#!/usr/bin/env bash
# D3: PI rounding patch — runs at EbN0 ∈ {20, 60} dB, seed=42, τ=0.3.
# Note: patch already applied to rtl/sync_loop_filter_pi.v before this script.
set -e
ROOT=/home/t-kudimov/temp/matmodel/vkr_sync_hdl
SIM=$ROOT/sim
OUT=$SIM/debug_v3/D3_pi_rounding
STIM=$SIM/gen_sync_top_stimulus.py

EBNO_LIST=(60 20)

source /home/t-kudimov/viv/Vivado/2023.2/settings64.sh
VIVADO=/home/t-kudimov/viv/Vivado/2023.2/bin/vivado

cd "$ROOT"
mkdir -p "$OUT"

for E in "${EBNO_LIST[@]}"; do
    echo "=========================================="
    echo "[D3] (patched PI) EbN0 = $E dB"
    echo "=========================================="
    SUBDIR="$OUT/ebno_${E}_patched"
    mkdir -p "$SUBDIR"

    python3 - <<PY
import re
p = "$STIM"
s = open(p).read()
s = re.sub(r'^EBN0_DB\s*=.*$', f'EBN0_DB     = ${E}.0      # Eb/N0, дБ (D3 patched)', s, count=1, flags=re.M)
open(p,'w').write(s)
PY

    cd "$SIM"
    python3 gen_sync_top_stimulus.py > "$SUBDIR/gen.log" 2>&1
    cd "$ROOT"

    "$VIVADO" -mode batch -source scripts/run_sim_top.tcl > "$SUBDIR/vivado_run.log" 2>&1 || {
        echo "Vivado failed at EbN0=$E"; exit 1; }

    cp "$SIM/sync_out_symbols.txt" "$SUBDIR/sync_out_symbols.txt"
    cp "$SIM/sync_internal.txt"    "$SUBDIR/sync_internal.txt"

    python3 "$SIM/debug_v3/analyse_v3.py" \
        --symbols  "$SUBDIR/sync_out_symbols.txt" \
        --internal "$SUBDIR/sync_internal.txt" \
        --trim 200 > "$SUBDIR/metrics.txt" 2>&1

    echo "[D3] EbN0=$E patched done."
done

python3 - <<PY
import re
p = "$STIM"
s = open(p).read()
s = re.sub(r'^EBN0_DB\s*=.*$', 'EBN0_DB     = 20.0      # Eb/N0, дБ (достаточно высокое для чистого захвата)', s, count=1, flags=re.M)
open(p,'w').write(s)
PY
echo "[D3] EBN0_DB restored. Patch still applied — revert in next step."
