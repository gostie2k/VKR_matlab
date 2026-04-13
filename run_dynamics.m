%% run_dynamics.m
% Исследование динамики петли символьной синхронизации
% Подэтапы: 2.6а — время захвата, 2.6б — джиттер
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
EbNo_dB       = 30;       % высокий SNR — почти без шума, чтобы видеть чистую динамику
Nsym          = 2000;     % длина пакета (хватит для захвата + установившегося режима)

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

%% ====== 4. Один раз генерируем сигнал ======
rng(42);  % фиксируем seed для воспроизводимости
idx_tx = randi([0 M-1], Nsym, 1);
sym_tx = pskmod(idx_tx, M, pi/4, 'gray');

reset(txFilter); reset(varDelay); reset(rxFilter);
sig_tx     = txFilter(sym_tx);
sig_delayed = varDelay(sig_tx, timing_offset * sps_tx);

chan = comm.AWGNChannel( ...
    'NoiseMethod',     'Signal to noise ratio (Eb/No)', ...
    'EbNo',            EbNo_dB, ...
    'BitsPerSymbol',   k_bits, ...
    'SignalPower',     1/sps_tx, ...
    'SamplesPerSymbol', sps_tx);
sig_noisy = chan(sig_delayed);
sig_mf = rxFilter(sig_noisy);

%% ====== 5. Прогон через синхронизатор для разных BnT ======
fprintf('\n=== Динамика петли символьной синхронизации ===\n');
fprintf('%-25s %-15s %-15s\n', 'Конфигурация', 'T_acq (симв)', 'std(timErr)');
fprintf('---------------------------------------------------------\n');

results = cell(length(BnT_vec), 1);

for i = 1:length(BnT_vec)
    BnT = BnT_vec(i);
    
    symSync = comm.SymbolSynchronizer( ...
        'TimingErrorDetector',     'Gardner (non-data-aided)', ...
        'SamplesPerSymbol',        sps_rx, ...
        'DampingFactor',           zeta, ...
        'NormalizedLoopBandwidth', BnT, ...
        'DetectorGain',            Kp, ...
        'TimingErrorOutputPort',   true);
    
    [~, timErr] = symSync(sig_mf);
    results{i} = timErr;
    
    % --- Анализ ---
    % Установившееся значение: среднее по последним 500 символам
    n = length(timErr);
    if n < 1000
        fprintf('Слишком мало символов на выходе.\n');
        continue;
    end
    steady_value = mean(timErr(n-500:n));
    
    % Время захвата: первый момент, когда |timErr - steady| < 0.05
    threshold = 0.05;
    converged = abs(timErr - steady_value) < threshold;
    % Ищем последний момент, когда условие НЕ выполняется
    last_unconv = find(~converged, 1, 'last');
    if isempty(last_unconv)
        T_acq = 0;
    else
        T_acq = last_unconv;
    end
    
    % Джиттер: std в установившемся режиме (последние 500 символов)
    jitter = std(timErr(n-500:n));
    
    fprintf('%-25s %-15d %-15.4e\n', BnT_names{i}, T_acq, jitter);
end

%% ====== 6. График: сходимость для разных BnT ======
figure('Name','Динамика петли','Position',[100 100 1100 700]);

% График 1: timing error во времени (первые 500 символов)
subplot(2,1,1);
hold on;
for i = 1:length(BnT_vec)
    plot(results{i}(1:min(500, length(results{i}))), ...
         colors{i}, 'LineWidth', 1.5);
end
grid on;
xlabel('Номер символа', 'FontSize', 11);
ylabel('timing error (норм.)', 'FontSize', 11);
title('Захват петли: переходный процесс при различных BnT', ...
      'FontSize', 12);
legend(BnT_names, 'Location', 'best', 'FontSize', 10);
xlim([0 500]);

% График 2: установившийся режим (символы 1000..1500)
subplot(2,1,2);
hold on;
for i = 1:length(BnT_vec)
    n = length(results{i});
    if n > 1500
        plot(1000:1500, results{i}(1000:1500), colors{i}, 'LineWidth', 1);
    end
end
grid on;
xlabel('Номер символа', 'FontSize', 11);
ylabel('timing error (норм.)', 'FontSize', 11);
title('Установившийся режим: джиттер при различных BnT', ...
      'FontSize', 12);
legend(BnT_names, 'Location', 'best', 'FontSize', 10);
xlim([1000 1500]);

fprintf('\nТеоретическое время захвата для BnT=0.02: ~%.0f символов\n', ...
        1/(2*0.02));
fprintf('Готово.\n');