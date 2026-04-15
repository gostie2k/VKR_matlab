%% diag_real_data.m
% Голая диагностика out.dat без предобработки

clear; clc; close all;

fid = fopen('out.dat', 'r');
data = fread(fid, 4096*2, 'double');
fclose(fid);

dr = data(1:2:end);
di = data(2:2:end);
s = dr + 1i*di;

% Базовая статистика
fprintf('=== Статистика ===\n');
fprintf('  N комплексных:  %d\n', length(s));
fprintf('  re: min=%.0f max=%.0f mean=%.2f std=%.1f\n', ...
        min(real(s)), max(real(s)), mean(real(s)), std(real(s)));
fprintf('  im: min=%.0f max=%.0f mean=%.2f std=%.1f\n', ...
        min(imag(s)), max(imag(s)), mean(imag(s)), std(imag(s)));

figure('Position',[100 100 1400 800]);

% --- Временные ряды ---
subplot(3,2,1);
plot(real(s(1:200))); grid on;
xlabel('n'); ylabel('Re(s)');
title('Real часть, первые 200 отсчётов');

subplot(3,2,2);
plot(imag(s(1:200))); grid on;
xlabel('n'); ylabel('Im(s)');
title('Imag часть, первые 200 отсчётов');

% --- Огибающая ---
subplot(3,2,3);
plot(abs(s)); grid on;
xlabel('n'); ylabel('|s|');
title('Огибающая |s| на всём интервале');

% --- Спектр сырой ---
subplot(3,2,4);
N = length(s);
sp = fftshift(abs(fft(s)).^2 / N);
f_axis = linspace(-0.5, 0.5, N);
plot(f_axis, 10*log10(sp + eps)); grid on;
xlabel('f / F_s'); ylabel('PSD, дБ');
title('Спектр СЫРОГО сигнала (где несущая?)');

% --- Сырое созвездие ---
subplot(3,2,5);
plot(real(s), imag(s), '.', 'MarkerSize', 4); grid on;
axis equal;
xlabel('I'); ylabel('Q');
title('Сырое созвездие (4096 точек)');

% --- Спектр после кандидатных сдвигов ---
subplot(3,2,6);
n = (1:N)';
shifts = [-0.25, 0.25, -0.125, 0.125];
colors = {'b', 'r', 'g', 'm'};
hold on;
for k = 1:length(shifts)
    s_sh = s .* exp(-1i*2*pi*n*shifts(k));
    sp_sh = fftshift(abs(fft(s_sh)).^2 / N);
    plot(f_axis, 10*log10(sp_sh + eps), colors{k}, 'LineWidth', 1);
end
plot(f_axis, 10*log10(fftshift(abs(fft(s)).^2 / N) + eps), 'k--');
grid on;
legend('-0.25 (как у советника)', '+0.25', '-0.125', '+0.125', 'без сдвига', ...
       'Location', 'best');
xlabel('f / F_s'); ylabel('PSD, дБ');
title('Спектр при разных частотных сдвигах');
xlim([-0.5 0.5]);

fprintf('\nГотово — смотрим на графики.\n');