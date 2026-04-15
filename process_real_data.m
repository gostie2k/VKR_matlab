%% process_real_data.m
% Обработка реального дампа с железа (out.dat от научного руководителя)
% и подача в нашу gardner_canonical_rice.
%
% Формат out.dat (по parse_deb_data.m, строки 2-3):
%   double LE, 4096 комплексных пар, чередование re/im.
%
% Цепочка предобработки (по parse_deb_data.m, строки 6-41):
%   1) Чтение double LE
%   2) Нормировка к пику
%   3) Сдвиг частоты на -Fs/4 (несущая на четверти частоты дискретизации)
%   4) RRC SRRC, rolloff=0.20, span=10, sps=4
%   5) Подача в gardner_canonical_rice при sps_rx = 4
%
% Этап 2.11.
% =====================================================================

clear; clc; close all;

%% ====== 1. Чтение out.dat ======
filename = 'out.dat';      % положить рядом со скриптом

fid = fopen(filename, 'r');
if fid < 0
    error('process_real_data:open_failed', 'Не найден %s', filename);
end
data = fread(fid, 4096*2, 'double');
fclose(fid);

dr = data(1:2:end);
di = data(2:2:end);
s_raw = dr + 1i*di;

fprintf('=== Реальный сигнал из %s ===\n', filename);
fprintf('  Отсчётов:    %d комплексных пар\n', length(s_raw));
fprintf('  Пик:         %.1f\n', max(abs(s_raw)));
fprintf('  RMS:         %.1f\n', sqrt(mean(abs(s_raw).^2)));
fprintf('  DC re/im:    %.2f / %.2f\n\n', mean(real(s_raw)), mean(imag(s_raw)));

%% ====== 2. Нормировка ======
s = s_raw / max(abs(s_raw));

%% ====== 3. Сдвиг частоты на -Fs/4 ======
n = (1:length(s))';
s = s .* exp(-1i*2*pi*n/4);

%% ====== 4. RRC-фильтр (точно как у советника) ======
sps_rx  = 4;
rolloff = 0.20;
span    = 10;

v = rcosdesign(rolloff, span, sps_rx, 'sqrt');
v = round(v/max(v) * 8192);     % квантование коэффициентов как у советника
v = v / sum(v) * sps_rx;        % перенормировка для единичного коэф. передачи

ssf = filter(v, 1, s);
ssf = ssf(length(v):end);        % срез warmup фильтра

fprintf('=== После RRC ===\n');
fprintf('  Отсчётов:    %d (= %d символов × %d sps)\n', ...
        length(ssf), floor(length(ssf)/sps_rx), sps_rx);

%% ====== 5. Спектр после переноса и фильтрации (диагностика) ======
figure('Name','Спектры','Position',[100 100 1100 400]);
subplot(1,2,1);
sp_raw = fftshift(abs(fft(s_raw)).^2);
f_axis = linspace(-0.5, 0.5, length(sp_raw));
plot(f_axis, 10*log10(sp_raw + eps)); grid on;
xlabel('f / F_s'); ylabel('PSD, дБ');
title('Спектр исходного сигнала');

subplot(1,2,2);
sp_filt = fftshift(abs(fft(ssf)).^2);
f_axis = linspace(-0.5, 0.5, length(sp_filt));
plot(f_axis, 10*log10(sp_filt + eps)); grid on;
xlabel('f / F_s'); ylabel('PSD, дБ');
title('Спектр после сдвига и RRC');

%% ====== 6. Коэффициенты Rice PI-фильтра ======
BnT  = 0.02;
zeta = 1/sqrt(2);
Kp   = 2.7;
theta_n = BnT / (zeta + 1/(4*zeta));
K0Kp_K1 = (4*zeta*theta_n)  / (1 + 2*zeta*theta_n + theta_n^2);
K0Kp_K2 = (4*theta_n^2)     / (1 + 2*zeta*theta_n + theta_n^2);
K0 = -1;
K1 = K0Kp_K1 / (K0*Kp);
K2 = K0Kp_K2 / (K0*Kp);

%% ====== 7. Запуск Rice+Farrow на реальных данных ======
[sym_rx, mu_log, e_log, Kagc_log] = ...
    gardner_canonical_rice(ssf, sps_rx, K1, K2);

fprintf('\n=== Rice+Farrow на реальных данных ===\n');
fprintf('  Символов на выходе: %d\n', length(sym_rx));

%% ====== 8. MER (по протоколу советника) ======
warmup = max(round(length(sym_rx)*0.3), 1);
sym_meas = sym_rx(warmup+1:end);

mean_radius = mean(abs(sym_meas));
sym_norm = sym_meas / mean_radius;

an = 180/pi * atan2(imag(sym_norm), real(sym_norm));
an = round(an / 45) * 45 * pi/180;
dem_solve = exp(1i*an);
mer_dB = 20*log10(mean(abs(sym_norm - dem_solve)));

fprintf('  Использовано для MER: %d (срез warmup = %d)\n', ...
        length(sym_meas), warmup);
fprintf('  Средний радиус:       %.4f\n', mean_radius);
fprintf('  MER:                  %.2f дБ\n', mer_dB);

%% ====== 9. Графики ======
figure('Name','Реальные данные через Rice+Farrow','Position',[100 100 1300 800]);

% Созвездие на выходе петли (нормированное)
subplot(2,3,1);
plot(real(sym_norm), imag(sym_norm), '.', 'MarkerSize', 6); hold on;
plot([1 -1 -1 1]/sqrt(2), [1 1 -1 -1]/sqrt(2), 'r+', ...
     'MarkerSize', 12, 'LineWidth', 2);
axis equal; grid on; xlim([-1.5 1.5]); ylim([-1.5 1.5]);
xlabel('I'); ylabel('Q');
title(sprintf('Созвездие после Gardner (MER = %.1f дБ)', mer_dB));

% mu во времени
subplot(2,3,2);
plot(mu_log); grid on;
xlabel('Номер отсчёта'); ylabel('\mu');
title('Дробная задержка \mu');
ylim([-0.1 1.1]);

% Сигнал ошибки
subplot(2,3,3);
plot(e_log); grid on;
xlabel('Номер символа'); ylabel('e(k)');
title('Сигнал ошибки Gardner TED');

% AGC во времени
subplot(2,3,4);
plot(Kagc_log); grid on;
xlabel('Номер отсчёта'); ylabel('K_{AGC}');
title('Коэффициент AGC');

% Огибающая входного сигнала после RRC
subplot(2,3,5);
plot(abs(ssf)); grid on;
xlabel('Номер отсчёта'); ylabel('|s|');
title('Огибающая после RRC');

% Сырое созвездие после RRC (без синхронизации, с децимацией кратно 4)
subplot(2,3,6);
ssf_dec = ssf(1:sps_rx:end);    % децимация без выбора фазы
plot(real(ssf_dec), imag(ssf_dec), '.', 'MarkerSize', 4); hold on;
plot([1 -1 -1 1]/sqrt(2), [1 1 -1 -1]/sqrt(2)*0.5, 'r+', ...
     'MarkerSize', 12, 'LineWidth', 2);
axis equal; grid on;
xlabel('I'); ylabel('Q');
title('Сырое созвездие (без синхронизации)');

fprintf('\nГотово.\n');