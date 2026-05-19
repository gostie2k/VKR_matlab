#!/usr/bin/env bash
# syn/scripts/run_all_ooc.sh
#
# Master-скрипт: out-of-context-синтез всех модулей петли символьной
# синхронизации при целевой частоте 100 МГц и контрольный прогон
# sync_top на 150 МГц.
#
# Запуск (из корня vkr_sync_hdl):
#   bash syn/scripts/run_all_ooc.sh
#
# Все .rpt-отчёты и логи попадают в syn/reports/.

set -e
ROOT=/home/t-kudimov/temp/matmodel/vkr_sync_hdl
cd "$ROOT"

source /home/t-kudimov/viv/Vivado/2023.2/settings64.sh
VIVADO=/home/t-kudimov/viv/Vivado/2023.2/bin/vivado

# Раздельные XDC: общий для sync_top и для подмодулей без конфиг-портов;
# отдельный для подмодулей с конфиг-портами (false_path на AXI-Lite-входах)
XDC_TOP_100="syn/constraints/sync_top_ooc.xdc"
XDC_TOP_150="syn/constraints/sync_top_ooc_150mhz.xdc"
XDC_PI_100="syn/constraints/sync_loop_filter_pi_ooc.xdc"
XDC_AGC_100="syn/constraints/sync_agc_ooc.xdc"

mkdir -p syn/reports

run_one () {
    local TOP=$1
    local OUT=$2
    local XDC=$3
    local LOG="syn/reports/${OUT}_log.txt"

    echo "=== [$(date '+%H:%M:%S')] OOC: $TOP -> $OUT (xdc=$XDC) ==="
    "$VIVADO" -mode batch \
              -source syn/scripts/run_ooc_synth.tcl \
              -tclargs "$TOP" "$OUT" "$XDC" \
              2>&1 | tee "$LOG"
    if [ -f vivado.log ]; then mv -f vivado.log "syn/reports/${OUT}_vivado.log"; fi
    if [ -f vivado.jou ]; then mv -f vivado.jou "syn/reports/${OUT}_vivado.jou"; fi
}

# -------- Все шесть модулей @ 100 МГц --------
# Подмодули без конфиг-портов — общий XDC sync_top_ooc.xdc:
run_one sync_farrow_parab   sync_farrow_parab_100mhz   "$XDC_TOP_100"
run_one sync_mod1_nco       sync_mod1_nco_100mhz       "$XDC_TOP_100"
run_one sync_ted_gardner    sync_ted_gardner_100mhz    "$XDC_TOP_100"
# Подмодули с конфиг-портами — специализированные XDC:
run_one sync_loop_filter_pi sync_loop_filter_pi_100mhz "$XDC_PI_100"
run_one sync_agc            sync_agc_100mhz            "$XDC_AGC_100"
# Верхний модуль:
run_one sync_top            sync_top_100mhz            "$XDC_TOP_100"

# -------- Контрольный прогон sync_top @ 150 МГц --------
run_one sync_top            sync_top_150mhz            "$XDC_TOP_150"

echo "=== [$(date '+%H:%M:%S')] All OOC syntheses done ==="
ls -la syn/reports/
