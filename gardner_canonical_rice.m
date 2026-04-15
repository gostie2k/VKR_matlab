function [y_strobe, mu_log, e_log, Kagc_log] = gardner_canonical_rice(sig, sps_rx, K1, K2)
% gardner_canonical_rice — каноническая реализация петли Gardner по схеме Rice
% Piecewise parabolic Farrow + Mod-1 NCO + PI-фильтр + AGC
%
% Вход:
%   sig    — комплексный вектор отсчётов с приёмного RRC (sps_rx на символ)
%   sps_rx — отсчётов на символ (обычно 2)
%   K1, K2 — коэффициенты PI-фильтра (отрицательные, K0 = -1 учтён)
%
% Выход:
%   y_strobe — комплексный вектор стробированных символов (1 на символ)
%   mu_log   — лог дробной задержки во времени
%   e_log    — лог сигнала ошибки в strobe-моменты
%   Kagc_log — лог коэффициента AGC в strobe-моменты

N = length(sig);

% --- Номинальный шаг NCO и пределы ограничения ---
W_nom   = 1/sps_rx;
W_max   = W_nom * 1.5;
W_min   = W_nom * 0.5;
vi_lim  = W_nom * 0.5;

% --- AGC ---
% Целевая мощность строба: |XI*Kagc|^2 = 1
% Bagc — шаг адаптации (степень двойки для будущей фиксированной арифметики)
Bagc     = 2^-7;
Kagc     = 1;
Kagc_min = 0.1;
Kagc_max = 10;

% --- Линия задержки Farrow: x_dl(1) = свежий, x_dl(4) = старый ---
x_dl = complex(zeros(4, 1));

% --- Состояние NCO ---
CNT = 1;
mu = 0;
W = W_nom;
underflow = 0;

% --- TED shift register ---
TEDBuff = complex(zeros(2, 1));

% --- Состояние PI-фильтра ---
vi = 0;

% --- Логи ---
y_strobe = complex(zeros(N, 1));
mu_log   = zeros(N, 1);
e_log    = zeros(N, 1);
Kagc_log = zeros(N, 1);
k_out = 0;

for n = 1:N

    % --- 1. Обновление линии задержки ---
    x_dl(4) = x_dl(3);
    x_dl(3) = x_dl(2);
    x_dl(2) = x_dl(1);
    x_dl(1) = sig(n);

    % --- 2. Piecewise parabolic Farrow ---
    v2 = 0.5*( x_dl(1) - x_dl(2) - x_dl(3) + x_dl(4));
    v1 = 0.5*(-x_dl(1) + 3*x_dl(2) - x_dl(3) - x_dl(4));
    v0 = x_dl(3);
    XI = (v2*mu + v1)*mu + v0;

    % --- 3. AGC: масштабируем КАЖДЫЙ XI (не только стробы) ---
    %     Это нужно, чтобы TEDBuff содержал уже нормированные значения,
    %     иначе TED увидит несогласованные амплитуды mid/strobe.
    XI_agc = XI * Kagc;

    % --- 4. TED ---
    if underflow == 1
        diff = TEDBuff(2) - XI_agc;
        e = real(TEDBuff(1)) * real(diff) + imag(TEDBuff(1)) * imag(diff);
    else
        e = 0;
    end

    % --- 5. PI-фильтр и обновление W (на каждом такте) ---
    vp = K1 * e;
    vi = vi + K2 * e;
    vi = max(min(vi, vi_lim), -vi_lim);
    v_pi = vp + vi;
    W = max(min(W_nom + v_pi, W_max), W_min);

    % --- 6. Выход и обновление AGC на стробе ---
    if underflow == 1
        k_out = k_out + 1;
        y_strobe(k_out) = XI_agc;
        e_log(k_out) = e;

        % AGC LMS-update по мощности строба
        Kagc = Kagc + Bagc * (1 - abs(XI_agc)^2);
        Kagc = max(min(Kagc, Kagc_max), Kagc_min);
    end
    Kagc_log(n) = Kagc;

    % --- 7. NCO: декремент регистра ---
    CNT_next = CNT - W;
    if CNT_next < 0
        CNT_next = CNT_next + 1;
        underflow = 1;
        mu = CNT / W;
    else
        underflow = 0;
    end
    CNT = CNT_next;

    % --- 8. TEDBuff: сдвиг на каждом такте, хранит нормированные XI_agc ---
    TEDBuff(2) = TEDBuff(1);
    TEDBuff(1) = XI_agc;

    mu_log(n) = mu;
end

y_strobe = y_strobe(1:k_out);
e_log    = e_log(1:k_out);

end