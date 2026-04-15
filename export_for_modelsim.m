function info = export_for_modelsim(sig, filename, scale_mode)
% export_for_modelsim — запись комплексного сигнала в test.dat в формате
% Q1.13 int16 для подачи на вход Verilog-симуляции (ModelSim).
%
% Формат точно совпадает с протоколом научного руководителя
% (parse_deb_data.m, строки 454..461; scan_modelsim_result.m).
%
% Структура файла:
%   int16 LE, чередование real/imag, по одному значению на отсчёт.
%   Шкала Q1.13: значение 1.0 кодируется как 8191 (= 2^13 - 1).
%   Динамический диапазон входа: [-1; +1).
%
% Вход:
%   sig        — комплексный вектор (double) для записи
%   filename   — имя выходного файла (например, 'test.dat')
%   scale_mode — режим нормировки амплитуды:
%     'auto' — автомасштаб к пику: sig / max(abs(sig)) * 0.99
%              (запас 1 % от насыщения)
%     'rms'  — нормировка по RMS к 0.5 (сохраняет запас на пики)
%     'none' — без нормировки, сигнал уже в диапазоне [-1; +1)
%
% Выход:
%   info — структура с метаданными:
%     .n_samples       — число записанных отсчётов
%     .scale_factor    — применённый множитель (sig_norm = sig * scale_factor)
%     .max_input_abs   — пиковая амплитуда исходного сигнала
%     .clipped_count   — число отсчётов, попавших в насыщение int16
%
% Пример использования:
%   info = export_for_modelsim(sig_mf, 'test.dat', 'auto');

if nargin < 3, scale_mode = 'auto'; end

QSCALE = 2^13 - 1;              % = 8191, единица в Q1.13
INT16_MAX = 2^15 - 1;           % = 32767
INT16_MIN = -2^15;              % = -32768

max_abs = max(abs(sig));

% --- Нормировка ---
switch lower(scale_mode)
    case 'auto'
        scale_factor = 0.99 / max_abs;
    case 'rms'
        rms_val = sqrt(mean(abs(sig).^2));
        scale_factor = 0.5 / rms_val;
    case 'none'
        scale_factor = 1.0;
    otherwise
        error('export_for_modelsim:bad_scale', ...
              'scale_mode должен быть auto, rms или none');
end

sig_norm = sig * scale_factor;

% --- Квантование в Q1.13 ---
sig_q_real = round(real(sig_norm) * QSCALE);
sig_q_imag = round(imag(sig_norm) * QSCALE);

% --- Saturation в int16 ---
n_clipped = sum(sig_q_real > INT16_MAX | sig_q_real < INT16_MIN | ...
                sig_q_imag > INT16_MAX | sig_q_imag < INT16_MIN);
sig_q_real = max(min(sig_q_real, INT16_MAX), INT16_MIN);
sig_q_imag = max(min(sig_q_imag, INT16_MAX), INT16_MIN);

% --- Запись по протоколу советника: int16 LE, чередование re/im ---
fid = fopen(filename, 'w');
if fid < 0
    error('export_for_modelsim:open_failed', ...
          'Не удалось открыть %s для записи', filename);
end

interleaved = zeros(2*length(sig), 1, 'int16');
interleaved(1:2:end) = int16(sig_q_real);
interleaved(2:2:end) = int16(sig_q_imag);
fwrite(fid, interleaved, 'int16');
fclose(fid);

% --- Метаданные ---
info.n_samples     = length(sig);
info.scale_factor  = scale_factor;
info.max_input_abs = max_abs;
info.clipped_count = n_clipped;
info.filename      = filename;
info.format        = 'Q1.13 int16 LE, interleaved re/im';

fprintf('export_for_modelsim: %s\n', filename);
fprintf('  Отсчётов записано:    %d\n', info.n_samples);
fprintf('  Размер файла:         %d байт\n', 4*info.n_samples);
fprintf('  Множитель нормировки: %.6f\n', info.scale_factor);
fprintf('  Пик исходного сигнала: %.4f\n', info.max_input_abs);
fprintf('  Saturation events:    %d (%.2f %%)\n', ...
        n_clipped, 100*n_clipped/(2*info.n_samples));

end