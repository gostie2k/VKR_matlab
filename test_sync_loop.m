%% test_sync_loop.m
% Полная модель цифрового приёмника с собственной петлёй Gardner
% Реализация петли по эталонной схеме Rice [1, гл. 8.4]
% =====================================================================

clear; clc; close all;

%% ====== 1. Параметры ======
M       = 4;
k_bits  = log2(M);
Rs      = 1e6;
Ts      = 1/Rs;
sps_tx  = 8;
Fs_tx   = Rs * sps_tx;
rolloff = 0.35;
span    = 10;
Nsym    = 5000;

timing_offset = 0.3;
EbNo_dB       = 30;

sps_rx = 2;
decim  = sps_tx / sps_rx;
Fs_rx  = Rs * sps_rx;

% Параметры петли
BnT  = 0.02;
zeta = 1/sqrt(2);
Kp   = 2.7;     % усиление детектора Gardner для RRC alpha=0.35

theta_n = BnT / (zeta + 1/(4*zeta));
K0Kp_K1 = (4*zeta*theta_n) / (1 + 2*zeta*theta_n + theta_n^2);
K0Kp_K2 = (4*theta_n^2)    / (1 + 2*zeta*theta_n + theta_n^2);
K1 = K0Kp_K1 / Kp;
K2 = K0Kp_K2 / Kp;

%% ====== 2. Передатчик ======
bits = randi([0 1], Nsym*k_bits, 1);
sym_tx = pskmod(bi2de(reshape(bits, k_bits, []).', 'left-msb'), M, pi/4, 'gray');

rrc_tx = rcosdesign(rolloff, span, sps_tx, 'sqrt');
sig_tx = upfirdn(sym_tx, rrc_tx, sps_tx);

%% ====== 3. Канал ======
delay_samples = timing_offset * sps_tx;
n_orig = (0:length(sig_tx)-1).';
n_new  = n_orig - delay_samples;
sig_delayed = interp1(n_orig, sig_tx, n_new, 'spline', 0);

sig_rx = awgn(sig_delayed, EbNo_dB + 10*log10(k_bits) - 10*log10(sps_tx), 'measured');

%% ====== 4. Приёмный RRC + децимация ======
rrc_rx = rcosdesign(rolloff, span, sps_tx, 'sqrt');
sig_mf = upfirdn(sig_rx, rrc_rx, 1, decim);
sig_mf = sig_mf / sps_tx;
sig_mf = sig_mf(span+1 : end-span);

%% ====== 5. Петля Gardner по схеме Rice ======
N = length(sig_mf);

% Линия задержки Farrow: 4 последних входных отсчёта
% Convention Rice: x_dl(1) = x[n] (самый свежий), x_dl(4) = x[n-3] (самый старый)
x_dl = zeros(4, 1);

% Состояние NCO
mu = 0;                       % дробная задержка
NCO = 1;                      % регистр счётчика (стартует с 1)
W = 1/sps_rx;                 % шаг NCO (изначально равный 1/sps)

% Состояние PI-фильтра
vi = 0;                       % выход интегратора (накопленная ошибка * K2)

% Память Gardner TED
y_strobe_curr = 0;            % текущий "решающий" отсчёт
y_strobe_prev = 0;            % предыдущий "решающий" отсчёт
y_mid         = 0;            % промежуточный отсчёт между ними

% Счётчик чередования strobe/mid
% В Rice используется бит, который переключается на каждом underflow:
% 0 -> mid (промежуточный), 1 -> strobe (решающий, тут работает TED)
underflow_count = 0;

% Логи
y_out  = zeros(N, 1);
e_log  = zeros(N, 1);
mu_log = zeros(N, 1);
W_log  = zeros(N, 1);
strobe_idx = false(N, 1);

n_out = 0;

for n = 1:N
    
    % --- Сдвиг линии задержки и новый вход ---
    x_dl = [sig_mf(n); x_dl(1:3)];   % x_dl(1)=новый, остальные сдвигаются
    
    % --- Кубический Farrow ---
    v3 =  (1/6)*x_dl(1) - (1/2)*x_dl(2) + (1/2)*x_dl(3) - (1/6)*x_dl(4);
    v2 =                  (1/2)*x_dl(2) -        x_dl(3) + (1/2)*x_dl(4);
    v1 = -(1/6)*x_dl(1) +        x_dl(2) - (1/2)*x_dl(3) - (1/3)*x_dl(4);
    v0 =                                          x_dl(3);
    y_interp = ((v3*mu + v2)*mu + v1)*mu + v0;
    
    % --- NCO: декремент текущего регистра ---
    NCO_new = NCO - W;
    
    % --- Проверка underflow ---
    if NCO_new < 0
        % Underflow произошёл — есть новый интерполированный отсчёт
        % Вычисляем mu (с учётом интерполяции по краям интервала)
        mu = NCO / W;
        
        % Чередуем strobe / mid
        underflow_count = underflow_count + 1;
        
        if mod(underflow_count, 2) == 1
            % Нечётный underflow → промежуточный отсчёт (mid)
            y_mid = y_interp;
        else
            % Чётный underflow → решающий strobe-отсчёт
            y_strobe_prev = y_strobe_curr;
            y_strobe_curr = y_interp;
            
            n_out = n_out + 1;
            y_out(n_out) = y_interp;
            strobe_idx(n) = true;
            
            % --- Gardner TED: e(k) = Re{ y_mid * conj(y[k] - y[k-1]) } ---
            % Это правильная формула из Rice [1, ур. 8.99]
            e = real( y_mid * conj(y_strobe_curr - y_strobe_prev) );
            e_log(n) = e;
            
            % --- PI-фильтр ---
            vi = vi + K2 * e;        % интегратор
            v_pi = K1 * e + vi;      % полный выход
            
            % --- Обновление шага NCO ---
            % Знак минус: NCO замедляется при положительной ошибке
            W = 1/sps_rx + v_pi;
        end
        
        % Сброс регистра NCO в положительный диапазон (mod 1)
        NCO = NCO_new + 1;
    else
        NCO = NCO_new;
    end
    
    mu_log(n) = mu;
    W_log(n)  = W;
end

y_out = y_out(1:n_out);

%% ====== 6. Графики ======
figure('Name','Custom Gardner Loop — результаты','Position',[100 100 1200 800]);

subplot(2,2,1);
plot(real(y_out), imag(y_out), '.', 'MarkerSize', 6); hold on;
plot([1 -1 -1 1]/sqrt(2), [1 1 -1 -1]/sqrt(2), 'r+', 'MarkerSize', 12, 'LineWidth', 2);
axis equal; grid on; xlim([-1.5 1.5]); ylim([-1.5 1.5]);
xlabel('In-phase'); ylabel('Quadrature');
title('Восстановленное созвездие');

subplot(2,2,2);
e_nz = e_log(strobe_idx);
plot(e_nz); grid on;
xlabel('Номер символа'); ylabel('e(k)');
title('Сигнал ошибки Gardner TED (только в моменты strobe)');

subplot(2,2,3);
plot(mu_log); grid on;
xlabel('Номер отсчёта'); ylabel('\mu');
title('Дробная задержка \mu');
ylim([-0.1 1.1]);

subplot(2,2,4);
plot(W_log); grid on;
xlabel('Номер отсчёта'); ylabel('W');
title('Шаг NCO');

fprintf('Симуляция завершена. Получено %d символов на выходе петли.\n', n_out);