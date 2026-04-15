%% test_round_period_loop.m
% Минимальный тест round-period реализации Gardner
% Этап 2.9, шаг 2.
% =====================================================================

clear; clc; close all;

%% ====== Параметры ======
M       = 4;
k_bits  = log2(M);
sps_tx  = 8;
sps_rx  = 8;             % БЕЗ децимации — round-period нужен sps >= 8
rolloff = 0.35;
span    = 10;
Nsym    = 5000;

timing_offset = 0.3;
EbNo_dB       = 30;

% Коэффициенты советника (степени двойки)
%K1 = -2^-2;     % -0.25
%K2 = -2^-8;     % -0.00390625

% K1 = -2^-3;     % -0.125 (было -2^-2 = -0.25, для sps_rx = 8)
% K2 = -2^-8;     % -0.00390625 (без изменений)
% 
% quant_bits = 8;          % как у советника: round(dper*256)/256

K1 = -2^-3;     % -0.125 (как было)
K2 = -2^-10;    % -0.000977 (было -2^-8 = -0.0039, уменьшаем в 4 раза)

quant_bits = 0;          % отключаем квантование dper для чистого теста

fprintf('Параметры round-period петли:\n');
fprintf('  K1 = %+.6e (= -2^-2)\n', K1);
fprintf('  K2 = %+.6e (= -2^-8)\n', K2);
fprintf('  quant_bits = %d\n', quant_bits);

%% ====== Цепочка обработки ======
txFilter = comm.RaisedCosineTransmitFilter( ...
    'Shape', 'Square root', 'RolloffFactor', rolloff, ...
    'FilterSpanInSymbols', span, 'OutputSamplesPerSymbol', sps_tx);

varDelay = dsp.VariableFractionalDelay( ...
    'InterpolationMethod', 'FIR', 'FilterHalfLength', 4);

% Приёмный RRC БЕЗ децимации (sps_rx = sps_tx = 8)
rxFilter = comm.RaisedCosineReceiveFilter( ...
    'Shape', 'Square root', 'RolloffFactor', rolloff, ...
    'FilterSpanInSymbols', span, 'InputSamplesPerSymbol', sps_tx, ...
    'DecimationFactor', 1);

%% ====== Генерация сигнала ======
rng(42);
idx_tx = randi([0 M-1], Nsym, 1);
sym_tx = pskmod(idx_tx, M, pi/4, 'gray');

reset(txFilter); reset(varDelay); reset(rxFilter);
sig_tx      = txFilter(sym_tx);
sig_delayed = varDelay(sig_tx, timing_offset * sps_tx);

chan = comm.AWGNChannel( ...
    'NoiseMethod', 'Signal to noise ratio (Eb/No)', ...
    'EbNo', EbNo_dB, 'BitsPerSymbol', k_bits, ...
    'SignalPower', 1/sps_tx, 'SamplesPerSymbol', sps_tx);
sig_noisy = chan(sig_delayed);
sig_mf    = rxFilter(sig_noisy);

%% ====== Запуск round-period петли ======
[sym_rp, dper_log, e_log] = ...
    gardner_round_period(sig_mf, sps_rx, K1, K2, quant_bits);

fprintf('\nВыходных символов: %d (ожидалось ~%d)\n', length(sym_rp), Nsym);

%% ====== Графики ======
figure('Name','Round-period Gardner','Position',[100 100 1200 800]);

% Созвездие
subplot(2,2,1);
plot(real(sym_rp(500:end)), imag(sym_rp(500:end)), '.', 'MarkerSize', 6);
hold on;
plot([1 -1 -1 1]/sqrt(2), [1 1 -1 -1]/sqrt(2), 'r+', ...
     'MarkerSize', 12, 'LineWidth', 2);
axis equal; grid on; xlim([-1.5 1.5]); ylim([-1.5 1.5]);
xlabel('I'); ylabel('Q');
title('Созвездие на выходе round-period петли');

% Невязка dper
subplot(2,2,2);
plot(dper_log); grid on;
xlabel('Номер символа'); ylabel('dper');
title('Дробная невязка периода dper');

% Сигнал ошибки
subplot(2,2,3);
plot(e_log); grid on;
xlabel('Номер символа'); ylabel('e(k)');
title('Сигнал ошибки Gardner TED');

% Период во времени (восстанавливается из dper)
subplot(2,2,4);
per_recon = sps_rx + dper_log;   % приближённо
plot(per_recon); grid on;
xlabel('Номер символа'); ylabel('per');
title('Период (приближённо: sps + dper)');

fprintf('\nГотово.\n');