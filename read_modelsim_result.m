function [sym_rx, mer_dB, sym_norm] = read_modelsim_result(filename, n_symbols)
% read_modelsim_result — чтение result.dat от Verilog-симуляции.
%
% Формат симметричен export_for_modelsim:
%   int16 LE, чередование real/imag, нормировка к double делением на 2^13-1.
%
% MER считается по протоколу советника (parse_deb_data.m, строки 172, 432..438):
% перед расчётом MER символы нормируются к среднему радиусу 1
% (tmp = tmp / mean(abs(tmp))) — это устраняет зависимость от амплитудного
% масштабирования цепочки и оставляет только угловую/фазовую ошибку,
% которая и характеризует качество стробирования.
%
% Вход:
%   filename  — имя файла
%   n_symbols — ожидаемое число символов (0 = читать всё)
%
% Выход:
%   sym_rx   — комплексный вектор символов после деления на 2^13-1
%              (амплитуда — как в файле, без AGC-нормировки)
%   mer_dB   — modulation error ratio в дБ (после AGC к радиусу 1)
%   sym_norm — символы после AGC-нормировки (используются для MER)

if nargin < 2, n_symbols = 0; end

QSCALE = 2^13 - 1;

% --- Чтение int16 ---
fid = fopen(filename, 'r');
if fid < 0
    error('read_modelsim_result:open_failed', ...
          'Не удалось открыть %s для чтения', filename);
end

if n_symbols > 0
    raw = fread(fid, 2*n_symbols, 'int16');
else
    raw = fread(fid, inf, 'int16');
end
fclose(fid);

if mod(length(raw), 2) ~= 0
    warning('read_modelsim_result:odd_count', ...
            'Нечётное число int16-значений в %s — последнее отброшено', ...
            filename);
    raw = raw(1:end-1);
end

qr = raw(1:2:end);
qi = raw(2:2:end);

sym_rx = (qr + 1i*qi) / QSCALE;

% --- AGC-нормировка перед расчётом MER (как у советника) ---
% Срезаем warmup в 20 % от начала, чтобы переходный процесс петли
% не портил оценку среднего радиуса
n = length(sym_rx);
warmup = max(round(n*0.2), 1);
sym_meas = sym_rx(warmup+1:end);

mean_radius = mean(abs(sym_meas));
sym_norm = sym_meas / mean_radius;

% --- MER по протоколу советника ---
an = 180/pi * atan2(imag(sym_norm), real(sym_norm));
an = round(an / 45) * 45 * pi/180;
dem_solve = exp(1i*an);
mer_dB = 20*log10(mean(abs(sym_norm - dem_solve)));

fprintf('read_modelsim_result: %s\n', filename);
fprintf('  Прочитано отсчётов:    %d\n', length(sym_rx));
fprintf('  Использовано для MER:  %d (срез warmup = %d)\n', ...
        length(sym_meas), warmup);
fprintf('  Средний радиус:        %.4f (нормировка к 1)\n', mean_radius);
fprintf('  MER:                   %.2f дБ\n', mer_dB);

end