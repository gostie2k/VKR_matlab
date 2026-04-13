%% run_dynamics.m
% Исследование динамики петли символьной синхронизации через EVM
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
EbNo_dB       = 30;       % высокий SNR, чтобы видеть чистую динамику
Nsym          = 3000;     % длина пакета

zeta = 1/sqrt(2);
Kp   = 2.7;

%% ====== 2. Набор значений BnT для сравнения ======
BnT_vec   = [0.005, 0.02, 0.05];
BnT_names = {'BnT = 0.005 (узкая)', 'BnT = 0.02 (наша)', 'BnT = 0.05 (широкая)'};
colors    = {'b', 'r', 'g'};

%% ====== 3. Подготовка фильтров ======
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

%% ====== 4. Генерация сигнала ======
rng(42);
idx_tx = randi([0 M-1], Nsym, 1);
sym_tx = pskmod(idx_tx, M, pi/4, 'gray');

reset(txFilter); reset(varDelay); reset(rxFilter);
sig_tx      = txFilter(sym_tx);
sig_delayed = varDelay(sig_tx, timing_offset * sps_tx);

chan = comm.AWGNChannel( ...
    'NoiseMethod',     'Signal to noise ratio (Eb/No)', ...
    'EbNo',            EbNo_dB, ...
    'BitsPerSymbol',   k_bits, ...
    'SignalPower',     1/sps_tx, ...
    'SamplesPerSymbol', sps_tx);
sig_noisy = chan(sig_delayed);
sig_mf    = rxFilter(sig_noisy);

%% ====== 5. Прогон через синхронизатор для разных BnT ======
fprintf('\n=== Динамика петли символьной синхронизации ===\n');
fprintf('%-25s %-15s %-15s\n', 'Конфигурация', 'T_acq (симв)', 'EVM устан. (%)');
fprintf('---------------------------------------------------------\n');

results_evm = cell(length(BnT_vec), 1);
results_err = cell(length(BnT_vec), 1);

% Эталонные точки QPSK-созвездия
ref_constellation = pskmod((0:M-1).', M, pi/4, 'gray');

for i = 1:length(BnT_vec)
    BnT = BnT_vec(i);
    
    symSync = comm.SymbolSynchronizer( ...
        'TimingErrorDetector',     'Gardner (non-data-aided)', ...
        'SamplesPerSymbol',        sps_rx, ...
        'DampingFactor',           zeta, ...
        'NormalizedLoopBandwidth', BnT, ...
        'DetectorGain',            Kp);
    
    sym_rx = symSync(sig_mf);
    
    % --- Вычисление расстояния до ближайшей точки созвездия ---
    % для каждого принятого символа (мгновенная ошибка EVM)
    n = length(sym_rx);
    err_inst = zeros(n, 1);
    for k = 1:n
        dists = abs(sym_rx(k) - ref_constellation);
        err_inst(k) = min(dists);
    end
    
    % --- Скользящее среднее для EVM (окно 30 символов) ---
    win = 30;
    evm_smooth = movmean(err_inst, win);
    
    results_err{i} = err_inst;
    results_evm{i} = evm_smooth;
    
    % --- Анализ: время захвата и установившееся EVM ---
    if n < 1500
        fprintf('Недостаточно символов.\n');
        continue;
    end
    
    % Установившееся значение EVM: среднее по последним 500 символам
    evm_steady = mean(err_inst(n-500:n));
    
    % Время захвата: первый момент, когда скользящее EVM входит
    % в полосу steady * 1.2 (т.е. отклонение не более 20% от установившегося)
    threshold = evm_steady * 1.5;
    converged_mask = evm_smooth < threshold;
    first_converged = find(converged_mask, 1, 'first');
    if isempty(first_converged)
        T_acq = NaN;
    else
        T_acq = first_converged;
    end
    
    fprintf('%-25s %-15d %-15.2f\n', ...
        BnT_names{i}, T_acq, evm_steady*100);
end

%% ====== 6. Графики ======
figure('Name','Динамика петли (через EVM)','Position',[100 100 1100 800]);

% График 1: переходный процесс (EVM во времени, первые 500 символов)
subplot(2,1,1);
hold on;
for i = 1:length(BnT_vec)
    n_show = min(500, length(results_evm{i}));
    plot(1:n_show, results_evm{i}(1:n_show)*100, ...
         colors{i}, 'LineWidth', 1.5);
end
grid on;
xlabel('Номер символа', 'FontSize', 11);
ylabel('EVM (скользящее среднее), %', 'FontSize', 11);
title('Захват петли: EVM при различных B_nT', 'FontSize', 12);
legend(BnT_names, 'Location', 'best', 'FontSize', 10);
xlim([0 500]);

% График 2: созвездия для 3 вариантов (последние 1500 символов)
subplot(2,3,4);
n = length(results_err{1});
n_plot = min(1500, n-500);
sym_show = evalin('caller', 'sym_rx');  % не сработает
% Переделываем — пересчитаем символы внутри цикла. Проще вынести.

% Соберём отдельно sym_rx для трёх BnT
for i = 1:3
    symSync_tmp = comm.SymbolSynchronizer( ...
        'TimingErrorDetector',     'Gardner (non-data-aided)', ...
        'SamplesPerSymbol',        sps_rx, ...
        'DampingFactor',           zeta, ...
        'NormalizedLoopBandwidth', BnT_vec(i), ...
        'DetectorGain',            Kp);
    sym_rx_tmp = symSync_tmp(sig_mf);
    n_tmp = length(sym_rx_tmp);
    
    subplot(2, 3, 3+i);
    plot(real(sym_rx_tmp(500:n_tmp)), imag(sym_rx_tmp(500:n_tmp)), ...
         '.', 'MarkerSize', 4, 'Color', colors{i}); hold on;
    plot([1 -1 -1 1]/sqrt(2), [1 1 -1 -1]/sqrt(2), 'k+', ...
         'MarkerSize', 12, 'LineWidth', 2);
    axis equal; grid on;
    xlim([-1.5 1.5]); ylim([-1.5 1.5]);
    xlabel('I'); ylabel('Q');
    title(BnT_names{i}, 'FontSize', 10);
end

fprintf('\nТеоретическое время захвата для BnT=0.02: ~%.0f символов\n', ...
        1/(2*0.02));
fprintf('Готово.\n');