#!/usr/bin/env python3
"""
syn/scripts/extract_metrics.py

Парсит отчёты Vivado из syn/reports/, формирует:
    - таблицу утилизации по модулям (LUT, LUTRAM, FF, BRAM, DSP48E1);
    - таблицу timing'а (WNS, TNS, WHS, целевая/достижимая частота);
    - иерархическую таблицу для sync_top;
    - топ-1 критический путь sync_top;
    - сводку критических warning'ов;
    - итоговый summary_3_12.md.

Запуск:
    python3 syn/scripts/extract_metrics.py
"""
import os
import re
import sys
from pathlib import Path

ROOT = Path(__file__).resolve().parents[2]
RPT  = ROOT / "syn" / "reports"

# Модули и соответствие частоте конкретного xdc
MODULES_100 = [
    ("sync_agc",            "sync_agc_100mhz",            10.000),
    ("sync_farrow_parab",   "sync_farrow_parab_100mhz",   10.000),
    ("sync_mod1_nco",       "sync_mod1_nco_100mhz",       10.000),
    ("sync_ted_gardner",    "sync_ted_gardner_100mhz",    10.000),
    ("sync_loop_filter_pi", "sync_loop_filter_pi_100mhz", 10.000),
    ("sync_top",            "sync_top_100mhz",            10.000),
]
MODULE_150 = ("sync_top", "sync_top_150mhz", 6.667)


def read(p):
    return p.read_text(errors="replace") if p.exists() else ""


# --------- Утилизация ---------
def parse_util(path):
    """
    Возвращает dict: LUT, LUTRAM, FF, BRAM_kb, DSP.
    """
    text = read(path)
    out = {"LUT": "-", "LUTRAM": "-", "FF": "-", "BRAM_kb": "-", "DSP": "-"}
    if not text:
        return out

    def row(name):
        # Ищет '| <name> | <used> | ...'
        m = re.search(rf"^\|\s*{re.escape(name)}\s*\|\s*(\d+)\s*\|", text, re.M)
        return int(m.group(1)) if m else None

    lut       = row("Slice LUTs")
    lutram    = row("LUT as Memory") or row("Slice LUTs as Memory") or 0
    ff        = row("Slice Registers") or row("Register as Flip Flop")
    bram_t36  = row("Block RAM Tile") or 0
    ramb36    = row("RAMB36/FIFO") or 0
    ramb18    = row("RAMB18") or 0
    dsp       = row("DSPs")

    if lut is not None: out["LUT"] = lut
    out["LUTRAM"]  = lutram if lutram is not None else 0
    if ff is not None: out["FF"] = ff
    # BRAM в килобитах: RAMB36 = 36 kb, RAMB18 = 18 kb
    bram_kb = ramb36 * 36 + ramb18 * 18
    out["BRAM_kb"] = bram_kb
    if dsp is not None: out["DSP"] = dsp
    return out


# --------- Timing ---------
def parse_timing(path, period_ns):
    """
    Возвращает dict: WNS, TNS, WHS, THS, fmax_MHz, target_MHz.
    """
    text = read(path)
    out = {"WNS": None, "TNS": None, "WHS": None, "THS": None,
           "fmax_MHz": None, "target_MHz": 1000.0 / period_ns}
    if not text:
        return out

    # Первая строка с числами после заголовка таблицы Setup/Hold/PulseWidth
    m = re.search(
        r"^\s*WNS\(ns\).*?\n\s*-+.*?\n\s*([-\d.]+)\s+([-\d.]+)\s+\d+\s+\d+"
        r"\s+([-\d.]+)\s+([-\d.]+)",
        text, re.M | re.S)
    if m:
        out["WNS"] = float(m.group(1))
        out["TNS"] = float(m.group(2))
        out["WHS"] = float(m.group(3))
        out["THS"] = float(m.group(4))
        # достижимая частота: 1000 / (period - WNS)
        # если WNS > 0 (положительный slack), fmax = 1000 / (period - WNS)
        # если WNS < 0, fmax < target
        eff_period = period_ns - out["WNS"]
        if eff_period > 0:
            out["fmax_MHz"] = 1000.0 / eff_period
    return out


# --------- Worst path ---------
def parse_worst_path(path):
    """
    Возвращает dict с одним худшим путём:
       slack, source, destination, data_path_delay, logic_levels.
    """
    text = read(path)
    out = {"slack": None, "source": None, "destination": None,
           "data_path_delay": None, "logic_levels": None}
    if not text:
        return out
    # Первый блок Slack ... Source ... Destination ... Data Path Delay
    m = re.search(
        r"Slack\s*\(.*?\)\s*:\s*([-\d.]+)ns.*?"
        r"Source:\s*([^\n]+).*?"
        r"Destination:\s*([^\n]+).*?"
        r"Data Path Delay:\s*([\d.]+)ns.*?"
        r"Logic Levels:\s*(\d+)",
        text, re.S)
    if m:
        out["slack"]            = float(m.group(1))
        out["source"]           = m.group(2).strip().split(" ")[0]
        out["destination"]      = m.group(3).strip().split(" ")[0]
        out["data_path_delay"]  = float(m.group(4))
        out["logic_levels"]     = int(m.group(5))
    return out


# --------- Иерархическая утилизация sync_top ---------
def parse_hier_util(path):
    """
    Возвращает list of dict: {instance, module, LUT, FF, BRAM, DSP}
    из секции 15. (или подобной) report_utilization -hierarchical.
    """
    text = read(path)
    if not text:
        return []
    # Найдём блок Utilization by Hierarchy
    m = re.search(r"Utilization by Hierarchy.*?\Z", text, re.S)
    if not m:
        return []
    block = m.group(0)
    rows = []
    # Строки таблицы вида: | Instance | Module | Total LUTs | Logic LUTs | LUTRAMs | SRLs | FFs | RAMB36 | RAMB18 | DSP48 Blocks |
    # Заголовок:
    hdr = re.search(r"^\|\s*Instance\s*\|\s*Module\s*\|.*$", block, re.M)
    if not hdr:
        return []
    # Подбираем имена колонок по заголовку
    header_line = hdr.group(0)
    cols = [c.strip() for c in header_line.split("|")[1:-1]]
    # Парсим строки после заголовка
    body_start = hdr.end()
    body = block[body_start:]
    for line in body.splitlines():
        if not line.startswith("|"):
            continue
        cells = [c.strip() for c in line.split("|")[1:-1]]
        if len(cells) != len(cols):
            continue
        if cells[0] in ("Instance", ""):
            continue
        rec = dict(zip(cols, cells))
        rows.append(rec)
    return rows


# --------- Warning сводка ---------
def parse_warnings(report_paths):
    """
    Просматривает указанные .rpt/.txt и собирает строки с критическими warning-кодами.
    """
    crit_codes = ["Synth 8-", "Constraints 18-", "Timing 38-2", "Project 1-486",
                  "Place 30-", "Route 35-"]
    found = []
    for p in report_paths:
        t = read(p)
        for line in t.splitlines():
            if "CRITICAL WARNING" in line or "ERROR" in line:
                found.append((p.name, line.strip()))
    return found


def fmt_int(x):
    if x in (None, "-"):
        return "-"
    return str(x)


def main():
    util = {}
    timing = {}
    worst = {}

    for top, out, period in MODULES_100 + [MODULE_150]:
        u_path = RPT / f"{out}_util.rpt"
        t_path = RPT / f"{out}_timing.rpt"
        w_path = RPT / f"{out}_timing_paths.rpt"
        util[out]   = parse_util(u_path)
        timing[out] = parse_timing(t_path, period)
        worst[out]  = parse_worst_path(w_path)

    hier_top = parse_hier_util(RPT / "sync_top_100mhz_util_hier.rpt")

    # ------- собираем критические warning -------
    wlogs = []
    for top, out, _ in MODULES_100 + [MODULE_150]:
        for ext in ["_log.txt", "_method.rpt", "_drc.rpt"]:
            p = RPT / f"{out}{ext}"
            if p.exists():
                wlogs.append(p)
    crit = parse_warnings(wlogs)
    (RPT / "critical_warnings.txt").write_text(
        "Критические warning'ы / ERROR из логов OOC-синтеза:\n\n"
        + ("\n".join(f"[{f}] {l}" for f, l in crit) if crit
           else "(пусто — критических warning'ов и ошибок не обнаружено)\n")
    )

    # ------- summary_3_12.md -------
    md = []
    md.append("# Этап 3.12 — OOC-синтез петли символьной синхронизации")
    md.append("")
    md.append("**Дата:** см. время в `.rpt`.  ")
    md.append("**Тулза:** Vivado 2023.2 (-mode batch).  ")
    md.append("**FPGA part:** xc7z020clg484-1 (Zynq-7020, CLG484, speed grade -1).")
    md.append("")
    md.append("Out-of-context-синтез выполнен с post-route timing: "
              "`synth_design → opt_design → place_design → route_design`. "
              "Каждый из шести RTL-модулей синтезирован как самостоятельный "
              "top-уровень при целевой частоте 100 МГц (период 10.000 нс); "
              "дополнительно для `sync_top` проведён контрольный прогон при "
              "150 МГц (период 6.667 нс) — оценка запаса архитектуры.")
    md.append("")

    # ---------- 1. Утилизация ----------
    md.append("## 1. Утилизация по модулям при 100 МГц")
    md.append("")
    md.append("| Модуль                | LUT  | LUTRAM | FF   | BRAM, kb | DSP48E1 | WNS, нс | Fmax, МГц |")
    md.append("|-----------------------|------|--------|------|----------|---------|---------|-----------|")
    for top, out, period in MODULES_100:
        u = util[out]; t = timing[out]
        wns  = f"{t['WNS']:+.3f}" if t["WNS"] is not None else "-"
        fmax = f"{t['fmax_MHz']:.1f}" if t["fmax_MHz"] else "-"
        md.append("| {:<21} | {:>4} | {:>6} | {:>4} | {:>8} | {:>7} | {:>7} | {:>9} |".format(
            top, fmt_int(u["LUT"]), fmt_int(u["LUTRAM"]), fmt_int(u["FF"]),
            fmt_int(u["BRAM_kb"]), fmt_int(u["DSP"]), wns, fmax))
    md.append("")

    # ---------- 2. Иерархия sync_top ----------
    md.append("## 2. Иерархическая утилизация sync_top (100 МГц)")
    md.append("")
    if hier_top:
        # Покажем первый уровень глубины (instance под sync_top)
        md.append("| Instance | Module | LUTs (Total) | FF | DSP | RAMB36/18 |")
        md.append("|----------|--------|--------------|----|-----|-----------|")
        for r in hier_top:
            inst   = r.get("Instance", "")
            mod    = r.get("Module", "")
            lut_t  = r.get("Total LUTs", r.get("Logic LUTs", "-"))
            ff     = r.get("FFs", r.get("Registers", "-"))
            dsp    = r.get("DSP48 Blocks", r.get("DSPs", "-"))
            ram36  = r.get("RAMB36", "0")
            ram18  = r.get("RAMB18", "0")
            md.append(f"| {inst} | {mod} | {lut_t} | {ff} | {dsp} | {ram36}/{ram18} |")
    else:
        md.append("_(иерархический отчёт пуст — см. raw report sync_top_100mhz_util_hier.rpt)_")
    md.append("")

    # ---------- 3. Критический путь sync_top ----------
    md.append("## 3. Критический путь sync_top при 100 МГц")
    md.append("")
    w = worst.get("sync_top_100mhz", {})
    if w.get("slack") is not None:
        md.append(f"- **Slack:** {w['slack']:+.3f} нс")
        md.append(f"- **Source:** `{w['source']}`")
        md.append(f"- **Destination:** `{w['destination']}`")
        md.append(f"- **Data Path Delay:** {w['data_path_delay']:.3f} нс")
        md.append(f"- **Logic Levels:** {w['logic_levels']}")
    else:
        md.append("_(не удалось извлечь — см. sync_top_100mhz_timing_paths.rpt)_")
    md.append("")

    # ---------- 4. Особенности инференса ----------
    md.append("## 4. Особенности инференса")
    md.append("")
    md.append("Раздел заполняется вручную по результатам ручного осмотра"
              " отчётов утилизации (см. секцию «Особенности инференса»"
              " в README/диалоге).")
    md.append("")

    # ---------- 5. Запас по частоте ----------
    md.append("## 5. Запас по частоте")
    md.append("")
    t150 = timing["sync_top_150mhz"]
    w150 = worst["sync_top_150mhz"]
    md.append(f"Контрольный прогон sync_top при 150 МГц:")
    md.append(f"- WNS = {t150['WNS']:+.3f} нс" if t150["WNS"] is not None else "- WNS: не извлечён")
    if t150["fmax_MHz"] is not None:
        md.append(f"- Fmax (по 150 МГц прогону) = {t150['fmax_MHz']:.1f} МГц")
    if w150.get("slack") is not None:
        md.append(f"- Worst path @150 МГц: `{w150['source']}` → `{w150['destination']}`, "
                  f"data path {w150['data_path_delay']:.3f} нс, "
                  f"logic levels {w150['logic_levels']}")
    md.append("")

    # ---------- 6. Критические warning'ы ----------
    md.append("## 6. Критические warning'ы и DRC")
    md.append("")
    if crit:
        md.append("| Источник | Сообщение |")
        md.append("|----------|-----------|")
        for f, l in crit[:50]:
            md.append(f"| {f} | {l[:120]} |")
    else:
        md.append("Критических warning / ERROR не обнаружено.")
    md.append("")

    # ---------- 7. OOC-ограничения ----------
    md.append("## 7. Особенности OOC-ограничений")
    md.append("")
    md.append("В реальной интеграции (Block Design + AXI-Lite shim) "
              "конфигурационные порты `reg_k1`, `reg_k2`, `reg_w_nom`, "
              "`reg_clamp`, `reg_agc_target`, а также управляющие "
              "`ctrl_soft_reset`, `ctrl_enable`, `ctrl_agc_bypass` "
              "драйвятся статическими регистрами в той же clock-области "
              "и обновляются один раз за сеанс. В OOC-режиме они "
              "получают артефактный `set_input_delay 2.0 ns`, что "
              "приводит к ложному критическому пути через комбинационное "
              "насыщение PI-фильтра. Для устранения этого артефакта "
              "соответствующие порты объявлены `set_false_path` в "
              "`sync_top_ooc.xdc`, `sync_top_ooc_150mhz.xdc`, "
              "`sync_loop_filter_pi_ooc.xdc`, `sync_agc_ooc.xdc`.")
    md.append("")
    md.append("В интегрированной системе данные ограничения избыточны: "
              "регистры AXI-Lite shim'а и регистры подмодулей принадлежат "
              "одной clock-области, и timing между ними учитывается "
              "стандартными правилами синхронизатора без дополнительных "
              "ограничений.")
    md.append("")

    # ---------- 8. Открытые вопросы ----------
    md.append("## 8. Открытые вопросы")
    md.append("")
    open_issues = []
    for top, out, period in MODULES_100 + [MODULE_150]:
        t = timing[out]
        if t["WNS"] is not None and t["WNS"] < 0:
            w = worst[out]
            open_issues.append(
                f"- **{top}** ({out}): WNS = {t['WNS']:+.3f} нс при цели "
                f"{t['target_MHz']:.0f} МГц.\n"
                f"  Источник: `{w['source']}`. Назначение: `{w['destination']}`.\n"
                f"  Data path {w['data_path_delay']:.3f} нс, "
                f"{w['logic_levels']} уровней логики."
            )
    if open_issues:
        md.append("Модули с WNS < 0 (после false_path на конфиг-портах) "
                  "требуют ручного решения:")
        md.extend(open_issues)
    else:
        md.append("Не выявлены.")
    md.append("")

    out_path = RPT / "summary_3_12.md"
    out_path.write_text("\n".join(md))
    print(f"summary_3_12.md written to {out_path}")
    print(f"critical_warnings.txt written to {RPT / 'critical_warnings.txt'}")
    # Краткий dump в stdout
    for top, out, period in MODULES_100 + [MODULE_150]:
        u = util[out]; t = timing[out]
        wns = f"{t['WNS']:+.3f}" if t["WNS"] is not None else "?"
        print(f"  {out:<32}  LUT={u['LUT']:>5} FF={u['FF']:>5} "
              f"DSP={u['DSP']:>3} WNS={wns}")


if __name__ == "__main__":
    main()
