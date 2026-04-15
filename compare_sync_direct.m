%% compare_sync_direct.m
% Прямое сравнение: comm.SymbolSynchronizer vs gardner_canonical_rice
% на ОДНОМ сигнале с ОДНИМ rng-seed.
% Этап 2.9, диагностический прогон.
% =====================================================================

clear; clc; close all;

%% ====== Параметры (идентичны run_ber_curve_rice.m) ======
M       = 4;
k_bits  = log2(M);
sps_tx  = 8;
sps_rx  = 2;
decim   = sps_tx / sps_rx;
rolloff = 0.35;
span    = 10;

timing_offset = 0.3;
BnT  = 0.02;
zeta = 1/sqrt(2);
Kp   = 2.7;

% Коэффициенты PI-фильтра
theta_n = BnT / (zeta + 1/(4*zeta));
K0Kp_K1 = (4*zeta*theta_n)  / (1 + 2*zeta*theta_n + theta_n^2);
K0Kp_K2 = (4*theta_n^2)     / (1 + 2*zeta*theta_n + theta_n^2);
K0 = -1;
K1 = K0Kp_K1 / (K0*Kp);
K2 = K0Kp_K2 / (K0*Kp);

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

rxFilter = comm.RaisedCosineReceiveFilter( ...
    'Shape', 'Square root', 'RolloffFactor', rolloff, ...
    'FilterSpanInSymbols', span, 'InputSamplesPerSymbol', sps_tx, ...
    'DecimationFactor', decim);

%% ====== Главный цикл ======
ber_ref  = zeros(size(EbNo_dB_vec));
ber_rice = zeros(size(EbNo_dB_vec));

fprintf('\n=== Прямое сравнение: comm.SymbolSynchronizer vs gardner_canonical_rice ===\n');
fprintf('%-8s  %-12s %-12s   %-12s %-12s\n', ...
    'Eb/N0', 'BER_ref', 'Lat/Rot_ref', 'BER_rice', 'Lat/Rot_rice');
fprintf('------------------------------------------------------------------------\n');

for idx = 1:length(EbNo_dB_vec)
    EbNo_dB = EbNo_dB_vec(idx);
    
    rng(42 + idx);    % фиксированный seed — один и тот же сигнал для обоих
    
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
    
    % === Эталон: comm.SymbolSynchronizer ===
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
    
    % === Наша реализация ===
    sym_rice = gardner_canonical_rice(sig_mf, sps_rx, K1, K2);
    
    [n_err_rice, n_cmp_rice, lat_rice, rot_rice] = ...
        find_best_alignment(idx_tx, sym_rice, M, warmup_sym);
    if n_cmp_rice > 0
        ber_rice(idx) = n_err_rice / (n_cmp_rice * k_bits);
    else
        ber_rice(idx) = NaN;
    end
    
    fprintf('%-8.1f  %-12.3e %d/%-11d %-12.3e %d/%d\n', ...
        EbNo_dB, ber_ref(idx), lat_ref, rot_ref, ...
        ber_rice(idx), lat_rice, rot_rice);
end

%% ====== Теоретическая кривая ======
EbNo_lin   = 10.^(EbNo_dB_vec/10);
ber_theory = qfunc(sqrt(2*EbNo_lin));

%% ====== График ======
figure('Name','Direct Comparison','Position',[100 100 900 650]);
semilogy(EbNo_dB_vec, ber_theory, 'k-',  'LineWidth', 2); hold on;
semilogy(EbNo_dB_vec, ber_ref,    'bo-', 'LineWidth', 1.5, ...
         'MarkerSize', 8, 'MarkerFaceColor', 'b');
semilogy(EbNo_dB_vec, ber_rice,   'rs-', 'LineWidth', 1.5, ...
         'MarkerSize', 8, 'MarkerFaceColor', 'r');
grid on;
xlabel('E_b/N_0, дБ', 'FontSize', 12);
ylabel('BER',         'FontSize', 12);
title('Прямое сравнение на одном сигнале', 'FontSize', 12);
legend('Теоретическая (QPSK)', ...
       'comm.SymbolSynchronizer', ...
       'gardner\_canonical\_rice', ...
       'Location', 'southwest', 'FontSize', 11);
ylim([1e-6 1]);
xlim([min(EbNo_dB_vec)-0.5 max(EbNo_dB_vec)+0.5]);

fprintf('\nГотово.\n');

%% ====== Функция выравнивания (та же, что в run_ber_curve.m) ======
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
    for lat = 0:20
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