function check_farrow_result()
% check_farrow_result — bit-accurate сравнение выхода HDL (из out_hdl.txt)
% с золотым вектором (golden_xi.mat, сгенерированным gen_farrow_stimulus.m)
%
% Типичный сценарий использования:
%   1. В MATLAB: gen_farrow_stimulus()       — формирует stim_*.hex + golden_xi.mat
%   2. В ModelSim: vsim -do "run -all" tb_sync_farrow_parab
%   3. В MATLAB: check_farrow_result()        — выводит статистику расхождений
%
% Kudimov, ВКР, глава 3, этап 3.1

%% ============ 1. Загрузка данных =======================================
if ~exist('golden_xi.mat', 'file')
    error('golden_xi.mat не найден. Запусти сначала gen_farrow_stimulus.m');
end
S = load('golden_xi.mat');

if ~exist('out_hdl.txt', 'file')
    error('out_hdl.txt не найден. Запусти сначала ModelSim на tb_sync_farrow_parab');
end

hdl_data = load('out_hdl.txt');   % столбцы: xi_i, xi_q, valid

%% ============ 2. Выделение валидных отсчётов ===========================
% В HDL-выходе есть задержка в 3 такта на конвейер и дополнительные такты
% в начале (reset) — поэтому сопоставляем только по valid-флагу
valid_mask = hdl_data(:, 3) == 1;
hdl_xi_i = hdl_data(valid_mask, 1);
hdl_xi_q = hdl_data(valid_mask, 2);

% Золотой вектор: выбираем ненулевые (после латентности)
gold_xi_i = S.xi_i_q;
gold_xi_q = S.xi_q_q;
gold_valid = (gold_xi_i ~= 0) | (gold_xi_q ~= 0);
gold_xi_i = gold_xi_i(gold_valid);
gold_xi_q = gold_xi_q(gold_valid);

% Выравнивание длин
n_compare = min(length(hdl_xi_i), length(gold_xi_i));
hdl_xi_i = hdl_xi_i(1:n_compare);
hdl_xi_q = hdl_xi_q(1:n_compare);
gold_xi_i = gold_xi_i(1:n_compare);
gold_xi_q = gold_xi_q(1:n_compare);

fprintf('[check_farrow_result] Сравниваем %d отсчётов\n', n_compare);

%% ============ 3. Статистика расхождений ================================
diff_i = hdl_xi_i - gold_xi_i;
diff_q = hdl_xi_q - gold_xi_q;

n_exact = sum((diff_i == 0) & (diff_q == 0));
n_match_1lsb = sum((abs(diff_i) <= 1) & (abs(diff_q) <= 1));

fprintf('\n=== Bit-accurate статистика sync_farrow_parab ===\n');
fprintf('  Полное совпадение (0 LSB):  %d / %d (%.2f %%)\n', ...
        n_exact, n_compare, 100*n_exact/n_compare);
fprintf('  Совпадение в ±1 LSB:        %d / %d (%.2f %%)\n', ...
        n_match_1lsb, n_compare, 100*n_match_1lsb/n_compare);
fprintf('  max |diff_I| =              %d LSB\n', max(abs(diff_i)));
fprintf('  max |diff_Q| =              %d LSB\n', max(abs(diff_q)));
fprintf('  RMS  diff_I =               %.3f LSB\n', sqrt(mean(diff_i.^2)));
fprintf('  RMS  diff_Q =               %.3f LSB\n', sqrt(mean(diff_q.^2)));

%% ============ 4. Графики расхождений ===================================
figure('Name', 'sync_farrow_parab — HDL vs MATLAB golden', 'NumberTitle', 'off');

subplot(3,1,1);
plot(1:n_compare, gold_xi_i, 'b-', 1:n_compare, hdl_xi_i, 'r--', 'LineWidth', 1);
xlabel('Отсчёт'); ylabel('XI_I (LSB)');
legend('Golden (MATLAB)', 'HDL (ModelSim)');
title('Канал I: золотой вектор и HDL-выход');
grid on;

subplot(3,1,2);
plot(1:n_compare, gold_xi_q, 'b-', 1:n_compare, hdl_xi_q, 'r--', 'LineWidth', 1);
xlabel('Отсчёт'); ylabel('XI_Q (LSB)');
legend('Golden (MATLAB)', 'HDL (ModelSim)');
title('Канал Q: золотой вектор и HDL-выход');
grid on;

subplot(3,1,3);
stem(1:n_compare, diff_i, 'b', 'Marker', '.');
hold on;
stem(1:n_compare, diff_q, 'r', 'Marker', '.');
xlabel('Отсчёт'); ylabel('diff (LSB)');
legend('diff_I', 'diff_Q');
title('Разность HDL − Golden');
grid on;

%% ============ 5. Вердикт ================================================
if n_exact == n_compare
    fprintf('\n[РЕЗУЛЬТАТ]  Bit-accurate соответствие достигнуто.\n');
elseif n_match_1lsb / n_compare > 0.99
    fprintf('\n[РЕЗУЛЬТАТ]  99%% совпадение в пределах ±1 LSB (приемлемо для округлений).\n');
else
    fprintf('\n[РЕЗУЛЬТАТ]  ВНИМАНИЕ: расхождение превышает допустимое. Требуется отладка.\n');
end

end
