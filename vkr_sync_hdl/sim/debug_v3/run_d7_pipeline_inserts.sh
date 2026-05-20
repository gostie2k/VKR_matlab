#!/usr/bin/env bash
# D7 — перепрогон V3 после трёх RTL-правок этапа 3.12 (итерация 3, pipeline):
#   1) sync_farrow_parab.v   pipeline между DSP-продуктом и сложением v0 (+1 такт)
#   2) sync_ted_gardner.v    pipeline между DSP-продуктами и финальным sum (+1 такт)
#   3) sync_agc.v            pipeline между I²/Q² и накопителем (+1 такт)
#
# Прогон 1: EbN0 = 20 dB (рабочая точка).
# Прогон 2: EbN0 = 60 dB (high-SNR ceiling).
set -e
ROOT=/home/t-kudimov/temp/matmodel/vkr_sync_hdl
SIM=$ROOT/sim
STIM=$SIM/gen_sync_top_stimulus.py

source /home/t-kudimov/viv/Vivado/2023.2/settings64.sh
VIVADO=/home/t-kudimov/viv/Vivado/2023.2/bin/vivado

cd "$ROOT"

run_one () {
    local EBNO=$1
    local OUT=$2
    mkdir -p "$OUT"

    python3 - <<PY
import re
p = "$STIM"
s = open(p).read()
s = re.sub(r'^EBN0_DB\s*=.*$', f'EBN0_DB     = ${EBNO}.0      # Eb/N0, дБ (D7)', s, count=1, flags=re.M)
open(p,'w').write(s)
PY

    cd "$SIM"
    python3 gen_sync_top_stimulus.py > "$OUT/gen.log" 2>&1
    cd "$ROOT"

    "$VIVADO" -mode batch -source scripts/create_project_top.tcl 2>&1 \
        | tee "$OUT/log_create_top.txt"
    "$VIVADO" -mode batch -source scripts/run_sim_top.tcl 2>&1 \
        | tee "$OUT/log_run_top.txt"

    cp "$SIM/sync_out_symbols.txt" "$OUT/sync_out_symbols.txt"
    cp "$SIM/sync_internal.txt"    "$OUT/sync_internal.txt"

    python3 "$SIM/debug_v3/analyse_v3.py" \
        --symbols  "$OUT/sync_out_symbols.txt" \
        --internal "$OUT/sync_internal.txt" \
        --trim 200 > "$OUT/metrics.txt" 2>&1
}

run_one 20 "$SIM/debug_v3/D7_pipeline_inserts"
run_one 60 "$SIM/debug_v3/D7_pipeline_inserts_ebno60"

# Восстановить EBN0_DB=20.0
python3 - <<PY
import re
p = "$STIM"
s = open(p).read()
s = re.sub(r'^EBN0_DB\s*=.*$', 'EBN0_DB     = 20.0      # Eb/N0, дБ (достаточно высокое для чистого захвата)', s, count=1, flags=re.M)
open(p,'w').write(s)
PY
echo "[D7] done. EBN0_DB restored to 20.0"
