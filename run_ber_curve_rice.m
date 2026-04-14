%% run_ber_curve_rice.m
% Измерение помехоустойчивости QPSK c собственной реализацией петли
% Gardner (gardner_canonical_rice) — каноническая схема Rice:
% piecewise parabolic Farrow + Mod-1 NCO + PI-фильтр.
%
% Финальная валидация реализации: BER vs Eb/N0 должна лечь на
% теоретическую кривую QPSK в AWGN так же, как это было для эталонного
% comm.SymbolSynchronizer (этап 2.6).
%
% Этап 2.9, шаг 1.
% =====================================================================

clear; clc; close all;

%% ====== 1. Параметры системы (как в этапе 2.6) ======
M       = 4;
k_bits  = log2(M);
sps_tx  = 8;
sps_rx  = 2;
decim   = sps_tx / sps_rx;
rolloff = 0.35;
span    = 10;

timing_offset = 0.3;     % дробное смещение в долях символа

BnT  = 0.02;
zeta = 1/sqrt(2);
Kp   = 2.7;              % gain Gardner TED для QPSK + RRC α = 0,35

%% ====== 2. Расчёт коэффициентов PI-фильтра по формулам Rice ======
% Эти коэффициенты зависят только от BnT, zeta, Kp и sps_rx,
% поэтому считаются один раз до главного цикла.
theta_n = BnT / (zeta + 1/(4*zeta));
K0Kp_K1 = (4*zeta*theta_n)  / (1 + 2*zeta*theta_n + theta_n^2);
K0Kp_K2 = (4*theta_n^2)     / (1 + 2*zeta*theta_n + theta_n^2);
K0 = -1;                                  % знак управления NCO
K1 = K0Kp_K1 / (K0*Kp);
K2 = K0Kp_K2 / (K0*Kp);

fprintf('Коэффициенты PI-фильтра (Rice):\n');
fprintf('  K1 = %+.6e\n', K1);
fprintf('  K2 = %+.6e\n', K2);

%% ====== 3. Параметры исследования ======
EbNo_dB_vec = 0:1:12;
sym_per_run = 50000;
warmup_sym  = 1000;       % срез на переходный процесс петли

%% ====== 4. System objects (создаются один раз) ======
txFilter = comm.RaisedCosineTransmitFilter( ...
    'Shape',                  'Square root', ...
    'RolloffFactor',          rolloff, ...
    'FilterSpanInSymbols',    span, ...
    'OutputSamplesPerSymbol', sps_tx);

varDelay = dsp.VariableFractionalDelay( ...
    'InterpolationMethod', 'FIR', ...
    'FilterHalfLength',    4);

rxFilter = comm.RaisedCosineReceiveFilter( ...
    'Shape',                  'Square root', ...
    'RolloffFactor',          rolloff, ...
    'FilterSpanInSymbols',    span, ...
    'InputSamplesPerSymbol',  sps_tx, ...
    'DecimationFactor',       decim);

%% ====== 5. Главный цикл ======
ber_meas   = zeros(size(EbNo_dB_vec));
nbits_used = zeros(size(EbNo_dB_vec));

fprintf('\n=== BER vs Eb/N0 (gardner_canonical_rice) ===\n');
fprintf('%-8s %-12s %-12s %-12s %-8s\n', ...
    'Eb/N0', 'Symbols', 'Errors', 'BER', 'Lat/Rot');
fprintf('--------------------------------------------------------\n');

for idx = 1:length(EbNo_dB_vec)
    EbNo_dB = EbNo_dB_vec(idx);

    % Сброс stateful System objects.
    % gardner_canonical_rice — чистая функция, собственного состояния
    % между запусками не хранит, поэтому обнулять нечего.
    reset(txFilter);
    reset(varDelay);
    reset(rxFilter);

    % --- TX ---
    idx_tx = randi([0 M-1], sym_per_run, 1);
    sym_tx = pskmod(idx_tx, M, pi/4, 'gray');
    sig_tx = txFilter(sym_tx);

    % --- Канал: дробная задержка ---
    sig_delayed = varDelay(sig_tx, timing_offset * sps_tx);

    % --- AWGN ---
    chan = comm.AWGNChannel( ...
        'NoiseMethod',      'Signal to noise ratio (Eb/No)', ...
        'EbNo',             EbNo_dB, ...
        'BitsPerSymbol',    k_bits, ...
        'SignalPower',      1/sps_tx, ...
        'SamplesPerSymbol', sps_tx);
    sig_noisy = chan(sig_delayed);

    % --- RX RRC + децимация до sps_rx = 2 ---
    sig_mf = rxFilter(sig_noisy);

    % --- Gardner Sync: наша реализация вместо comm.SymbolSynchronizer ---
    sym_rx = gardner_canonical_rice(sig_mf, sps_rx, K1, K2);

    % --- Поиск выравнивания (полный перебор по латентности и фазе) ---
    [n_errs, n_compare, lat, rot] = find_best_alignment( ...
        idx_tx, sym_rx, M, warmup_sym);

    if n_compare > 0
        ber_meas(idx)   = n_errs / (n_compare * k_bits);
        nbits_used(idx) = n_compare * k_bits;
    else
        ber_meas(idx) = NaN;
    end

    fprintf('%-8.1f %-12d %-12d %-12.3e %d/%d\n', ...
        EbNo_dB, n_compare, n_errs, ber_meas(idx), lat, rot);
end

%% ====== 6. Теоретическая кривая ======
EbNo_lin   = 10.^(EbNo_dB_vec/10);
ber_theory = qfunc(sqrt(2*EbNo_lin));

%% ====== 7. График ======
figure('Name','BER vs Eb/N0 (Rice)','Position',[100 100 800 600]);
semilogy(EbNo_dB_vec, ber_theory, 'k-',  'LineWidth', 2); hold on;
semilogy(EbNo_dB_vec, ber_meas,   'rs-', 'LineWidth', 1.5, ...
         'MarkerSize', 8, 'MarkerFaceColor', 'r');
grid on;
xlabel('E_b/N_0, дБ', 'FontSize', 12);
ylabel('BER',         'FontSize', 12);
title({'Помехоустойчивость QPSK с собственной реализацией', ...
       'петли Gardner (каноническая схема Rice)'}, 'FontSize', 12);
legend('Теоретическая (QPSK в AWGN)', ...
       'Измеренная (gardner\_canonical\_rice)', ...
       'Location', 'southwest', 'FontSize', 11);
ylim([1e-6 1]);
xlim([min(EbNo_dB_vec)-0.5 max(EbNo_dB_vec)+0.5]);

fprintf('\nГотово.\n');

%% ====== Полный перебор: латентность 0..20 + 4 фазовых поворота ======
function [n_errs_min, n_compare_best, best_lat, best_rot] = ...
         find_best_alignment(idx_tx, sym_rx, M, warmup)

    k_bits = log2(M);
    n_errs_min = inf;
    n_compare_best = 0;
    best_lat = 0;
    best_rot = 0;

    % Срезаем warmup с обеих сторон
    if length(sym_rx) <= warmup || length(idx_tx) <= warmup
        return;
    end
    sym_rx_w = sym_rx(warmup+1:end);
    idx_tx_w = idx_tx(warmup+1:end);

    % Перебор латентности 0..20
    for lat = 0:20
        if lat >= length(sym_rx_w), break; end

        b_sym = sym_rx_w(lat+1:end);
        n = min(length(idx_tx_w), length(b_sym));
        if n < 1000, continue; end

        a_idx = idx_tx_w(1:n);
        b_sym_n = b_sym(1:n);

        % Перебор 4 фазовых поворотов
        for rot = 0:3
            b_rot = b_sym_n * exp(1j*rot*pi/2);
            b_idx = pskdemod(b_rot, M, pi/4, 'gray');

            bits_a = de2bi(a_idx, k_bits, 'left-msb');
            bits_b = de2bi(b_idx, k_bits, 'left-msb');
            n_errs = sum(bits_a(:) ~= bits_b(:));

            if n_errs < n_errs_min
                n_errs_min = n_errs;
                n_compare_best = n;
                best_lat = lat;
                best_rot = rot;
            end
        end
    end
end