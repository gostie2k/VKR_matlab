#!/usr/bin/env python3
"""
analyse_v3.py — единый анализатор метрик прогонов V3 sync_top.

Принимает на вход:
    --symbols   путь к sync_out_symbols.txt
    --internal  путь к sync_internal.txt
    --trim      число выходных символов на отбрасываемом переходном
                процессе (по умолчанию 200)
    --steady    минимальный clk_count для стационарного окна
                (по умолчанию автоматически: 75% длины)

Выводит plain-text таблицу метрик и завершает работу.
Ничего не пишет, кроме stdout.

Колонки sync_internal.txt:
    1: clk_count
    2: nco_strobe
    3: strobe_d2
    4: cnt_reg
    5: mu_out
    6: debug_w
    7: e_out (signed)
    8: v_pi_wire (signed)
    9: vi_reg (signed)
"""

import argparse
import sys
import numpy as np
import collections


IDEAL_PHASES_DEG = np.array([45.0, 135.0, -135.0, -45.0])


def load_symbols(path):
    arr = np.loadtxt(path)
    if arr.ndim == 1:
        arr = arr.reshape(-1, 2)
    return arr


def load_internal(path):
    return np.loadtxt(path)


def compute_mer(symbols, ideal_mag=None):
    """Возвращает MER, медианную амплитуду, RMS амплитуды и распределение
    по 4 квадрантам с центрами на ±45° / ±135°."""
    if len(symbols) == 0:
        return float('nan'), float('nan'), float('nan'), {}, float('nan')
    mag = np.sqrt(symbols[:, 0] ** 2 + symbols[:, 1] ** 2)
    if ideal_mag is None:
        ideal_mag = float(np.median(mag))
    phases = np.degrees(np.arctan2(symbols[:, 1], symbols[:, 0]))
    err = np.empty(len(symbols))
    for i, (x, y) in enumerate(symbols):
        p = phases[i]
        d = (IDEAL_PHASES_DEG - p + 180.0) % 360.0 - 180.0
        j = int(np.argmin(np.abs(d)))
        ip = IDEAL_PHASES_DEG[j]
        ix = ideal_mag * np.cos(np.radians(ip))
        iy = ideal_mag * np.sin(np.radians(ip))
        err[i] = (x - ix) ** 2 + (y - iy) ** 2
    mer = 10.0 * np.log10(ideal_mag ** 2 / np.mean(err))
    rms = float(np.sqrt(np.mean(mag ** 2)))
    # Квадранты с центром на ±45°, ±135°: бин 90°, сдвиг 45°
    quads = collections.Counter(((phases + 180.0 + 45.0) / 90.0).astype(int) % 4)
    quads_pct = {int(k): 100.0 * quads[k] / len(symbols) for k in range(4)}
    # phase deviation std
    phase_dev = np.empty(len(symbols))
    for i in range(len(symbols)):
        p = phases[i]
        d = (IDEAL_PHASES_DEG - p + 180.0) % 360.0 - 180.0
        j = int(np.argmin(np.abs(d)))
        phase_dev[i] = (p - IDEAL_PHASES_DEG[j] + 180.0) % 360.0 - 180.0
    return mer, ideal_mag, rms, quads_pct, float(np.std(phase_dev))


def analyse(symbols_path, internal_path, trim=200, steady_start=None):
    syms_all = load_symbols(symbols_path)
    inter = load_internal(internal_path)
    n_total = len(syms_all)
    if trim >= n_total:
        raise SystemExit(f"trim {trim} >= N_sym {n_total}")
    syms = syms_all[trim:]
    n_steady = len(syms)

    # Window for internal metrics
    clk_max = float(inter[:, 0].max())
    if steady_start is None:
        # auto: take last 25% (after warmup) by clock count
        steady_start = int(clk_max * 0.75)
    seg = inter[inter[:, 0] >= steady_start]
    strobe_seg = seg[seg[:, 1] == 1]  # nco_strobe == 1 rows
    d2_seg = seg[seg[:, 2] == 1]      # strobe_d2 == 1 rows

    mer, ideal_mag, rms, quads, ph_std = compute_mer(syms)

    def stats(col):
        if len(col) == 0:
            return float('nan'), float('nan')
        return float(np.mean(col)), float(np.std(col))

    mu_mean, mu_std = stats(strobe_seg[:, 4]) if len(strobe_seg) else (float('nan'), float('nan'))
    w_mean, w_std = stats(seg[:, 5])
    vi_mean, vi_std = stats(seg[:, 8])
    abs_e_mean = float(np.mean(np.abs(seg[:, 6]))) if len(seg) else float('nan')

    print(f"=== analyse_v3 ===")
    print(f"symbols: {symbols_path}")
    print(f"internal: {internal_path}")
    print(f"N_sym total       = {n_total}")
    print(f"N_sym steady      = {n_steady}  (trim={trim})")
    print(f"steady_start_clk  = {steady_start}  (clk_max={int(clk_max)})")
    print(f"N strobe steady   = {len(strobe_seg)}")
    print(f"")
    print(f"MER               = {mer:.2f} dB")
    print(f"ideal_mag (med|x|)= {ideal_mag:.0f}")
    print(f"RMS|x|            = {rms:.0f}")
    print(f"phase dev std     = {ph_std:.2f} deg")
    print(f"Quadrants (±45/±135) [%]:  Q0={quads.get(0,0):.1f}  Q1={quads.get(1,0):.1f}  Q2={quads.get(2,0):.1f}  Q3={quads.get(3,0):.1f}")
    print(f"")
    print(f"mu_lock mean      = {mu_mean:.1f}   (ratio={mu_mean/4096:.4f})")
    print(f"mu_lock std       = {mu_std:.1f}")
    print(f"debug_w mean      = {w_mean:.1f}")
    print(f"debug_w std       = {w_std:.1f}")
    print(f"vi_reg  mean      = {vi_mean:.2f}")
    print(f"vi_reg  std       = {vi_std:.2f}")
    print(f"|e_out| mean      = {abs_e_mean:.0f}")

    return {
        'N_sym': n_total,
        'N_sym_steady': n_steady,
        'MER': mer,
        'ideal_mag': ideal_mag,
        'RMS': rms,
        'phase_std': ph_std,
        'quads': quads,
        'mu_mean': mu_mean,
        'mu_std': mu_std,
        'mu_ratio': mu_mean / 4096.0,
        'w_mean': w_mean,
        'w_std': w_std,
        'vi_mean': vi_mean,
        'vi_std': vi_std,
        'abs_e_mean': abs_e_mean,
        'steady_start_clk': steady_start,
    }


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument('--symbols', required=True)
    ap.add_argument('--internal', required=True)
    ap.add_argument('--trim', type=int, default=200)
    ap.add_argument('--steady', type=int, default=None)
    args = ap.parse_args()
    analyse(args.symbols, args.internal, args.trim, args.steady)


if __name__ == '__main__':
    main()
