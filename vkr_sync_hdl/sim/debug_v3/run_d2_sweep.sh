#!/usr/bin/env bash
# D2: seed sweep at τ=0.3, EbN0=20, N_SYM=2000
set -e
ROOT=/home/t-kudimov/temp/matmodel/vkr_sync_hdl
SIM=$ROOT/sim
OUT=$SIM/debug_v3/D2_seed_sweep
STIM=$SIM/gen_sync_top_stimulus.py

SEEDS=(42 100 200 300 400)

source /home/t-kudimov/viv/Vivado/2023.2/settings64.sh
VIVADO=/home/t-kudimov/viv/Vivado/2023.2/bin/vivado

cd "$ROOT"
mkdir -p "$OUT"

for S in "${SEEDS[@]}"; do
    echo "=========================================="
    echo "[D2] seed = $S"
    echo "=========================================="
    SUBDIR="$OUT/seed_${S}"
    mkdir -p "$SUBDIR"

    python3 - <<PY
import re
p = "$STIM"
s = open(p).read()
s = re.sub(r'^np\.random\.seed\(\d+\)$', 'np.random.seed(${S})', s, count=1, flags=re.M)
open(p,'w').write(s)
PY

    cd "$SIM"
    python3 gen_sync_top_stimulus.py > "$SUBDIR/gen.log" 2>&1
    cd "$ROOT"

    "$VIVADO" -mode batch -source scripts/run_sim_top.tcl > "$SUBDIR/vivado_run.log" 2>&1 || {
        echo "Vivado failed at seed=$S"; exit 1; }

    cp "$SIM/sync_out_symbols.txt" "$SUBDIR/sync_out_symbols.txt"
    cp "$SIM/sync_internal.txt"    "$SUBDIR/sync_internal.txt"

    python3 "$SIM/debug_v3/analyse_v3.py" \
        --symbols  "$SUBDIR/sync_out_symbols.txt" \
        --internal "$SUBDIR/sync_internal.txt" \
        --trim 200 > "$SUBDIR/metrics.txt" 2>&1

    python3 "$SIM/debug_v3/golden_offline_sync.py" --ebno 20 --seed $S \
        > "$SUBDIR/mer_ideal.txt" 2>&1

    echo "[D2] seed=$S done."
done

python3 - <<PY
import re
p = "$STIM"
s = open(p).read()
s = re.sub(r'^np\.random\.seed\(\d+\)$', 'np.random.seed(42)', s, count=1, flags=re.M)
open(p,'w').write(s)
PY
echo "[D2] seed restored to 42. Done."
