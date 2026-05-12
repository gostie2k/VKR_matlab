#!/usr/bin/env python3
"""
gardner_golden.py — bit-accurate floating-point эталон петли Gardner
для поточечной сверки с HDL sync_top.

Воспроизводит gardner_canonical_rice.m с теми же hex-стимулами,
что подаются в tb_sync_top.v.
Пишет golden_internal.txt с внутренними сигналами для сравнения.

Kudimov, ВКР, Глава 3
"""

import numpy as np

# ============ Параметры (идентичны sync_params.vh) ============
W_IN = 16
sps_rx = 2
K1 = -0.019233
K2 = -0.000513

# ============ Чтение стимулов ============
def read_hex_signed(fname, width=16):
    vals = []
    with open(fname) as f:
        for line in f:
            line = line.strip()
            if line:
                v = int(line, 16)
                if v >= (1 << (width - 1)):
                    v -= (1 << width)
                vals.append(v)
    return np.array(vals, dtype=float)

sig_i = read_hex_signed('sync_stim_i.hex') / (2**(W_IN - 1))
sig_q = read_hex_signed('sync_stim_q.hex') / (2**(W_IN - 1))
sig = sig_i + 1j * sig_q
N = len(sig)
print(f"[gardner_golden] Loaded {N} samples")

# ============ Петля Gardner по схеме Rice ============
# (точная копия gardner_canonical_rice.m)
x_dl = np.zeros(4, dtype=complex)
CNT = 1.0
mu = 0.0
W = 1.0 / sps_rx
underflow = 0
TEDBuff = np.zeros(2, dtype=complex)
vi = 0.0

# Логи
y_strobe = []
log_cnt = []
log_mu = []
log_w = []
log_e = []
log_strobe = []  # 1 на итерацию где был strobe
log_xi = []

for n in range(N):
    # 1. Обновление линии задержки
    x_dl[3] = x_dl[2]
    x_dl[2] = x_dl[1]
    x_dl[1] = x_dl[0]
    x_dl[0] = sig[n]

    # 2. Piecewise parabolic Farrow
    v2 = 0.5 * (x_dl[0] - x_dl[1] - x_dl[2] + x_dl[3])
    v1 = 0.5 * (-x_dl[0] + 3*x_dl[1] - x_dl[2] - x_dl[3])
    v0 = x_dl[2]
    XI = (v2 * mu + v1) * mu + v0

    log_xi.append(XI)

    # 3. TED и PI (на underflow от предыдущей итерации)
    e_val = 0.0
    if underflow == 1:
        diff = TEDBuff[1] - XI
        e_val = np.real(TEDBuff[0]) * np.real(diff) + np.imag(TEDBuff[0]) * np.imag(diff)

        vp = K1 * e_val
        vi = vi + K2 * e_val
        # clamp vi
        clamp = 0.5 * W
        vi = max(min(vi, clamp), -clamp)
        v_pi = vp + vi
        v_pi = max(min(v_pi, clamp), -clamp)

        W = 1.0 / sps_rx + v_pi
        y_strobe.append(XI)
        log_strobe.append(1)
    else:
        log_strobe.append(0)

    log_e.append(e_val)
    log_cnt.append(CNT)
    log_mu.append(mu)
    log_w.append(W)

    # 4. NCO
    CNT_next = CNT - W
    if CNT_next < 0:
        CNT_next = CNT_next + 1
        underflow = 1
        mu = CNT / W
    else:
        underflow = 0

    CNT = CNT_next

    # 5. TEDBuff
    TEDBuff[1] = TEDBuff[0]
    TEDBuff[0] = XI

# ============ Анализ результата ============
y_strobe = np.array(y_strobe)
print(f"[gardner_golden] Output symbols: {len(y_strobe)}")

warmup = 100
if len(y_strobe) > warmup:
    si = np.real(y_strobe[warmup:])
    sq = np.imag(y_strobe[warmup:])
    sc = max(np.mean(np.abs(si)), np.mean(np.abs(sq)))
    si_n, sq_n = si / sc, sq / sc
    di, dq = np.sign(si_n), np.sign(sq_n)
    ep = np.mean((si_n - di)**2 + (sq_n - dq)**2)
    sp = np.mean(di**2 + dq**2)
    mer_db = 10 * np.log10(sp / ep) if ep > 0 else 99
    print(f"[gardner_golden] MER = {mer_db:.1f} dB (floating-point эталон)")
    print(f"[gardner_golden] W final = {log_w[-1]:.6f}")
else:
    print("[gardner_golden] Too few symbols for MER")

# ============ Запись внутренних сигналов ============
with open('golden_internal.txt', 'w') as f:
    f.write("# n strobe CNT mu W e XI_re XI_im\n")
    for n in range(N):
        f.write(f"{n} {log_strobe[n]} {log_cnt[n]:.8f} {log_mu[n]:.8f} "
                f"{log_w[n]:.8f} {log_e[n]:.8f} "
                f"{np.real(log_xi[n]):.8f} {np.imag(log_xi[n]):.8f}\n")

print(f"[gardner_golden] Internal log: golden_internal.txt ({N} lines)")

# ============ Запись символов для сравнения ============
with open('golden_symbols.txt', 'w') as f:
    for s in y_strobe:
        f.write(f"{np.real(s):.8f} {np.imag(s):.8f}\n")

print(f"[gardner_golden] Symbols: golden_symbols.txt ({len(y_strobe)} lines)")
