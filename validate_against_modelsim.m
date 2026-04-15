%% validate_against_modelsim.m
% Сравнение MATLAB-петли (gardner_round_period) с выходом HDL-симуляции
% советника (result_MODELSIM.dat) на одном и том же входном сигнале (test.dat).
%
% Этап 2.11.
% =====================================================================

clear; clc; close all;

%% ====== 1. Чтение test.dat (вход петли в Q1.13) ======
fid = fopen('test.dat', 'r');
raw = fread(fid, inf, 'int16');
fclose(fid);

QSCALE = 2^13 - 1;
qr = raw(1:2:end);
qi = raw(2:2:end);
sig_in = (qr + 1i*qi) / QSCALE;

fprintf('=== Вход (test.dat) ===\n');
fprintf('  Отсчётов:    %d\n', length(sig_in));
fprintf('  Пик |s|:     %.4f\n', max(abs(sig_in)));
fprintf('  RMS |s|:     %.4f\n\n', sqrt(mean(abs(sig_in).^2)));

%% ====== 2. Параметры петли (по советнику) ======
sps_rx     = 40;
K1         = -2^-2;
K2         = -2^-8;
quant_bits = 8;

%% ====== 3. Прогон через нашу gardner_round_period ======
fprintf('Прогоняем через gardner_round_period...\n');
tic;
[sym_matlab, dper_log, e_log] = ...
    gardner_round_period(sig_in, sps_rx, K1, K2, quant_bits);
t_matlab = toc;
fprintf('  Время: %.1f с\n', t_matlab);
fprintf('  Символов на выходе: %d\n\n', length(sym_matlab));

%% ====== 4. Чтение HDL-результата ======
[sym_hdl, mer_hdl, sym_hdl_norm] = read_modelsim_result('result_MODELSIM.dat');
fprintf('\n');

%% ====== 5. MER нашей реализации (тот же протокол) ======
n = length(sym_matlab);
warmup_m = max(round(n*0.2), 1);
sym_m_meas = sym_matlab(warmup_m+1:end);

mr_matlab = mean(abs(sym_m_meas));
sym_matlab_norm = sym_m_meas / mr_matlab;
an = 180/pi * atan2(imag(sym_matlab_norm), real(sym_matlab_norm));
an = round(an / 45) * 45 * pi/180;
mer_matlab = 20*log10(mean(abs(sym_matlab_norm - exp(1i*an))));

fprintf('=== Сравнение MER ===\n');
fprintf('  MATLAB (gardner_round_period): %.2f дБ  (%d символов)\n', ...
        mer_matlab, length(sym_m_meas));
fprintf('  HDL (result_MODELSIM.dat):     %.2f дБ  (%d символов)\n', ...
        mer_hdl, length(sym_hdl_norm));
fprintf('  Разница MATLAB - HDL:          %+.2f дБ\n', mer_matlab - mer_hdl);

%% ====== 6. Графики ======
figure('Name','MATLAB vs HDL','Position',[100 100 1400 700]);

% Созвездие MATLAB
subplot(1,2,1);
plot(real(sym_matlab_norm), imag(sym_matlab_norm), '.', ...
     'MarkerSize', 4); hold on;
plot([1 -1 -1 1]/sqrt(2), [1 1 -1 -1]/sqrt(2), 'r+', ...
     'MarkerSize', 14, 'LineWidth', 2);
axis equal; grid on; xlim([-1.5 1.5]); ylim([-1.5 1.5]);
xlabel('I'); ylabel('Q');
title(sprintf('MATLAB: gardner\\_round\\_period (MER = %.1f дБ)', mer_matlab));

% Созвездие HDL
subplot(1,2,2);
plot(real(sym_hdl_norm), imag(sym_hdl_norm), '.', ...
     'MarkerSize', 4, 'Color', [0.6 0 0.6]); hold on;
plot([1 -1 -1 1]/sqrt(2), [1 1 -1 -1]/sqrt(2), 'r+', ...
     'MarkerSize', 14, 'LineWidth', 2);
axis equal; grid on; xlim([-1.5 1.5]); ylim([-1.5 1.5]);
xlabel('I'); ylabel('Q');
title(sprintf('HDL: knk\\_pkrv\\_modem.v (MER = %.1f дБ)', mer_hdl));

fprintf('\nГотово.\n');