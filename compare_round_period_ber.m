%% compare_round_period_ber.m
% BER vs Eb/N0 для round-period реализации Gardner.
% Сравнение с эталоном comm.SymbolSynchronizer и теоретической кривой QPSK.
%
% Параметры — точно по схеме научного руководителя (parse_deb_data.m):
%   sps_rx = 40, K1 = -2^-2, K2 = -2^-8, quant_bits = 8.
%
% Этап 2.9, шаг 3.
% =====================================================================

clear; clc; close all;

%% ====== Параметры системы ======
M       = 4;
k_bits  = log2(M);
sps_tx  = 40;            % КАК У СОВЕТНИКА
sps_rx  = 40;            % без децимации
rolloff = 0.35;
span    = 10;

timing_offset = 0.3;

% Параметры эталонной петли (для comm.SymbolSynchronizer)
BnT  = 0.02;
zeta = 1/sqrt(2);
Kp   = 2.7;

% Параметры round-period петли (схема советника, степени двойки)
K1_rp = -2^-2;     % -0.25
K2_rp = -2^-8;     % -0.00390625
quant_bits = 8;

%% ====== Параметры исследования ======
EbNo_dB_vec = 0:1:12;
sym_per_run = 50000;
warmup_sym  = 1000;

%% ====== System objects ======
txFilter = comm.RaisedCosineTransmitFilter( ...
    'Shape', 'Square root', 'RolloffFactor', rolloff, ...
    'FilterSpanInSymbols', span, 'OutputSamplesPerSymbol', sps_tx);

varDelay = dsp.VariableFractionalDelay( ...
    'InterpolationMethod', 'FIR', 'FilterHalfLength', 4);

% Приёмный RRC БЕЗ децимации (вход = выход = 40 sps)
rxFilter = comm.RaisedCosineReceiveFilter( ...
    'Shape', 'Square root', 'RolloffFactor', rolloff, ...
    'FilterSpanInSymbols', span, 'InputSamplesPerSymbol', sps_tx, ...
    'DecimationFactor', 1);

%% ====== Главный цикл ======
ber_ref = zeros(size(EbNo_dB_vec));
ber_rp  = zeros(size(EbNo_dB_vec));

fprintf('\n=== Round-period vs comm.SymbolSynchronizer (sps = %d) ===\n', sps_rx);
fprintf('%-8s  %-12s %-12s   %-12s %-12s\n', ...
    'Eb/N0', 'BER_ref', 'Lat/Rot_ref', 'BER_rp', 'Lat/Rot_rp');
fprintf('-----------------------------------------------------------------------\n');

for idx = 1:length(EbNo_dB_vec)
    EbNo_dB = EbNo_dB_vec(idx);

    rng(42 + idx);    % фиксированный seed — один сигнал для обеих петель

    reset(txFilter); reset(varDelay); reset(rxFilter);

    % --- TX ---
    idx_tx = randi([0 M-1], sym_per_run, 1);
    sym_tx = pskmod(idx_tx, M, pi/4, 'gray');
    sig_tx = txFilter(sym_tx);
    sig_delayed = varDelay(sig_tx, timing_offset * sps_tx);

    % --- AWGN ---
    chan = comm.AWGNChannel( ...
        'NoiseMethod', 'Signal to noise ratio (Eb/No)', ...
        'EbNo', EbNo_dB, 'BitsPerSymbol', k_bits, ...
        'SignalPower', 1/sps_tx, 'SamplesPerSymbol', sps_tx);
    sig_noisy = chan(sig_delayed);
    sig_mf    = rxFilter(sig_noisy);

    % === Эталон: comm.SymbolSynchronizer (sps = 40) ===
    symSync = comm.SymbolSynchronizer( ...
        'TimingErrorDetector', 'Gardner (non-data-aided)', ...
        'SamplesPerSymbol', sps_rx, 'DampingFactor', zeta, ...
        'NormalizedLoopBandwidth', BnT, 'DetectorGain', Kp);
    sym_ref = symSync(sig_mf);

    [n_err_ref, n_cmp_ref, lat_ref, rot_ref] = ...
        find_best_alignment(idx_tx, sym_ref, M, warmup_sym);
    if n_cmp_ref > 0
        ber_ref(idx) = n_err_ref / (n_cmp_ref * k_bits);
    else
        ber_ref(idx) = NaN;
    end

    % === Round-period реализация ===
    sym_rp = gardner_round_period(sig_mf, sps_rx, K1_rp, K2_rp, quant_bits);

    [n_err_rp, n_cmp_rp, lat_rp, rot_rp] = ...
        find_best_alignment(idx_tx, sym_rp, M, warmup_sym);
    if n_cmp_rp > 0
        ber_rp(idx) = n_err_rp / (n_cmp_rp * k_bits);
    else
        ber_rp(idx) = NaN;
    end

    fprintf('%-8.1f  %-12.3e %d/%-11d %-12.3e %d/%d\n', ...
        EbNo_dB, ber_ref(idx), lat_ref, rot_ref, ...
        ber_rp(idx), lat_rp, rot_rp);
end

%% ====== Теоретическая кривая ======
EbNo_lin   = 10.^(EbNo_dB_vec/10);
ber_theory = qfunc(sqrt(2*EbNo_lin));

%% ====== График ======
figure('Name','Round-period BER','Position',[100 100 900 650]);
semilogy(EbNo_dB_vec, ber_theory, 'k-',  'LineWidth', 2); hold on;
semilogy(EbNo_dB_vec, ber_ref,    'bo-', 'LineWidth', 1.5, ...
         'MarkerSize', 8, 'MarkerFaceColor', 'b');
semilogy(EbNo_dB_vec, ber_rp,     'gd-', 'LineWidth', 1.5, ...
         'MarkerSize', 8, 'MarkerFaceColor', 'g');
grid on;
xlabel('E_b/N_0, дБ', 'FontSize', 12);
ylabel('BER',         'FontSize', 12);
title({'Помехоустойчивость QPSK с round-period реализацией Gardner', ...
       sprintf('(sps = %d, K_1 = -2^{-2}, K_2 = -2^{-8})', sps_rx)}, ...
       'FontSize', 12);
legend('Теоретическая (QPSK)', ...
       'comm.SymbolSynchronizer', ...
       'gardner\_round\_period', ...
       'Location', 'southwest', 'FontSize', 11);
ylim([1e-6 1]);
xlim([min(EbNo_dB_vec)-0.5 max(EbNo_dB_vec)+0.5]);

fprintf('\nГотово.\n');

%% ====== Функция выравнивания (расширенный диапазон lat 0..30) ======
function [n_errs_min, n_compare_best, best_lat, best_rot] = ...
         find_best_alignment(idx_tx, sym_rx, M, warmup)
    k_bits = log2(M);
    n_errs_min = inf;
    n_compare_best = 0;
    best_lat = 0;
    best_rot = 0;
    if length(sym_rx) <= warmup || length(idx_tx) <= warmup
        return;
    end
    sym_rx_w = sym_rx(warmup+1:end);
    idx_tx_w = idx_tx(warmup+1:end);
    for lat = 0:30                       % РАСШИРЕНО с 20 до 30
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
                best_lat = lat;
                best_rot = rot;
            end
        end
    end
end