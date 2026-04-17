#!/usr/bin/env python3
"""
gen_sync_top_stimulus.py — генерация тестового QPSK-сигнала для
интеграционной верификации sync_top.

Цепочка: QPSK → RRC tx (sps=8) → timing offset → RRC rx → децимация до sps=2
Результат: hex-файлы для $readmemh в tb_sync_top.v

Kudimov, ВКР, Глава 3
"""

import math
import numpy as np
from numpy import convolve, exp, pi, sqrt, arange, zeros, roll

# ============ Параметры (совпадают с params_vkr.m) ============
N_SYM       = 2000      # символов QPSK
SPS_TX      = 8         # передискретизация передатчика
SPS_RX      = 2         # передискретизация на входе петли
ROLLOFF     = 0.35      # коэффициент RRC
SPAN        = 10        # полудлина RRC в символах
TIMING_OFF  = 0.3       # дробное смещение тактирования (в символах)
EBN0_DB     = 20.0      # Eb/N0, дБ (достаточно высокое для чистого захвата)
W_IN        = 16        # разрядность квантования

# Параметры PI-фильтра (Rice, B_n·T = 0.02, ζ = 1/√2, K_p = 2.7)
BNT   = 0.02
ZETA  = 1.0 / sqrt(2.0)
KP    = 2.7
THETA = BNT / (ZETA + 1.0/(4.0*ZETA))
D_N   = (1.0 + 2.0*ZETA*THETA + THETA**2) * KP
K1    = (4.0*ZETA*THETA) / D_N       # ~ 0.0192
K2    = (4.0*THETA**2) / D_N         # ~ 5.13e-4
# Знак: K0 = -1 для вычитающего NCO
K1    = -K1
K2    = -K2

np.random.seed(42)


def rcosdesign(beta, span, sps, shape='sqrt'):
    """Root Raised Cosine filter (аналог MATLAB rcosdesign)."""
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
            num = math.sin(pi * ti * (1 - beta)) + 4 * beta * ti * math.cos(pi * ti * (1 + beta))
            den = pi * ti * (1 - (4 * beta * ti)**2)
            h[i] = num / den
    h /= sqrt(np.sum(h**2))  # нормировка к единичной энергии
    return h


def main():
    # 1. Генерация QPSK-символов
    bits = np.random.randint(0, 2, (N_SYM, 2))
    # Gray: 00→(+1,+1), 01→(+1,-1), 11→(-1,-1), 10→(-1,+1)
    syms_i = (1 - 2 * bits[:, 0]) / sqrt(2.0)
    syms_q = (1 - 2 * bits[:, 1]) / sqrt(2.0)

    # 2. Передискретизация + RRC TX
    rrc = rcosdesign(ROLLOFF, SPAN, SPS_TX, 'sqrt')
    # Upsampling
    sig_up_i = zeros(N_SYM * SPS_TX)
    sig_up_q = zeros(N_SYM * SPS_TX)
    sig_up_i[::SPS_TX] = syms_i
    sig_up_q[::SPS_TX] = syms_q
    sig_tx_i = convolve(sig_up_i, rrc, mode='same')
    sig_tx_q = convolve(sig_up_q, rrc, mode='same')

    # 3. Timing offset (дробная задержка через sinc-интерполяцию)
    delay_samples = TIMING_OFF * SPS_TX
    n_orig = arange(len(sig_tx_i))
    n_new = n_orig - delay_samples
    sig_del_i = np.interp(n_new, n_orig, sig_tx_i)
    sig_del_q = np.interp(n_new, n_orig, sig_tx_q)

    # 4. AWGN
    k_bits = 2  # QPSK
    snr_lin = 10.0 ** (EBN0_DB / 10.0) * k_bits / SPS_TX
    noise_std = 1.0 / sqrt(2.0 * snr_lin)
    sig_rx_i = sig_del_i + noise_std * np.random.randn(len(sig_del_i))
    sig_rx_q = sig_del_q + noise_std * np.random.randn(len(sig_del_q))

    # 5. RRC RX + децимация до sps_rx = 2
    decim = SPS_TX // SPS_RX
    sig_mf_i = convolve(sig_rx_i, rrc, mode='same') / SPS_TX
    sig_mf_q = convolve(sig_rx_q, rrc, mode='same') / SPS_TX
    # Децимация
    sig_dec_i = sig_mf_i[::decim]
    sig_dec_q = sig_mf_q[::decim]
    # Убираем переходные процессы фильтра
    trim = SPAN * SPS_RX
    sig_dec_i = sig_dec_i[trim:-trim]
    sig_dec_q = sig_dec_q[trim:-trim]

    N_out = len(sig_dec_i)
    print(f"[gen_sync_top_stimulus] Generated {N_out} samples (sps_rx={SPS_RX})")

    # 6. Квантование до Q1.15
    scale = 0.9 / max(np.max(np.abs(sig_dec_i)), np.max(np.abs(sig_dec_q)))
    sig_dec_i *= scale
    sig_dec_q *= scale
    qi = np.round(sig_dec_i * (2**(W_IN-1))).astype(int)
    qq = np.round(sig_dec_q * (2**(W_IN-1))).astype(int)
    qi = np.clip(qi, -(2**(W_IN-1)), 2**(W_IN-1)-1)
    qq = np.clip(qq, -(2**(W_IN-1)), 2**(W_IN-1)-1)

    # 7. Запись hex-файлов
    with open('sync_stim_i.hex', 'w') as f:
        for v in qi:
            f.write(f"{v & 0xFFFF:04x}\n")
    with open('sync_stim_q.hex', 'w') as f:
        for v in qq:
            f.write(f"{v & 0xFFFF:04x}\n")

    # 8. Запись золотых символов для сравнения
    np.savez('sync_golden.npz',
             tx_syms_i=syms_i, tx_syms_q=syms_q,
             rx_i=qi, rx_q=qq,
             K1=K1, K2=K2, N_out=N_out,
             timing_offset=TIMING_OFF, EbN0=EBN0_DB)

    # 9. Вычисление hex-значений коэффициентов для тестбенча
    k1_q15 = int(round(K1 * (2**15)))
    k2_q15 = int(round(K2 * (2**15)))
    w_nom  = int(round(0.5 * (2**16)))  # 1/sps_rx = 0.5 → 0x8000
    clamp  = int(round(0.5 * (2**15)))  # ±0.5·W_nom → 0x4000

    print(f"[gen_sync_top_stimulus] PI coefficients:")
    print(f"  K1 = {K1:.6f} → 0x{k1_q15 & 0xFFFF:04X} (Q1.15)")
    print(f"  K2 = {K2:.6f} → 0x{k2_q15 & 0xFFFF:04X} (Q1.15)")
    print(f"  W_nom = 0.5 → 0x{w_nom & 0xFFFF:04X}")
    print(f"  CLAMP = 0x{clamp & 0xFFFF:04X}")
    print(f"  N_samples = {N_out} (0x{N_out:04X})")

    # Записать параметры в отдельный файл для include в testbench
    with open('sync_params.vh', 'w') as f:
        f.write(f"// Автоматически сгенерировано gen_sync_top_stimulus.py\n")
        f.write(f"localparam N_STIM      = {N_out};\n")
        f.write(f"localparam [15:0] K1_VAL    = 16'h{k1_q15 & 0xFFFF:04X};\n")
        f.write(f"localparam [15:0] K2_VAL    = 16'h{k2_q15 & 0xFFFF:04X};\n")
        f.write(f"localparam [15:0] W_NOM_VAL = 16'h{w_nom & 0xFFFF:04X};\n")
        f.write(f"localparam [15:0] CLAMP_VAL = 16'h{clamp & 0xFFFF:04X};\n")


if __name__ == '__main__':
    main()
