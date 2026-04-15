%% test_round_period_loop.m
% Тест round-period реализации Gardner при sps = 40
% (точное воспроизведение схемы советника из parse_deb_data.m)
% Этап 2.9, шаг 2.
% =====================================================================

clear; clc; close all;

%% ====== Параметры ======
M       = 4;
k_bits  = log2(M);
sps_tx  = 40;            % КАК У СОВЕТНИКА
sps_rx  = 40;            % без децимации
rolloff = 0.35;
span    = 10;
Nsym    = 5000;

timing_offset = 0.3;
EbNo_dB       = 30;

% Коэффициенты советника (степени двойки) — без изменений
K1 = -2^-2;     % -0.25
K2 = -2^-8;     % -0.00390625

quant_bits = 8;          % round(dper*256)/256 — как у советника

fprintf('Параметры round-period петли (схема советника):\n');
fprintf('  sps_rx     = %d\n', sps_rx);
fprintf('  K1         = %+.6e (= -2^-2)\n', K1);
fprintf('  K2         = %+.6e (= -2^-8)\n', K2);
fprintf('  quant_bits = %d\n', quant_bits);

%% ====== Цепочка обработки ======
txFilter = comm.RaisedCosineTransmitFilter( ...
    'Shape', 'Square root', 'RolloffFactor', rolloff, ...
    'FilterSpanInSymbols', span, 'OutputSamplesPerSymbol', sps_tx);

varDelay = dsp.VariableFractionalDelay( ...
    'InterpolationMethod', 'FIR', 'FilterHalfLength', 4);

% Приёмный RRC без децимации (вход = выход = 40 sps)
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

fprintf('\nДлина сигнала на входе петли: %d отсчётов (= %d символов × %d sps)\n', ...
    length(sig_mf), Nsym, sps_rx);

%% ====== Запуск round-period петли ======
[sym_rp, dper_log, e_log] = ...
    gardner_round_period(sig_mf, sps_rx, K1, K2, quant_bits);

fprintf('Выходных символов: %d (ожидалось ~%d)\n', length(sym_rp), Nsym);

%% ====== Графики ======
figure('Name','Round-period Gardner (sps=40)','Position',[100 100 1200 800]);

subplot(2,2,1);
plot(real(sym_rp(500:end)), imag(sym_rp(500:end)), '.', 'MarkerSize', 6);
hold on;
plot([1 -1 -1 1]/sqrt(2), [1 1 -1 -1]/sqrt(2), 'r+', ...
     'MarkerSize', 12, 'LineWidth', 2);
axis equal; grid on; xlim([-1.5 1.5]); ylim([-1.5 1.5]);
xlabel('I'); ylabel('Q');
title('Созвездие на выходе round-period петли');

subplot(2,2,2);
plot(dper_log); grid on;
xlabel('Номер символа'); ylabel('dper');
title('Дробная невязка периода dper');

subplot(2,2,3);
plot(e_log); grid on;
xlabel('Номер символа'); ylabel('e(k)');
title('Сигнал ошибки Gardner TED');

subplot(2,2,4);
per_recon = sps_rx + dper_log;
plot(per_recon); grid on;
xlabel('Номер символа'); ylabel('per');
title('Период (приближённо: sps + dper)');

fprintf('\nГотово.\n');

%% ====== BER на стационаре ======
warmup = 500;
sym_rp_w = sym_rp(warmup+1:end);
idx_tx_w = idx_tx(warmup+1:end);

n_min = inf; lat_best = 0; rot_best = 0;
for lat = 0:5
    if lat >= length(sym_rp_w), break; end
    b = sym_rp_w(lat+1:end);
    n = min(length(idx_tx_w), length(b));
    if n < 100, continue; end
    a_idx = idx_tx_w(1:n);
    b_n = b(1:n);
    for rot = 0:3
        b_rot = b_n * exp(1j*rot*pi/2);
        b_idx = pskdemod(b_rot, M, pi/4, 'gray');
        n_err = sum(a_idx ~= b_idx);
        if n_err < n_min
            n_min = n_err;
            lat_best = lat;
            rot_best = rot;
            n_compare = n;
        end
    end
end

fprintf('\nBER при Eb/N0 = %d дБ:\n', EbNo_dB);
fprintf('  Символьных ошибок: %d из %d\n', n_min, n_compare);
fprintf('  SER = %.3e\n', n_min/n_compare);
fprintf('  Lat = %d, Rot = %d\n', lat_best, rot_best);

%% ====== Расширенная диагностика ======

% 1. Поиск с большим warmup и большим диапазоном латентности
fprintf('\n=== Расширенный поиск выравнивания ===\n');
for warmup_test = [500, 1000, 2000, 3000]
    if warmup_test >= length(sym_rp), continue; end
    sym_w = sym_rp(warmup_test+1:end);
    idx_w = idx_tx(warmup_test+1:end);
    
    n_min = inf; lat_best = 0; rot_best = 0;
    for lat = 0:50
        if lat >= length(sym_w), break; end
        b = sym_w(lat+1:end);
        n = min(length(idx_w), length(b));
        if n < 100, continue; end
        a_idx = idx_w(1:n);
        b_n = b(1:n);
        for rot = 0:3
            b_rot = b_n * exp(1j*rot*pi/2);
            b_idx = pskdemod(b_rot, M, pi/4, 'gray');
            n_err = sum(a_idx ~= b_idx);
            if n_err < n_min
                n_min = n_err;
                lat_best = lat;
                rot_best = rot;
                n_cmp = n;
            end
        end
    end
    fprintf('  warmup=%4d:  SER = %.3e  (%d/%d, lat=%d, rot=%d)\n', ...
        warmup_test, n_min/n_cmp, n_min, n_cmp, lat_best, rot_best);
end

% 2. SER по окнам — где петля захватывает, а где нет?
fprintf('\n=== SER по окнам 500 символов ===\n');
win = 500;
for w_start = 1:win:(length(sym_rp)-win)
    w_end = w_start + win - 1;
    sym_w = sym_rp(w_start:w_end);
    
    % Простой match: пробуем сдвиг 0..3 и rot 0..3 относительно idx_tx
    % с тем же стартом
    if w_end > length(idx_tx), break; end
    idx_w = idx_tx(w_start:w_end);
    
    n_min = inf;
    for lat = 0:3
        if lat >= length(sym_w), break; end
        b = sym_w(lat+1:end);
        n = min(length(idx_w), length(b));
        if n < 50, continue; end
        for rot = 0:3
            b_rot = b(1:n) * exp(1j*rot*pi/2);
            b_idx = pskdemod(b_rot, M, pi/4, 'gray');
            n_err = sum(idx_w(1:n) ~= b_idx);
            if n_err < n_min
                n_min = n_err;
                n_cmp_w = n;
            end
        end
    end
    fprintf('  symbols [%4d..%4d]:  SER = %.3e  (%d ошибок)\n', ...
        w_start, w_end, n_min/n_cmp_w, n_min);
end

% 3. График dindex — на каком отсчёте брался каждый строб
% Если петля работает, dindex должен расти линейно с шагом ~sps_rx
% Восстановим из dper_log
dindex_recon = cumsum([sps_rx; sps_rx + diff(dper_log)]);
figure('Name','Расположение стробов во времени');
subplot(2,1,1);
plot(diff(dindex_recon)); grid on;
xlabel('Номер символа'); ylabel('Расстояние между стробами в отсчётах');
title('Шаг между соседними стробами');
ylim([sps_rx-2, sps_rx+2]);

subplot(2,1,2);
% Фаза стробирования относительно идеальной сетки (символ N должен быть на отсчёте N*sps_rx)
ideal_pos = (1:length(dindex_recon))' * sps_rx;
phase_drift = dindex_recon - ideal_pos;
plot(phase_drift); grid on;
xlabel('Номер символа'); ylabel('Накопленный сдвиг, отсчётов');
title('Накопленный фазовый дрейф стробирования');