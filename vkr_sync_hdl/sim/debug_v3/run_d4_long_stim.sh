#!/usr/bin/env bash
# D4: long stimulus N_SYM=8000 to assess transient contribution.
# Patches gen_sync_top_stimulus.py (N_SYM=8000) and tb_sync_top.v
# (N_STIM, MAX_SAMP). Runs once at τ=0.3, seed=42, EbN0=20. Reverts both
# after the run.
set -e
ROOT=/home/t-kudimov/temp/matmodel/vkr_sync_hdl
SIM=$ROOT/sim
OUT=$SIM/debug_v3/D4_long_stim
STIM=$SIM/gen_sync_top_stimulus.py
TB=$SIM/tb_sync_top.v

source /home/t-kudimov/viv/Vivado/2023.2/settings64.sh
VIVADO=/home/t-kudimov/viv/Vivado/2023.2/bin/vivado

mkdir -p "$OUT"
cd "$ROOT"

cp "$TB"   "$OUT/tb_sync_top.v.orig"
cp "$STIM" "$OUT/gen_sync_top_stimulus.py.orig"

# 1. Patch N_SYM in generator (keep EbN0=20, seed=42, τ=0.3)
python3 - <<PY
import re
p = "$STIM"
s = open(p).read()
s = re.sub(r'^N_SYM\s*=.*$', 'N_SYM       = 8000      # символов QPSK (D4 long)', s, count=1, flags=re.M)
open(p,'w').write(s)
PY

# 2. Regenerate stim, read N_out from sync_params.vh
cd "$SIM"
python3 gen_sync_top_stimulus.py > "$OUT/gen.log" 2>&1
N_STIM_NEW=$(grep -E 'localparam N_STIM' sync_params.vh | grep -oE '[0-9]+' | tail -1)
echo "[D4] N_STIM_NEW = $N_STIM_NEW"
cd "$ROOT"

# 3. Patch testbench: N_STIM and MAX_SAMP
python3 - <<PY
import re
p = "$TB"
s = open(p).read()
s = re.sub(r'localparam\s+MAX_SAMP\s*=\s*\d+',  'localparam MAX_SAMP = 16384', s)
s = re.sub(r'localparam\s+N_STIM\s*=\s*\d+',    'localparam N_STIM      = $N_STIM_NEW', s)
open(p,'w').write(s)
PY

# 4. Run Vivado (rebuild project will pick up the testbench change)
"$VIVADO" -mode batch -source scripts/run_sim_top.tcl > "$OUT/vivado_run.log" 2>&1 || {
    echo "Vivado failed at D4"; }

# 5. Copy results
cp "$SIM/sync_out_symbols.txt" "$OUT/sync_out_symbols.txt" 2>/dev/null || true
cp "$SIM/sync_internal.txt"    "$OUT/sync_internal.txt"    2>/dev/null || true

# 6. Analyse — full run, and steady-state-only with bigger trim
python3 "$SIM/debug_v3/analyse_v3.py" \
    --symbols  "$OUT/sync_out_symbols.txt" \
    --internal "$OUT/sync_internal.txt" \
    --trim 200 > "$OUT/metrics_trim200.txt" 2>&1
python3 "$SIM/debug_v3/analyse_v3.py" \
    --symbols  "$OUT/sync_out_symbols.txt" \
    --internal "$OUT/sync_internal.txt" \
    --trim 1000 > "$OUT/metrics_trim1000.txt" 2>&1
python3 "$SIM/debug_v3/analyse_v3.py" \
    --symbols  "$OUT/sync_out_symbols.txt" \
    --internal "$OUT/sync_internal.txt" \
    --trim 4000 > "$OUT/metrics_trim4000.txt" 2>&1

# 7. Revert tb and gen
cp "$OUT/tb_sync_top.v.orig"   "$TB"
cp "$OUT/gen_sync_top_stimulus.py.orig" "$STIM"
echo "[D4] done; tb and gen reverted."
