#!/usr/bin/env python3
"""
golden_offline_sync.py — оффлайн-эталон символьной синхронизации.

Эмулирует тракт gen_sync_top_stimulus.py до квантизации, далее
выполняет ИДЕАЛЬНУЮ синхронизацию (sinc-интерполяция в точную
дробную позицию символа после tx RRC + timing offset + rx RRC)
и считает MER_ideal.

Метрика — теоретический потолок, доступный демодулятору в данных
условиях (тот же seed, тот же EbN0). Сравнение с MER из Verilog
даёт чистый бюджет потерь замкнутой петли Гарднера.

Используется в D1.
"""

import math
import argparse
import numpy as np
from numpy import convolve, pi, sqrt, arange, zeros


# Эти параметры ДОЛЖНЫ совпадать с константами в gen_sync_top_stimulus.py
N_SYM_DEFAULT   = 2000
SPS_TX          = 8
SPS_RX          = 2
ROLLOFF         = 0.35
SPAN            = 10
TIMING_OFF_SYM  = 0.3
W_IN            = 16


def rcosdesign(beta, span, sps):
    N = span * sps
    t = arange(-N, N + 1) / sps
    h = zeros(len(t))
    for i, ti in enumerate(t):
        if abs(ti) < 1e-12:
            h[i] = (1.0 - beta + 4.0 * beta / pi)
        elif abs(abs(ti) - 1.0 / (4.0 * beta)) < 1e-12:
            h[i] = beta / sqrt(2.0) * (
                (1.0 + 2.0/pi) * math.sin(pi/(4.0*beta)) +
                (1.0 - 2.0/pi) * math.cos(pi/(4.0*beta))
            )
        else:
            num = math.sin(pi*ti*(1-beta)) + 4*beta*ti*math.cos(pi*ti*(1+beta))
            den = pi*ti*(1 - (4*beta*ti)**2)
            h[i] = num / den
    h /= sqrt(np.sum(h**2))
    return h


def run_ideal(ebn0_db, seed=42, n_sym=N_SYM_DEFAULT, timing_off=TIMING_OFF_SYM):
    """Возвращает (tx_syms_iq, ideal_rx_syms_iq) на одной длине.

    ideal_rx_syms_iq — комплексные отсчёты, полученные идеальной
    sinc-интерполяцией к точным символьным позициям после tx RRC +
    timing offset + AWGN + rx RRC.
    """
    rng = np.random.RandomState(seed)
    bits = rng.randint(0, 2, (n_sym, 2))
    syms_i = (1 - 2 * bits[:, 0]) / sqrt(2.0)
    syms_q = (1 - 2 * bits[:, 1]) / sqrt(2.0)

    rrc = rcosdesign(ROLLOFF, SPAN, SPS_TX)
    sig_up_i = zeros(n_sym * SPS_TX)
    sig_up_q = zeros(n_sym * SPS_TX)
    sig_up_i[::SPS_TX] = syms_i
    sig_up_q[::SPS_TX] = syms_q
    sig_tx_i = convolve(sig_up_i, rrc, mode='same')
    sig_tx_q = convolve(sig_up_q, rrc, mode='same')

    delay_samples = timing_off * SPS_TX
    n_orig = arange(len(sig_tx_i))
    n_new = n_orig - delay_samples
    sig_del_i = np.interp(n_new, n_orig, sig_tx_i)
    sig_del_q = np.interp(n_new, n_orig, sig_tx_q)

    # AWGN — тот же расчёт, что в gen_sync_top_stimulus.py
    k_bits = 2
    snr_lin = 10.0 ** (ebn0_db / 10.0) * k_bits / SPS_TX
    noise_std = 1.0 / sqrt(2.0 * snr_lin)
    sig_rx_i = sig_del_i + noise_std * rng.randn(len(sig_del_i))
    sig_rx_q = sig_del_q + noise_std * rng.randn(len(sig_del_q))

    sig_mf_i = convolve(sig_rx_i, rrc, mode='same') / SPS_TX
    sig_mf_q = convolve(sig_rx_q, rrc, mode='same') / SPS_TX

    # Идеальная синхронизация:
    # np.convolve(mode='same') сохраняет позицию пика входной импульсной
    # последовательности. После timing-offset смещение по времени = delay_samples.
    # Пик k-го символа в sig_mf находится в позиции delay_samples + k*SPS_TX.
    sym_positions = delay_samples + np.arange(n_sym) * SPS_TX

    # sinc-интерполяция через windowed sinc по локальным соседям
    def sinc_sample(sig, pos, n_taps=33):
        half = (n_taps - 1) // 2
        result = np.zeros(len(pos), dtype=float)
        N = len(sig)
        for i, p in enumerate(pos):
            base = int(np.floor(p))
            frac = p - base
            # индексы base-half..base+half
            idx = base + np.arange(-half, half + 1)
            mask = (idx >= 0) & (idx < N)
            xs = np.where(mask, sig[np.clip(idx, 0, N-1)], 0.0)
            # окно Хэмминга + sinc
            t = np.arange(-half, half + 1) - frac
            w = 0.54 - 0.46 * np.cos(2 * np.pi * (np.arange(n_taps)) / (n_taps - 1))
            s = np.sinc(t)
            result[i] = np.sum(xs * s * w)
        return result

    ideal_i = sinc_sample(sig_mf_i, sym_positions)
    ideal_q = sinc_sample(sig_mf_q, sym_positions)

    tx = np.column_stack([syms_i, syms_q])
    rx = np.column_stack([ideal_i, ideal_q])

    return tx, rx


def mer_qpsk(tx, rx, trim=200):
    """Среднеквадратичное отношение мощности символа к ошибке."""
    tx_s = tx[trim:]
    rx_s = rx[trim:]
    # Нормировка: масштабируем rx так, чтобы средний |rx| = средний |tx|.
    rx_mag = np.sqrt(rx_s[:, 0] ** 2 + rx_s[:, 1] ** 2)
    tx_mag = np.sqrt(tx_s[:, 0] ** 2 + tx_s[:, 1] ** 2)
    scale = np.mean(tx_mag) / np.mean(rx_mag)
    rx_n = rx_s * scale
    err = rx_n - tx_s
    p_sig = np.mean(tx_s[:, 0] ** 2 + tx_s[:, 1] ** 2)
    p_err = np.mean(err[:, 0] ** 2 + err[:, 1] ** 2)
    mer = 10.0 * np.log10(p_sig / p_err)
    return mer


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument('--ebno', type=float, required=True)
    ap.add_argument('--seed', type=int, default=42)
    ap.add_argument('--n_sym', type=int, default=N_SYM_DEFAULT)
    ap.add_argument('--timing_off', type=float, default=TIMING_OFF_SYM)
    ap.add_argument('--trim', type=int, default=200)
    args = ap.parse_args()
    tx, rx = run_ideal(args.ebno, args.seed, args.n_sym, args.timing_off)
    mer = mer_qpsk(tx, rx, args.trim)
    print(f"=== golden_offline_sync ===")
    print(f"EbN0 = {args.ebno} dB, seed = {args.seed}, N_sym = {args.n_sym}, τ = {args.timing_off}")
    print(f"trim = {args.trim} symbols")
    print(f"MER_ideal = {mer:.2f} dB")
    return mer


if __name__ == '__main__':
    main()
