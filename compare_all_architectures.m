%% compare_all_architectures.m
% Сводный график: теория QPSK + эталон Mathworks + Rice+Farrow + round-period.
% Финальный сравнительный рисунок этапа 2.9 (рисунок 19 в дневнике).
%
% Прогон состоит из двух независимых частей:
%   Часть A: sps_rx = 2  — для Rice+Farrow и эталона при sps=2
%   Часть B: sps_rx = 40 — для round-period
% =====================================================================

clear; clc; close all;

%% ====== Общие параметры ======
M       = 4;
k_bits  = log2(M);
sps_tx  = 40;            % высокий sps на TX, чтобы оба варианта получали
                         % один и тот же исходный сигнал для честности
rolloff = 0.35;
span    = 10;

timing_offset = 0.3;

% Параметры эталонной петли
BnT  = 0.02;
zeta = 1/sqrt(2);
Kp   = 2.7;

% Коэффициенты PI для Rice+Farrow (вычисляются по формулам Rice)
theta_n  = BnT / (zeta + 1/(4*zeta));
K0Kp_K1  = (4*zeta*theta_n)  / (1 + 2*zeta*theta_n + theta_n^2);
K0Kp_K2  = (4*theta_n^2)     / (1 + 2*zeta*theta_n + theta_n^2);
K0       = -1;
K1_rice  = K0Kp_K1 / (K0*Kp);
K2_rice  = K0Kp_K2 / (K0*Kp);

% Коэффициенты PI для round-period (степени двойки, как у советника)
K1_rp = -2^-2;
K2_rp = -2^-8;
quant_bits = 8;

% Параметры исследования
EbNo_dB_vec = 0:1:12;
sym_per_run = 50000;
warmup_sym  = 1000;

%% ====== Часть A: sps_rx = 2 (Rice+Farrow и эталон) ======
fprintf('\n=== Часть A: sps_rx = 2 ===\n');

sps_rx_A = 2;
decim_A  = sps_tx / sps_rx_A;

txFilter_A = comm.RaisedCosineTransmitFilter( ...
    'Shape', 'Square root', 'RolloffFactor', rolloff, ...
    'FilterSpanInSymbols', span, 'OutputSamplesPerSymbol', sps_tx);

varDelay_A = dsp.VariableFractionalDelay( ...
    'InterpolationMethod', 'FIR', 'FilterHalfLength', 4);

rxFilter_A = comm.RaisedCosineReceiveFilter( ...
    'Shape', 'Square root', 'RolloffFactor', rolloff, ...
    'FilterSpanInSymbols', span, 'InputSamplesPerSymbol', sps_tx, ...
    'DecimationFactor', decim_A);

ber_ref_A  = zeros(size(EbNo_dB_vec));
ber_rice   = zeros(size(EbNo_dB_vec));

fprintf('%-8s  %-12s   %-12s\n', 'Eb/N0', 'BER_ref(s2)', 'BER_rice(s2)');
fprintf('---------------------------------------------\n');

for idx = 1:length(EbNo_dB_vec)
    EbNo_dB = EbNo_dB_vec(idx);
    rng(42 + idx);

    reset(txFilter_A); reset(varDelay_A); reset(rxFilter_A);

    idx_tx = randi([0 M-1], sym_per_run, 1);
    sym_tx = pskmod(idx_tx, M, pi/4, 'gray');
    sig_tx = txFilter_A(sym_tx);
    sig_delayed = varDelay_A(sig_tx, timing_offset * sps_tx);

    chan = comm.AWGNChannel( ...
        'NoiseMethod', 'Signal to noise ratio (Eb/No)', ...
        'EbNo', EbNo_dB, 'BitsPerSymbol', k_bits, ...
        'SignalPower', 1/sps_tx, 'SamplesPerSymbol', sps_tx);
    sig_noisy = chan(sig_delayed);
    sig_mf    = rxFilter_A(sig_noisy);

    % Эталон при sps = 2
    symSync = comm.SymbolSynchronizer( ...
        'TimingErrorDetector', 'Gardner (non-data-aided)', ...
        'SamplesPerSymbol', sps_rx_A, 'DampingFactor', zeta, ...
        'NormalizedLoopBandwidth', BnT, 'DetectorGain', Kp);
    sym_ref = symSync(sig_mf);
    [n_e, n_c] = find_best_alignment(idx_tx, sym_ref, M, warmup_sym);
    ber_ref_A(idx) = n_e / max(n_c * k_bits, 1);

    % Rice+Farrow
    sym_rice = gardner_canonical_rice(sig_mf, sps_rx_A, K1_rice, K2_rice);
    [n_e, n_c] = find_best_alignment(idx_tx, sym_rice, M, warmup_sym);
    ber_rice(idx) = n_e / max(n_c * k_bits, 1);

    fprintf('%-8.1f  %-12.3e   %-12.3e\n', ...
        EbNo_dB, ber_ref_A(idx), ber_rice(idx));
end

%% ====== Часть B: sps_rx = 40 (round-period) ======
fprintf('\n=== Часть B: sps_rx = 40 ===\n');

sps_rx_B = 40;

txFilter_B = comm.RaisedCosineTransmitFilter( ...
    'Shape', 'Square root', 'RolloffFactor', rolloff, ...
    'FilterSpanInSymbols', span, 'OutputSamplesPerSymbol', sps_tx);

varDelay_B = dsp.VariableFractionalDelay( ...
    'InterpolationMethod', 'FIR', 'FilterHalfLength', 4);

rxFilter_B = comm.RaisedCosineReceiveFilter( ...
    'Shape', 'Square root', 'RolloffFactor', rolloff, ...
    'FilterSpanInSymbols', span, 'InputSamplesPerSymbol', sps_tx, ...
    'DecimationFactor', 1);

ber_rp = zeros(size(EbNo_dB_vec));

fprintf('%-8s  %-12s\n', 'Eb/N0', 'BER_rp(s40)');
fprintf('-----------------------\n');

for idx = 1:length(EbNo_dB_vec)
    EbNo_dB = EbNo_dB_vec(idx);
    rng(42 + idx);    % тот же seed, что в части A

    reset(txFilter_B); reset(varDelay_B); reset(rxFilter_B);

    idx_tx = randi([0 M-1], sym_per_run, 1);
    sym_tx = pskmod(idx_tx, M, pi/4, 'gray');
    sig_tx = txFilter_B(sym_tx);
    sig_delayed = varDelay_B(sig_tx, timing_offset * sps_tx);

    chan = comm.AWGNChannel( ...
        'NoiseMethod', 'Signal to noise ratio (Eb/No)', ...
        'EbNo', EbNo_dB, 'BitsPerSymbol', k_bits, ...
        'SignalPower', 1/sps_tx, 'SamplesPerSymbol', sps_tx);
    sig_noisy = chan(sig_delayed);
    sig_mf    = rxFilter_B(sig_noisy);

    sym_rp = gardner_round_period(sig_mf, sps_rx_B, K1_rp, K2_rp, quant_bits);
    [n_e, n_c] = find_best_alignment(idx_tx, sym_rp, M, warmup_sym);
    ber_rp(idx) = n_e / max(n_c * k_bits, 1);

    fprintf('%-8.1f  %-12.3e\n', EbNo_dB, ber_rp(idx));
end

%% ====== Теоретическая кривая ======
EbNo_lin   = 10.^(EbNo_dB_vec/10);
ber_theory = qfunc(sqrt(2*EbNo_lin));

%% ====== Сводный график ======
figure('Name','Сводное сравнение архитектур','Position',[100 100 1000 700]);

semilogy(EbNo_dB_vec, ber_theory, 'k-',  'LineWidth', 2.5); hold on;
semilogy(EbNo_dB_vec, ber_ref_A,  'bo-', 'LineWidth', 1.5, ...
         'MarkerSize', 9, 'MarkerFaceColor', 'b');
semilogy(EbNo_dB_vec, ber_rice,   'rs-', 'LineWidth', 1.5, ...
         'MarkerSize', 9, 'MarkerFaceColor', 'r');
semilogy(EbNo_dB_vec, ber_rp,     'gd-', 'LineWidth', 1.5, ...
         'MarkerSize', 9, 'MarkerFaceColor', 'g');

grid on;
xlabel('E_b/N_0, дБ', 'FontSize', 13);
ylabel('BER',         'FontSize', 13);
title('Сравнение архитектур символьной синхронизации Gardner', ...
      'FontSize', 13);
legend('Теоретическая кривая QPSK в AWGN', ...
       'Эталон comm.SymbolSynchronizer (sps = 2)', ...
       'gardner\_canonical\_rice (Farrow + NCO, sps = 2)', ...
       'gardner\_round\_period (round-period, sps = 40)', ...
       'Location', 'southwest', 'FontSize', 11);
ylim([1e-6 1]);
xlim([min(EbNo_dB_vec)-0.5 max(EbNo_dB_vec)+0.5]);

%% ====== Сводная таблица ======
fprintf('\n\n=== Сводная таблица BER ===\n');
fprintf('%-8s %-12s %-12s %-12s %-12s\n', ...
    'Eb/N0', 'Теория', 'Mathworks', 'Rice+Farrow', 'Round-period');
fprintf('-----------------------------------------------------------------\n');
for idx = 1:length(EbNo_dB_vec)
    fprintf('%-8.1f %-12.3e %-12.3e %-12.3e %-12.3e\n', ...
        EbNo_dB_vec(idx), ber_theory(idx), ...
        ber_ref_A(idx), ber_rice(idx), ber_rp(idx));
end

fprintf('\nГотово.\n');

%% ====== Функция выравнивания (lat 0..30) ======
function [n_errs_min, n_compare_best] = ...
         find_best_alignment(idx_tx, sym_rx, M, warmup)
    k_bits = log2(M);
    n_errs_min = inf;
    n_compare_best = 0;
    if length(sym_rx) <= warmup || length(idx_tx) <= warmup
        return;
    end
    sym_rx_w = sym_rx(warmup+1:end);
    idx_tx_w = idx_tx(warmup+1:end);
    for lat = 0:30
        if lat >= length(sym_rx_w), break; end
        b_sym = sym_rx_w(lat+1:end);
        n = min(length(idx_tx_w), length(b_sym));
        if n < 1000, continue; end
        a_idx = idx_tx_w(1:n);
        b_sym_n = b_sym(1:n);
        for rot = 0:3
            b_rot = b_sym_n * exp(1j*rot*pi/2);
            b_idx = pskdemod(b_rot, M, pi/4, 'gray');
            bits_a = de2bi(a_idx, k_bits, 'left-msb');
            bits_b = de2bi(b_idx, k_bits, 'left-msb');
            n_errs = sum(bits_a(:) ~= bits_b(:));
            if n_errs < n_errs_min
                n_errs_min = n_errs;
                n_compare_best = n;
            end
        end
    end
end