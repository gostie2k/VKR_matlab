#!/usr/bin/env bash
# D1: EbN0 sweep for sync_top V3.
# Usage: bash run_d1_sweep.sh
# - Patches gen_sync_top_stimulus.py for each EbN0
# - Runs Vivado batch simulation sequentially (NO parallelism)
# - Saves artifacts to sim/debug_v3/D1_ebno_sweep/ebno_NN/
# - At the end restores EBN0_DB = 20.0

set -e
ROOT=/home/t-kudimov/temp/matmodel/vkr_sync_hdl
SIM=$ROOT/sim
OUT=$SIM/debug_v3/D1_ebno_sweep
STIM=$SIM/gen_sync_top_stimulus.py

EBNO_LIST=(60 40 30 25 20 15)

# Vivado env
source /home/t-kudimov/viv/Vivado/2023.2/settings64.sh
VIVADO=/home/t-kudimov/viv/Vivado/2023.2/bin/vivado

cd "$ROOT"

for E in "${EBNO_LIST[@]}"; do
    echo "=========================================="
    echo "[D1] EbN0 = $E dB"
    echo "=========================================="
    SUBDIR="$OUT/ebno_${E}"
    mkdir -p "$SUBDIR"

    # 1. Patch EBN0_DB
    python3 - <<PY
import re
p = "$STIM"
s = open(p).read()
s = re.sub(r'^EBN0_DB\s*=.*$', f'EBN0_DB     = ${E}.0      # Eb/N0, дБ (D1 sweep)', s, count=1, flags=re.M)
open(p,'w').write(s)
PY

    # 2. Regenerate stimulus
    cd "$SIM"
    python3 gen_sync_top_stimulus.py > "$SUBDIR/gen.log" 2>&1
    cd "$ROOT"

    # 3. Run Vivado simulation (foreground, sequential)
    "$VIVADO" -mode batch -source scripts/run_sim_top.tcl > "$SUBDIR/vivado_run.log" 2>&1 || {
        echo "Vivado failed at EbN0=$E"; exit 1; }

    # 4. Copy outputs
    cp "$SIM/sync_out_symbols.txt" "$SUBDIR/sync_out_symbols.txt"
    cp "$SIM/sync_internal.txt"    "$SUBDIR/sync_internal.txt"

    # 5. Analyse Verilog metrics
    python3 "$SIM/debug_v3/analyse_v3.py" \
        --symbols  "$SUBDIR/sync_out_symbols.txt" \
        --internal "$SUBDIR/sync_internal.txt" \
        --trim 200 > "$SUBDIR/metrics.txt" 2>&1

    # 6. Compute ideal MER (golden offline sync)
    python3 "$SIM/debug_v3/golden_offline_sync.py" --ebno $E --seed 42 \
        > "$SUBDIR/mer_ideal.txt" 2>&1

    echo "[D1] EbN0=$E done. Artifacts -> $SUBDIR"
done

# Restore EBN0_DB=20.0
python3 - <<PY
import re
p = "$STIM"
s = open(p).read()
s = re.sub(r'^EBN0_DB\s*=.*$', 'EBN0_DB     = 20.0      # Eb/N0, дБ (достаточно высокое для чистого захвата)', s, count=1, flags=re.M)
open(p,'w').write(s)
PY
echo "[D1] EBN0_DB restored to 20.0"
echo "[D1] sweep complete."
