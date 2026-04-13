%% run_fxp_study.m
% Исследование деградации BER при квантовании сигнала на входе петли
% Этап 2.8: выбор минимальной разрядности для FPGA-реализации
% =====================================================================

clear; clc; close all;

%% ====== 1. Параметры системы ======
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

%% ====== 2. Параметры исследования ======
EbNo_dB_vec = 0:1:10;
WL_vec      = [4, 5, 6, 8, 10, 12, inf];    % разрядность; inf = без квантования (эталон)
WL_names    = {'4 бит','5 бит','6 бит', '8 бит', '10 бит', '12 бит', 'Floating (эталон)'};

sym_per_run = 30000;
warmup_sym  = 1000;

%% ====== 3. System objects ======
txFilter = comm.RaisedCosineTransmitFilter( ...
    'Shape', 'Square root', ...
    'RolloffFactor', rolloff, ...
    'FilterSpanInSymbols', span, ...
    'OutputSamplesPerSymbol', sps_tx);

varDelay = dsp.VariableFractionalDelay( ...
    'InterpolationMethod', 'FIR', 'FilterHalfLength', 4);

rxFilter = comm.RaisedCosineReceiveFilter( ...
    'Shape', 'Square root', ...
    'RolloffFactor', rolloff, ...
    'FilterSpanInSymbols', span, ...
    'InputSamplesPerSymbol', sps_tx, ...
    'DecimationFactor', decim);

%% ====== 4. Главный двойной цикл: WL × Eb/N0 ======
ber_matrix = zeros(length(WL_vec), length(EbNo_dB_vec));

fprintf('\n=== Fixed-point study: BER vs Eb/N0 для разных WL ===\n');

for wl_idx = 1:length(WL_vec)
    WL = WL_vec(wl_idx);
    
    fprintf('\n--- %s ---\n', WL_names{wl_idx});
    fprintf('%-8s %-12s %-12s %-12s\n', 'Eb/N0', 'Symbols', 'Errors', 'BER');
    
    for snr_idx = 1:length(EbNo_dB_vec)
        EbNo_dB = EbNo_dB_vec(snr_idx);
        
        % Свежий синхронизатор для каждой точки
        symSync = comm.SymbolSynchronizer( ...
            'TimingErrorDetector', 'Gardner (non-data-aided)', ...
            'SamplesPerSymbol', sps_rx, ...
            'DampingFactor', zeta, ...
            'NormalizedLoopBandwidth', BnT, ...
            'DetectorGain', Kp);
        
        reset(txFilter); reset(varDelay); reset(rxFilter);
        
        % --- TX ---
        idx_tx = randi([0 M-1], sym_per_run, 1);
        sym_tx = pskmod(idx_tx, M, pi/4, 'gray');
        sig_tx = txFilter(sym_tx);
        
        % --- Канал ---
        sig_delayed = varDelay(sig_tx, timing_offset * sps_tx);
        chan = comm.AWGNChannel( ...
            'NoiseMethod', 'Signal to noise ratio (Eb/No)', ...
            'EbNo', EbNo_dB, ...
            'BitsPerSymbol', k_bits, ...
            'SignalPower', 1/sps_tx, ...
            'SamplesPerSymbol', sps_tx);
        sig_noisy = chan(sig_delayed);
        
        % --- RX RRC + децимация ---
        sig_mf = rxFilter(sig_noisy);
        
       % --- Квантование сигнала на входе синхронизатора ---
if isinf(WL)
    sig_quant = sig_mf;
else
    % Диапазон [-1, +1) с шагом 2^(-WL+1) — более жёсткое квантование
    FL = WL - 1;
    lsb = 2^(-FL);
    max_val = 1 - lsb;
    min_val = -1;
    
    re_q = round(real(sig_mf) / lsb) * lsb;
    im_q = round(imag(sig_mf) / lsb) * lsb;
    re_q = max(min(re_q, max_val), min_val);
    im_q = max(min(im_q, max_val), min_val);
    
    sig_quant = complex(re_q, im_q);
end
        
        % --- Gardner Sync ---
        sym_rx = symSync(sig_quant);
        
        % --- BER ---
        [n_errs, n_compare, ~, ~] = find_best_alignment( ...
            idx_tx, sym_rx, M, warmup_sym);
        
        if n_compare > 0
            ber = n_errs / (n_compare * k_bits);
        else
            ber = NaN;
        end
        ber_matrix(wl_idx, snr_idx) = ber;
        
        fprintf('%-8.1f %-12d %-12d %-12.3e\n', ...
            EbNo_dB, n_compare, n_errs, ber);
    end
end

%% ====== 5. Теоретическая кривая ======
EbNo_lin = 10.^(EbNo_dB_vec/10);
ber_theory = qfunc(sqrt(2*EbNo_lin));

%% ====== 6. График ======
figure('Name','Fixed-point study','Position',[100 100 900 700]);
semilogy(EbNo_dB_vec, ber_theory, 'k-', 'LineWidth', 2); hold on;

colors = lines(length(WL_vec));
markers = {'o', 's', 'd', '^', 'v', 'p', 'h'};
for wl_idx = 1:length(WL_vec)
    semilogy(EbNo_dB_vec, ber_matrix(wl_idx, :), ...
        'Color', colors(wl_idx, :), ...
        'Marker', markers{wl_idx}, ...
        'LineWidth', 1.5, ...
        'MarkerSize', 8, ...
        'MarkerFaceColor', colors(wl_idx, :));
end

grid on;
xlabel('E_b/N_0, дБ', 'FontSize', 12);
ylabel('BER', 'FontSize', 12);
title('Деградация BER при квантовании входного сигнала', ...
      'FontSize', 12);
legend(['Теория (QPSK)'; WL_names(:)], ...
       'Location', 'southwest', 'FontSize', 10);
ylim([1e-6 1]);
xlim([min(EbNo_dB_vec)-0.5 max(EbNo_dB_vec)+0.5]);

fprintf('\nГотово.\n');

%% ====== Вспомогательная функция выравнивания ======
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