function gen_farrow_stimulus()
% gen_farrow_stimulus — формирование стимулов и золотого вектора для
% верификации HDL-модуля sync_farrow_parab
%
% Генерирует:
%   stim_i.hex  — входной I-канал в формате Q1.15 int16 (W_IN = 16)
%   stim_q.hex  — входной Q-канал в формате Q1.15 int16
%   stim_mu.hex — μ в формате Q0.12 uint12 (W_MU = 12)
%   golden_xi.mat — эталонные значения XI, посчитанные bit-accurate моделью
%
% Вход:      синтетический комплексный сигнал ± линейная развёртка μ
% Проверка:  после прогона ModelSim запустить check_farrow_result.m
%
% Kudimov, ВКР, глава 3, этап 3.1

%% ============ Параметры (должны совпадать с Verilog) ===================
W_IN  = 16;     % разрядность I/Q, знаковое Q1.15
W_MU  = 12;     % разрядность μ, беззнаковое Q0.12
W_OUT = 16;     % выходная разрядность
W_V   = W_IN + 2;

%% ============ 1. Формирование входных стимулов =========================
rng(12345, 'twister');  % фиксированный seed для воспроизводимости

% Два сценария наложены друг на друга, чтобы покрыть разные режимы работы:
%   (а) ступенька — реакция на скачок входа (проверка линии задержки)
%   (б) синус с фиксированной μ = 0.5 — проверка базового интерполянта
%   (в) развёртка μ от 0 до 1 при константном входе — проверка схемы Горнера
%   (г) реальный RRC-сигнал с изменяющейся μ — интегральная проверка

Nstep = 200;    % длина каждого сценария
N_total = 4 * Nstep;

sig_i = zeros(N_total, 1);
sig_q = zeros(N_total, 1);
mu    = zeros(N_total, 1);

% (а) ступенька: 0 → 0.5
range_a = 1:Nstep;
sig_i(range_a) = 0.5 * (range_a' > Nstep/2);
sig_q(range_a) = 0;
mu(range_a)    = 0.5;

% (б) синус с постоянной μ = 0.5 (середина интервала)
range_b = Nstep + (1:Nstep);
k = (0:Nstep-1)';
sig_i(range_b) = 0.7 * cos(2*pi*k/50);
sig_q(range_b) = 0.7 * sin(2*pi*k/50);
mu(range_b)    = 0.5;

% (в) константный вход, μ развёртка 0 → 1
range_c = 2*Nstep + (1:Nstep);
sig_i(range_c) = 0.3;
sig_q(range_c) = 0.4;
mu(range_c)    = linspace(0, 1 - 2^(-W_MU), Nstep)';  % не 1.0, μ ∈ [0,1)

% (г) синтетический RRC-сигнал с случайной μ
range_d = 3*Nstep + (1:Nstep);
rolloff = 0.35;
span = 10;
sps = 8;
rrc = rcosdesign(rolloff, span, sps, 'sqrt');
syms_rand = sign(randn(ceil(Nstep/sps)+2, 1)) + 1j*sign(randn(ceil(Nstep/sps)+2, 1));
syms_rand = syms_rand / sqrt(2);
sig_up = upfirdn(syms_rand, rrc, sps, 1);
sig_up = sig_up / max(abs(sig_up));
sig_i(range_d) = real(sig_up(1:Nstep));
sig_q(range_d) = imag(sig_up(1:Nstep));
mu(range_d)    = 0.2 + 0.6*rand(Nstep, 1);  % псевдослучайная μ в [0.2, 0.8]

%% ============ 2. Квантование до формата Verilog ========================
% I/Q: Q1.15 знаковое int16
sig_i_q = round(sig_i * 2^(W_IN-1));
sig_q_q = round(sig_q * 2^(W_IN-1));
% Насыщение до диапазона int16
sig_i_q = max(min(sig_i_q, 2^(W_IN-1)-1), -2^(W_IN-1));
sig_q_q = max(min(sig_q_q, 2^(W_IN-1)-1), -2^(W_IN-1));

% μ: Q0.12 беззнаковое uint12
mu_q = round(mu * 2^W_MU);
mu_q = max(min(mu_q, 2^W_MU - 1), 0);

%% ============ 3. Bit-accurate Verilog-подобная модель ==================
% Повторяем арифметику sync_farrow_parab.v цифра-в-цифру
% Результат — xi_i_q, xi_q_q — те значения, которые должен выдать HDL

N = length(sig_i_q);
xi_i_q = zeros(N, 1);
xi_q_q = zeros(N, 1);

% Линия задержки
dl1_i = 0; dl2_i = 0; dl3_i = 0;
dl1_q = 0; dl2_q = 0; dl3_q = 0;

% Конвейерные регистры
v2_r_i = 0; v1_r_i = 0; v0_r_i = 0; mu_r1 = 0;
v2_r_q = 0; v1_r_q = 0; v0_r_q = 0;
valid_r1 = false;

t_r_i = 0; v0_r2_i = 0; mu_r2 = 0;
t_r_q = 0; v0_r2_q = 0;
valid_r2 = false;

xi_r_i = 0; xi_r_q = 0;
valid_r3 = false;

for n = 1:N
    % --- Текущий вход ---
    x0_i = sig_i_q(n);
    x0_q = sig_q_q(n);
    mu_cur = mu_q(n);

    % --- Ступень 1: v-коэффициенты + μ регистрируются ---
    v2_new_i = floor((x0_i - dl1_i - dl2_i + dl3_i) / 2);
    v1_new_i = floor((-x0_i + 3*dl1_i - dl2_i - dl3_i) / 2);
    v0_new_i = dl2_i;

    v2_new_q = floor((x0_q - dl1_q - dl2_q + dl3_q) / 2);
    v1_new_q = floor((-x0_q + 3*dl1_q - dl2_q - dl3_q) / 2);
    v0_new_q = dl2_q;

    % --- Конвейер: старые значения распространяются в следующие ступени ---
    if valid_r2
        xi_r_i = farrow_stage3_rounding(t_r_i, mu_r2, v0_r2_i, W_MU, W_V, W_OUT);
        xi_r_q = farrow_stage3_rounding(t_r_q, mu_r2, v0_r2_q, W_MU, W_V, W_OUT);
        valid_r3_new = true;
    else
        valid_r3_new = false;
    end

    if valid_r1
        % Ступень 2: t = v2 · μ + v1, полная точность
        mu_sgn = mu_r1;  % Q0.W_MU как беззнаковое → знаковое с MSB = 0
        t_new_i = v2_r_i * mu_sgn + bitshift(v1_r_i, W_MU);
        t_new_q = v2_r_q * mu_sgn + bitshift(v1_r_q, W_MU);
        v0_r2_new_i = v0_r_i;
        v0_r2_new_q = v0_r_q;
        mu_r2_new = mu_r1;
        valid_r2_new = true;
    else
        t_new_i = 0; t_new_q = 0;
        v0_r2_new_i = 0; v0_r2_new_q = 0;
        mu_r2_new = 0;
        valid_r2_new = false;
    end

    % Обновление конвейерных регистров в конце такта
    v2_r_i = v2_new_i; v1_r_i = v1_new_i; v0_r_i = v0_new_i;
    v2_r_q = v2_new_q; v1_r_q = v1_new_q; v0_r_q = v0_new_q;
    mu_r1 = mu_cur;
    valid_r1 = true;   % in_valid = 1 всегда в этом тесте

    t_r_i = t_new_i; t_r_q = t_new_q;
    v0_r2_i = v0_r2_new_i; v0_r2_q = v0_r2_new_q;
    mu_r2 = mu_r2_new;
    valid_r2 = valid_r2_new;

    valid_r3 = valid_r3_new;

    % --- Обновление линии задержки ---
    dl3_i = dl2_i; dl2_i = dl1_i; dl1_i = x0_i;
    dl3_q = dl2_q; dl2_q = dl1_q; dl1_q = x0_q;

    % --- Логирование выхода (с учётом латентности) ---
    if valid_r3
        xi_i_q(n) = xi_r_i;
        xi_q_q(n) = xi_r_q;
    else
        xi_i_q(n) = 0;
        xi_q_q(n) = 0;
    end
end

%% ============ 4. Запись стимулов в hex для $readmemh ===================
% $readmemh читает hex в знаковые регистры correctly: для int16 записываем
% беззнаковую двоичную интерпретацию

fid = fopen('stim_i.hex', 'w');
for n = 1:N
    val = mod(sig_i_q(n), 2^W_IN);
    fprintf(fid, '%04x\n', val);
end
fclose(fid);

fid = fopen('stim_q.hex', 'w');
for n = 1:N
    val = mod(sig_q_q(n), 2^W_IN);
    fprintf(fid, '%04x\n', val);
end
fclose(fid);

fid = fopen('stim_mu.hex', 'w');
for n = 1:N
    fprintf(fid, '%03x\n', mu_q(n));
end
fclose(fid);

%% ============ 5. Сохранение золотого вектора ============================
save('golden_xi.mat', 'sig_i_q', 'sig_q_q', 'mu_q', 'xi_i_q', 'xi_q_q', 'N', ...
                     'W_IN', 'W_MU', 'W_OUT');

fprintf('[gen_farrow_stimulus] Generated %d samples\n', N);
fprintf('[gen_farrow_stimulus] Files: stim_i.hex, stim_q.hex, stim_mu.hex, golden_xi.mat\n');

%% ============ 6. Диагностический график ================================
figure('Name', 'Farrow stimulus и золотой вектор', 'NumberTitle', 'off');
subplot(3,1,1);
plot(1:N, sig_i_q/2^(W_IN-1), 'b-', 1:N, sig_q_q/2^(W_IN-1), 'r-');
ylabel('Вход I/Q'); legend('I', 'Q'); grid on;
title('Стимулы для sync\_farrow\_parab');
subplot(3,1,2);
plot(1:N, mu_q/2^W_MU, 'k-');
ylabel('\mu'); grid on;
subplot(3,1,3);
plot(1:N, xi_i_q/2^(W_OUT-1), 'b-', 1:N, xi_q_q/2^(W_OUT-1), 'r-');
xlabel('Номер отсчёта n'); ylabel('Выход XI');
legend('XI_I (golden)', 'XI_Q (golden)'); grid on;

end


%% ---------- Вспомогательная функция для ступени 3 -----------------------
function xi_out = farrow_stage3_rounding(t, mu, v0, W_MU, W_V, W_OUT)
% Вторая ступень Горнера + округление half-up + насыщение

xi_scaled = t * mu + bitshift(int64(v0), 2*W_MU);

% Позиция LSB выхода
SHIFT_OUT = 2*W_MU + (W_V - W_OUT);

% Округление
round_const = int64(2)^(SHIFT_OUT - 1);
xi_rounded = int64(xi_scaled) + round_const;

% Арифметический сдвиг вправо
xi_shifted = floor(double(xi_rounded) / 2^SHIFT_OUT);

% Насыщение до Q1.(W_OUT-1)
sat_pos = 2^(W_OUT-1) - 1;
sat_neg = -2^(W_OUT-1);
xi_out = max(min(xi_shifted, sat_pos), sat_neg);

end
