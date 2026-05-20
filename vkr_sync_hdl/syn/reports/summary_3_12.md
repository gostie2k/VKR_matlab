# Этап 3.12 — OOC-синтез петли символьной синхронизации

**Дата:** см. время в `.rpt`.  
**Тулза:** Vivado 2023.2 (-mode batch).  
**FPGA part:** xc7z020clg484-1 (Zynq-7020, CLG484, speed grade -1).

Out-of-context-синтез выполнен с post-route timing: `synth_design → opt_design → place_design → route_design`. Каждый из шести RTL-модулей синтезирован как самостоятельный top-уровень при целевой частоте 100 МГц (период 10.000 нс); дополнительно для `sync_top` проведён контрольный прогон при 150 МГц (период 6.667 нс) — оценка запаса архитектуры.

## 1. Утилизация по модулям при 100 МГц

| Модуль                | LUT  | LUTRAM | FF   | BRAM, kb | DSP48E1 | WNS, нс | Fmax, МГц |
|-----------------------|------|--------|------|----------|---------|---------|-----------|
| sync_agc              |   83 |      0 |  101 |        0 |       4 |  +3.177 |     146.6 |
| sync_farrow_parab     |  252 |      0 |  290 |        0 |       6 |  +1.442 |     116.8 |
| sync_mod1_nco         |   17 |      0 |   29 |        0 |       0 |  +5.244 |     210.3 |
| sync_ted_gardner      |  100 |      0 |  151 |        0 |       2 |  +4.674 |     187.8 |
| sync_loop_filter_pi   |  194 |      0 |   70 |        0 |       2 |  +2.915 |     141.1 |
| sync_top              |  673 |      0 |  643 |        0 |      14 |  +1.720 |     120.8 |

## 2. Иерархическая утилизация sync_top (100 МГц)

| Instance | Module | LUTs (Total) | FF | DSP | RAMB36/18 |
|----------|--------|--------------|----|-----|-----------|
| sync_top | (top) | 673 | 643 | - | 0/0 |
| (sync_top) | (top) | 0 | 10 | - | 0/0 |
| u_agc | sync_agc | 94 | 100 | - | 0/0 |
| u_farrow | sync_farrow_parab | 254 | 288 | - | 0/0 |
| u_nco | sync_mod1_nco | 16 | 29 | - | 0/0 |
| u_pi | sync_loop_filter_pi | 209 | 67 | - | 0/0 |
| u_ted | sync_ted_gardner | 100 | 149 | - | 0/0 |

## 3. Критический путь sync_top при 100 МГц

- **Slack:** +1.720 нс
- **Source:** `t_mul_mu_i_i_18/C`
- **Destination:** `u_farrow/t_mul_mu_q__0/PCIN[0]`
- **Data Path Delay:** 6.796 нс
- **Logic Levels:** 2

## 4. Особенности инференса

Раздел заполняется вручную по результатам ручного осмотра отчётов утилизации (см. секцию «Особенности инференса» в README/диалоге).

## 5. Запас по частоте

Контрольный прогон sync_top при 150 МГц:
- WNS = -0.802 нс
- Fmax (по 150 МГц прогону) = 133.9 МГц
- Worst path @150 МГц: `t_mul_mu_i_i_18/C` → `u_farrow/t_mul_mu_q__0/PCIN[0]`, data path 5.985 нс, logic levels 2

## 6. Критические warning'ы и DRC

| Источник | Сообщение |
|----------|-----------|
| sync_agc_100mhz_log.txt | #     puts "ERROR: usage: vivado -mode batch -source run_ooc_synth.tcl -tclargs <top> <out_name> \[<xdc>\]" |
| sync_farrow_parab_100mhz_log.txt | #     puts "ERROR: usage: vivado -mode batch -source run_ooc_synth.tcl -tclargs <top> <out_name> \[<xdc>\]" |
| sync_farrow_parab_100mhz_log.txt | CRITICAL WARNING: [Vivado 12-4739] set_false_path:No valid object(s) found for '-from [get_ports {ctrl_soft_reset ctrl_e |
| sync_farrow_parab_100mhz_log.txt | CRITICAL WARNING: [Vivado 12-4739] set_false_path:No valid object(s) found for '-from [get_ports {ctrl_soft_reset ctrl_e |
| sync_mod1_nco_100mhz_log.txt | #     puts "ERROR: usage: vivado -mode batch -source run_ooc_synth.tcl -tclargs <top> <out_name> \[<xdc>\]" |
| sync_mod1_nco_100mhz_log.txt | CRITICAL WARNING: [Vivado 12-4739] set_false_path:No valid object(s) found for '-from [get_ports {ctrl_soft_reset ctrl_e |
| sync_mod1_nco_100mhz_log.txt | CRITICAL WARNING: [Vivado 12-4739] set_false_path:No valid object(s) found for '-from [get_ports {ctrl_soft_reset ctrl_e |
| sync_ted_gardner_100mhz_log.txt | #     puts "ERROR: usage: vivado -mode batch -source run_ooc_synth.tcl -tclargs <top> <out_name> \[<xdc>\]" |
| sync_ted_gardner_100mhz_log.txt | CRITICAL WARNING: [Vivado 12-4739] set_false_path:No valid object(s) found for '-from [get_ports {ctrl_soft_reset ctrl_e |
| sync_ted_gardner_100mhz_log.txt | CRITICAL WARNING: [Vivado 12-4739] set_false_path:No valid object(s) found for '-from [get_ports {ctrl_soft_reset ctrl_e |
| sync_loop_filter_pi_100mhz_log.txt | #     puts "ERROR: usage: vivado -mode batch -source run_ooc_synth.tcl -tclargs <top> <out_name> \[<xdc>\]" |
| sync_top_100mhz_log.txt | #     puts "ERROR: usage: vivado -mode batch -source run_ooc_synth.tcl -tclargs <top> <out_name> \[<xdc>\]" |
| sync_top_150mhz_log.txt | #     puts "ERROR: usage: vivado -mode batch -source run_ooc_synth.tcl -tclargs <top> <out_name> \[<xdc>\]" |

## 7. Особенности OOC-ограничений

В реальной интеграции (Block Design + AXI-Lite shim) конфигурационные порты `reg_k1`, `reg_k2`, `reg_w_nom`, `reg_clamp`, `reg_agc_target`, а также управляющие `ctrl_soft_reset`, `ctrl_enable`, `ctrl_agc_bypass` драйвятся статическими регистрами в той же clock-области и обновляются один раз за сеанс. В OOC-режиме они получают артефактный `set_input_delay 2.0 ns`, что приводит к ложному критическому пути через комбинационное насыщение PI-фильтра. Для устранения этого артефакта соответствующие порты объявлены `set_false_path` в `sync_top_ooc.xdc`, `sync_top_ooc_150mhz.xdc`, `sync_loop_filter_pi_ooc.xdc`, `sync_agc_ooc.xdc`.

В интегрированной системе данные ограничения избыточны: регистры AXI-Lite shim'а и регистры подмодулей принадлежат одной clock-области, и timing между ними учитывается стандартными правилами синхронизатора без дополнительных ограничений.

## 8. Открытые вопросы

Модули с WNS < 0 (после false_path на конфиг-портах) требуют ручного решения:
- **sync_top** (sync_top_150mhz): WNS = -0.802 нс при цели 150 МГц.
  Источник: `t_mul_mu_i_i_18/C`. Назначение: `u_farrow/t_mul_mu_q__0/PCIN[0]`.
  Data path 5.985 нс, 2 уровней логики.
