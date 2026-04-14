%% test_rice_loop.m
% Минимальный тест канонической реализации Gardner Rice
% Сравнение с эталоном comm.SymbolSynchronizer
% =====================================================================

clear; clc; close all;

%% ====== Параметры ======
M       = 4;
k_bits  = log2(M);
sps_tx  = 8;
sps_rx  = 2;
decim   = sps_tx / sps_rx;
rolloff = 0.35;
span    = 10;
Nsym    = 5000;

timing_offset = 0.3;
EbNo_dB       = 30;       % высокий SNR — без шума

% Параметры петли
BnT  = 0.02;
zeta = 1/sqrt(2);
Kp   = 2.7;

theta_n = BnT / (zeta + 1/(4*zeta));
K0Kp_K1 = (4*zeta*theta_n) / (1 + 2*zeta*theta_n + theta_n^2);
K0Kp_K2 = (4*theta_n^2)    / (1 + 2*zeta*theta_n + theta_n^2);
K0 = -1;
K1 = K0Kp_K1 / (K0*Kp);
K2 = K0Kp_K2 / (K0*Kp);
%K1 = -K0Kp_K1 / (K0*Kp);
%K2 = -K0Kp_K2 / (K0*Kp);
%K1 = K1 / 10;
%K2 = K2 / 10;
fprintf('K1 = %.6e\n', K1);
fprintf('K2 = %.6e\n', K2);

%% ====== Цепочка обработки (System objects, как в этапе 2.5) ======
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

%% ====== Генерация сигнала ======
rng(42);
idx_tx = randi([0 M-1], Nsym, 1);
sym_tx = pskmod(idx_tx, M, pi/4, 'gray');

reset(txFilter); reset(varDelay); reset(rxFilter);
sig_tx      = txFilter(sym_tx);
sig_delayed = varDelay(sig_tx, timing_offset * sps_tx);

chan = comm.AWGNChannel( ...
    'NoiseMethod', 'Signal to noise ratio (Eb/No)', ...
    'EbNo', EbNo_dB, ...
    'BitsPerSymbol', k_bits, ...
    'SignalPower', 1/sps_tx, ...
    'SamplesPerSymbol', sps_tx);
sig_noisy = chan(sig_delayed);
sig_mf    = rxFilter(sig_noisy);

%% ====== Эталон: comm.SymbolSynchronizer ======
symSync = comm.SymbolSynchronizer( ...
    'TimingErrorDetector', 'Gardner (non-data-aided)', ...
    'SamplesPerSymbol', sps_rx, ...
    'DampingFactor', zeta, ...
    'NormalizedLoopBandwidth', BnT, ...
    'DetectorGain', Kp);

sym_ref = symSync(sig_mf);

%% ====== Наша реализация ======
[sym_rice, mu_log, e_log] = gardner_canonical_rice(sig_mf, sps_rx, K1, K2);

fprintf('comm.SymbolSynchronizer: %d символов на выходе\n', length(sym_ref));
fprintf('gardner_canonical_rice:  %d символов на выходе\n', length(sym_rice));

%% ====== Графики ======
figure('Name','Сравнение реализаций Gardner','Position',[100 100 1200 800]);

% Созвездие comm.SymbolSynchronizer
subplot(2,2,1);
plot(real(sym_ref(1000:end)), imag(sym_ref(1000:end)), '.', 'MarkerSize', 6);
hold on;
plot([1 -1 -1 1]/sqrt(2), [1 1 -1 -1]/sqrt(2), 'r+', 'MarkerSize', 12, 'LineWidth', 2);
axis equal; grid on; xlim([-1.5 1.5]); ylim([-1.5 1.5]);
xlabel('I'); ylabel('Q');
title('Эталон: comm.SymbolSynchronizer');

% Созвездие нашей реализации
subplot(2,2,2);
plot(real(sym_rice(1000:end)), imag(sym_rice(1000:end)), '.', 'MarkerSize', 6, 'Color', [0 0.5 0]);
hold on;
plot([1 -1 -1 1]/sqrt(2), [1 1 -1 -1]/sqrt(2), 'r+', 'MarkerSize', 12, 'LineWidth', 2);
axis equal; grid on; xlim([-1.5 1.5]); ylim([-1.5 1.5]);
xlabel('I'); ylabel('Q');
title('Наша реализация: gardner\_canonical\_rice');

% Дробная задержка mu
subplot(2,2,3);
plot(mu_log); grid on;
xlabel('Номер отсчёта'); ylabel('\mu');
title('Дробная задержка \mu во времени');
ylim([-0.1 1.1]);

% Сигнал ошибки
subplot(2,2,4);
plot(e_log); grid on;
xlabel('Номер символа'); ylabel('e(k)');
title('Сигнал ошибки Gardner TED');

fprintf('\nГотово.\n');