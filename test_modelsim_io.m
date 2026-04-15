%% test_modelsim_io.m
% Тест pipeline для Главы 3:
% 1) Генерация сигнала, прогон через MATLAB-петлю Rice+Farrow
% 2) Экспорт входа петли (sig_mf) в test.dat — это вход для ModelSim
% 3) Экспорт выхода MATLAB-петли как эталона в ref.dat
% 4) Round-trip: чтение ref.dat обратно, проверка квантования
% 5) Метрика MER на MATLAB-выходе (нижняя граница для будущего HW)
%
% Этап 2.10, шаг 1.
% =====================================================================

clear; clc; close all;

%% ====== Параметры (как в этапе 2.6/2.9) ======
M       = 4;
k_bits  = log2(M);
sps_tx  = 8;
sps_rx  = 2;
decim   = sps_tx / sps_rx;
rolloff = 0.35;
span    = 10;
Nsym    = 5000;

timing_offset = 0.3;
EbNo_dB       = 20;          % высокий SNR для чистой проверки pipeline

% Коэффициенты Rice
BnT  = 0.02;
zeta = 1/sqrt(2);
Kp   = 2.7;
theta_n = BnT / (zeta + 1/(4*zeta));
K0Kp_K1 = (4*zeta*theta_n)  / (1 + 2*zeta*theta_n + theta_n^2);
K0Kp_K2 = (4*theta_n^2)     / (1 + 2*zeta*theta_n + theta_n^2);
K0 = -1;
K1 = K0Kp_K1 / (K0*Kp);
K2 = K0Kp_K2 / (K0*Kp);

%% ====== Цепочка: TX → канал → RX RRC ======
txFilter = comm.RaisedCosineTransmitFilter( ...
    'Shape', 'Square root', 'RolloffFactor', rolloff, ...
    'FilterSpanInSymbols', span, 'OutputSamplesPerSymbol', sps_tx);

varDelay = dsp.VariableFractionalDelay( ...
    'InterpolationMethod', 'FIR', 'FilterHalfLength', 4);

rxFilter = comm.RaisedCosineReceiveFilter( ...
    'Shape', 'Square root', 'RolloffFactor', rolloff, ...
    'FilterSpanInSymbols', span, 'InputSamplesPerSymbol', sps_tx, ...
    'DecimationFactor', decim);

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

%% ====== MATLAB-петля (эталонный выход) ======
sym_matlab = gardner_canonical_rice(sig_mf, sps_rx, K1, K2);
fprintf('MATLAB-петля: %d символов на выходе\n\n', length(sym_matlab));

%% ====== Шаг 2: экспорт входа петли в test.dat ======
fprintf('--- Экспорт входа петли (для ModelSim) ---\n');
info_in = export_for_modelsim(sig_mf, 'test.dat', 'auto');
fprintf('\n');

%% ====== Шаг 3: экспорт MATLAB-выхода как эталона ======
fprintf('--- Экспорт MATLAB-выхода (эталон для сверки) ---\n');
info_ref = export_for_modelsim(sym_matlab, 'ref.dat', 'auto');
fprintf('\n');

%% ====== Шаг 4: round-trip — чтение ref.dat и проверка ======
fprintf('--- Round-trip: чтение ref.dat ---\n');
[sym_readback, mer_readback] = read_modelsim_result('ref.dat');
fprintf('\n');

% --- Сверка: исходный sym_matlab (после нормировки) vs sym_readback ---
sym_matlab_normed = sym_matlab * info_ref.scale_factor;
err_qq = sym_matlab_normed - sym_readback;
err_rms = sqrt(mean(abs(err_qq).^2));
err_max = max(abs(err_qq));

fprintf('=== Round-trip проверка ===\n');
fprintf('  Сравнено символов:        %d\n', length(sym_readback));
fprintf('  RMS ошибка квантования:   %.6e\n', err_rms);
fprintf('  Пиковая ошибка:           %.6e\n', err_max);
fprintf('  Ожидаемый шаг квантования: %.6e (= 1/8191)\n', 1/8191);
fprintf('  Соотношение (peak/step):  %.2f (норма ~0.5)\n', err_max*8191);

%% ====== Шаг 5: MER эталонного MATLAB-выхода ======
fprintf('\n=== MER эталона MATLAB ===\n');
fprintf('  MER (на ref.dat после квантования): %.2f дБ\n', mer_readback);

% Для сравнения — MER на исходном double-выходе MATLAB до экспорта
% Тот же протокол: warmup 20 %, AGC к радиусу 1
n = length(sym_matlab);
warmup_d = max(round(n*0.2), 1);
sym_d = sym_matlab(warmup_d+1:end);
sym_d_norm = sym_d / mean(abs(sym_d));
an = 180/pi * atan2(imag(sym_d_norm), real(sym_d_norm));
an = round(an / 45) * 45 * pi/180;
dem_solve = exp(1i*an);
mer_double = 20*log10(mean(abs(sym_d_norm - dem_solve)));
fprintf('  MER (исходный double, без warmup): %.2f дБ\n', mer_double);
fprintf('  Деградация от квантования:         %.2f дБ\n', ...
        mer_readback - mer_double);

%% ====== График ======
figure('Name','Pipeline ModelSim','Position',[100 100 1100 600]);

subplot(1,2,1);
plot(real(sym_matlab(1000:end)), imag(sym_matlab(1000:end)), '.', ...
     'MarkerSize', 6); hold on;
plot([1 -1 -1 1]/sqrt(2), [1 1 -1 -1]/sqrt(2), 'r+', ...
     'MarkerSize', 12, 'LineWidth', 2);
axis equal; grid on; xlim([-1.5 1.5]); ylim([-1.5 1.5]);
xlabel('I'); ylabel('Q');
title('Исходный MATLAB-выход (double)');

subplot(1,2,2);
% Используем нормированные символы для отображения
% (третий выход read_modelsim_result)
[~, ~, sym_readback_norm] = read_modelsim_result('ref.dat');
plot(real(sym_readback_norm), imag(sym_readback_norm), '.', ...
     'MarkerSize', 6, 'Color', [0 0.5 0]); hold on;
plot([1 -1 -1 1]/sqrt(2), [1 1 -1 -1]/sqrt(2), 'r+', ...
     'MarkerSize', 12, 'LineWidth', 2);
axis equal; grid on; xlim([-1.5 1.5]); ylim([-1.5 1.5]);
xlabel('I'); ylabel('Q');
title(sprintf('После round-trip Q1.13, AGC (MER = %.1f дБ)', mer_readback));

fprintf('\nГотово. Файлы test.dat и ref.dat сохранены в текущей папке.\n');