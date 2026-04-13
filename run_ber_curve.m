%% run_ber_curve.m
% Измерение помехоустойчивости QPSK + Gardner Symbol Sync
% Все блоки — System objects из Communications Toolbox
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

timing_offset = 0.3;     % дробное смещение в долях символа

BnT  = 0.02;
zeta = 1/sqrt(2);
Kp   = 2.7;

%% ====== 2. Параметры исследования ======
EbNo_dB_vec = 0:1:12;
sym_per_run = 50000;
warmup_sym  = 1000;       % срез на переходный процесс петли

%% ====== 3. System objects (создаются один раз) ======
% Передающий RRC: правильная нормировка через System object
txFilter = comm.RaisedCosineTransmitFilter( ...
    'Shape',                  'Square root', ...
    'RolloffFactor',          rolloff, ...
    'FilterSpanInSymbols',    span, ...
    'OutputSamplesPerSymbol', sps_tx);

% Дробная задержка
varDelay = dsp.VariableFractionalDelay( ...
    'InterpolationMethod', 'FIR', ...
    'FilterHalfLength',    4);

% Приёмный RRC с децимацией
rxFilter = comm.RaisedCosineReceiveFilter( ...
    'Shape',                  'Square root', ...
    'RolloffFactor',          rolloff, ...
    'FilterSpanInSymbols',    span, ...
    'InputSamplesPerSymbol',  sps_tx, ...
    'DecimationFactor',       decim);

%% ====== 4. Главный цикл ======
ber_meas   = zeros(size(EbNo_dB_vec));
nbits_used = zeros(size(EbNo_dB_vec));

fprintf('\n=== BER vs Eb/N0 ===\n');
fprintf('%-8s %-12s %-12s %-12s %-8s\n', ...
    'Eb/N0', 'Symbols', 'Errors', 'BER', 'Lat/Rot');
fprintf('--------------------------------------------------------\n');

for idx = 1:length(EbNo_dB_vec)
    EbNo_dB = EbNo_dB_vec(idx);
    
    % Свежий синхронизатор для каждой точки
    symSync = comm.SymbolSynchronizer( ...
        'TimingErrorDetector',     'Gardner (non-data-aided)', ...
        'SamplesPerSymbol',        sps_rx, ...
        'DampingFactor',           zeta, ...
        'NormalizedLoopBandwidth', BnT, ...
        'DetectorGain',            Kp);
    
    % Сброс stateful-объектов
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
    % comm.AWGNChannel понимает Eb/N0 нативно
    chan = comm.AWGNChannel( ...
        'NoiseMethod',     'Signal to noise ratio (Eb/No)', ...
        'EbNo',            EbNo_dB, ...
        'BitsPerSymbol',   k_bits, ...
        'SignalPower',     1/sps_tx, ...
        'SamplesPerSymbol', sps_tx);
    sig_noisy = chan(sig_delayed);
    
    % --- RX RRC + децимация ---
    sig_mf = rxFilter(sig_noisy);
    
    % --- Gardner Sync ---
    sym_rx = symSync(sig_mf);
    
    % --- Поиск выравнивания (полный перебор) ---
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

%% ====== 5. Теоретическая кривая ======
EbNo_lin   = 10.^(EbNo_dB_vec/10);
ber_theory = qfunc(sqrt(2*EbNo_lin));

%% ====== 6. График ======
figure('Name','BER vs Eb/N0','Position',[100 100 800 600]);
semilogy(EbNo_dB_vec, ber_theory, 'k-', 'LineWidth', 2); hold on;
semilogy(EbNo_dB_vec, ber_meas,  'bo-', 'LineWidth', 1.5, ...
         'MarkerSize', 8, 'MarkerFaceColor', 'b');
grid on;
xlabel('E_b/N_0, дБ', 'FontSize', 12);
ylabel('BER', 'FontSize', 12);
title('Помехоустойчивость QPSK с символьной синхронизацией Gardner', ...
      'FontSize', 12);
legend('Теоретическая (QPSK в AWGN)', 'Измеренная (Gardner)', ...
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