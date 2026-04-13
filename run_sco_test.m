%% run_sco_test.m
% Исследование робастности петли к расхождению тактовых частот (SCO)
% Этап 2.7: проверка интегрального тракта PI-фильтра
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

timing_offset_init = 0.3;    % начальное смещение
EbNo_dB            = 20;     % высокий SNR, чтобы видеть чистый эффект SCO

BnT  = 0.02;
zeta = 1/sqrt(2);
Kp   = 2.7;

%% ====== 2. Параметры исследования ======
sco_ppm_vec = [0, 10, 50, 100, 200];       % значения SCO, ppm
Nsym        = 30000;                        % длинный пакет для накопления дрейфа
warmup_sym  = 1000;                         % warmup для захвата

%% ====== 3. Подготовка фильтров ======
txFilter = comm.RaisedCosineTransmitFilter( ...
    'Shape',                  'Square root', ...
    'RolloffFactor',          rolloff, ...
    'FilterSpanInSymbols',    span, ...
    'OutputSamplesPerSymbol', sps_tx);

rxFilter = comm.RaisedCosineReceiveFilter( ...
    'Shape',                  'Square root', ...
    'RolloffFactor',          rolloff, ...
    'FilterSpanInSymbols',    span, ...
    'InputSamplesPerSymbol',  sps_tx, ...
    'DecimationFactor',       decim);

varDelay = dsp.VariableFractionalDelay( ...
    'InterpolationMethod', 'FIR', ...
    'FilterHalfLength',    4, ...
    'MaximumDelay',        200);

%% ====== 4. Главный цикл по SCO ======
ref_constellation = pskmod((0:M-1).', M, pi/4, 'gray');

ber_results = zeros(size(sco_ppm_vec));
evm_final   = zeros(size(sco_ppm_vec));
evm_traces  = cell(size(sco_ppm_vec));

fprintf('\n=== Устойчивость петли к SCO ===\n');
fprintf('%-10s %-15s %-15s %-15s\n', ...
    'SCO (ppm)', 'Drift (симв)', 'BER', 'EVM финал, %');
fprintf('-------------------------------------------------------\n');

for idx = 1:length(sco_ppm_vec)
    sco_ppm = sco_ppm_vec(idx);
    
    % Свежий синхронизатор
    symSync = comm.SymbolSynchronizer( ...
        'TimingErrorDetector',     'Gardner (non-data-aided)', ...
        'SamplesPerSymbol',        sps_rx, ...
        'DampingFactor',           zeta, ...
        'NormalizedLoopBandwidth', BnT, ...
        'DetectorGain',            Kp);
    
    reset(txFilter); reset(rxFilter); reset(varDelay);
    
    % --- TX ---
    idx_tx = randi([0 M-1], Nsym, 1);
    sym_tx = pskmod(idx_tx, M, pi/4, 'gray');
    sig_tx = txFilter(sym_tx);
    
    % --- Канал: переменная задержка с линейным ростом ---
    N_samp = length(sig_tx);
    n_samp = (0:N_samp-1).';
    % delay(n) = initial*sps_tx + sco_ppm*1e-6 * n
    delay_vec = timing_offset_init * sps_tx + sco_ppm * 1e-6 * n_samp;
    sig_delayed = varDelay(sig_tx, delay_vec);
    
    % Полный накопленный дрейф за весь пакет, в символах
    total_drift_sym = sco_ppm * 1e-6 * N_samp / sps_tx;
    
    % --- AWGN ---
    chan = comm.AWGNChannel( ...
        'NoiseMethod',      'Signal to noise ratio (Eb/No)', ...
        'EbNo',             EbNo_dB, ...
        'BitsPerSymbol',    k_bits, ...
        'SignalPower',      1/sps_tx, ...
        'SamplesPerSymbol', sps_tx);
    sig_noisy = chan(sig_delayed);
    
    % --- RX RRC + децимация ---
    sig_mf = rxFilter(sig_noisy);
    
    % --- Gardner Sync ---
    sym_rx = symSync(sig_mf);
    
    % --- Анализ: EVM во времени ---
    n = length(sym_rx);
    err_inst = zeros(n, 1);
    for k = 1:n
        dists = abs(sym_rx(k) - ref_constellation);
        err_inst(k) = min(dists);
    end
    evm_traces{idx} = movmean(err_inst, 100) * 100;   % в процентах
    
    % Финальный EVM: среднее по последним 2000 символам
    if n > 2000
        evm_final(idx) = mean(err_inst(n-2000:n)) * 100;
    else
        evm_final(idx) = NaN;
    end
    
    % --- Подсчёт BER (полный перебор латентности и фазы) ---
    [n_errs, n_compare, ~, ~] = find_best_alignment( ...
        idx_tx, sym_rx, M, warmup_sym);
    
    if n_compare > 0
        ber_results(idx) = n_errs / (n_compare * k_bits);
    else
        ber_results(idx) = NaN;
    end
    
    fprintf('%-10d %-15.2f %-15.3e %-15.2f\n', ...
        sco_ppm, total_drift_sym, ber_results(idx), evm_final(idx));
end

%% ====== 5. Графики ======
figure('Name','Устойчивость к SCO','Position',[100 100 1100 700]);

% График 1: EVM во времени для разных SCO
subplot(2,1,1);
hold on;
colors = lines(length(sco_ppm_vec));
for i = 1:length(sco_ppm_vec)
    plot(evm_traces{i}, 'LineWidth', 1.5, 'Color', colors(i,:));
end
grid on;
xlabel('Номер символа', 'FontSize', 11);
ylabel('EVM (скользящее среднее), %', 'FontSize', 11);
title('Качество синхронизации во времени при различных SCO', ...
      'FontSize', 12);
leg_strs = arrayfun(@(x) sprintf('SCO = %d ppm', x), ...
    sco_ppm_vec, 'UniformOutput', false);
legend(leg_strs, 'Location', 'best', 'FontSize', 10);

% График 2: BER vs SCO
subplot(2,1,2);
semilogy(sco_ppm_vec, ber_results, 'bo-', 'LineWidth', 1.5, ...
         'MarkerSize', 8, 'MarkerFaceColor', 'b');
grid on;
xlabel('SCO, ppm', 'FontSize', 11);
ylabel('BER', 'FontSize', 11);
title('Вероятность битовой ошибки vs расхождение тактовых частот', ...
      'FontSize', 12);
ylim([1e-6 1]);

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