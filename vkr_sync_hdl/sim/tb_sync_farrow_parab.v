`timescale 1ns / 1ps
//==========================================================================
// Тестбенч     : tb_sync_farrow_parab
// Описание     : Bit-accurate верификация модуля sync_farrow_parab
//                Читает входные отсчёты I/Q и значения μ из файлов stimulus,
//                прогоняет через модуль, пишет выходной интерполянт в файл.
//                Параллельно MATLAB-скрипт test_sync_farrow_parab.m
//                формирует золотой вектор тех же входов и сравнивает результат.
//
// Формат файлов:
//    stimulus_in.txt   — ASCII, по одному числу на строку, W_IN-битное целое
//                        со знаком. Порядок: i0 q0 i1 q1 i2 q2 ... (4 строки на отсчёт)
//                        Последняя величина в строке — значение μ (беззнаковое W_MU бит).
//                        Итого 3 числа на тактовый период in_valid.
//    stimulus_mu.txt   — отдельный файл μ (по одному значению на такт)
//    out_hdl.txt       — вывод ASCII: i_out q_out valid (по одной строке на такт)
//==========================================================================
module tb_sync_farrow_parab;

// Параметры моделирования
localparam W_IN  = 16;
localparam W_MU  = 12;
localparam W_OUT = 16;
localparam CLK_PERIOD = 16;     // 62.5 МГц — типично для выхода DDC AD9361
localparam MAX_SAMPLES = 20000;

// Сигналы DUT
reg                      clk;
reg                      reset;
reg                      in_valid;
reg  signed [W_IN-1:0]   in_i;
reg  signed [W_IN-1:0]   in_q;
reg         [W_MU-1:0]   mu_in;
wire                     out_valid;
wire signed [W_OUT-1:0]  xi_i;
wire signed [W_OUT-1:0]  xi_q;

// Подключение DUT
sync_farrow_parab #(
    .W_IN  (W_IN),
    .W_MU  (W_MU),
    .W_OUT (W_OUT)
) dut (
    .clk       (clk),
    .reset     (reset),
    .in_valid  (in_valid),
    .in_i      (in_i),
    .in_q      (in_q),
    .mu_in     (mu_in),
    .out_valid (out_valid),
    .xi_i      (xi_i),
    .xi_q      (xi_q)
);

// Генератор тактового сигнала
initial clk = 1'b0;
always #(CLK_PERIOD/2) clk = ~clk;

// Память входных стимулов
reg signed [W_IN-1:0]  stim_i  [0:MAX_SAMPLES-1];
reg signed [W_IN-1:0]  stim_q  [0:MAX_SAMPLES-1];
reg        [W_MU-1:0]  stim_mu [0:MAX_SAMPLES-1];

integer n_samples;
integer i;
integer fout;

initial begin
    // Инициализация
    reset    = 1'b1;
    in_valid = 1'b0;
    in_i     = 0;
    in_q     = 0;
    mu_in    = 0;

    // Загрузка стимулов из файлов (сгенерированы скриптом gen_farrow_stimulus.m)
    for (i = 0; i < MAX_SAMPLES; i = i + 1) begin
        stim_i[i]  = 0;
        stim_q[i]  = 0;
        stim_mu[i] = 0;
    end
    $readmemh("stim_i.hex",  stim_i);
    $readmemh("stim_q.hex",  stim_q);
    $readmemh("stim_mu.hex", stim_mu);

    // Подсчёт фактического числа отсчётов (до первого «нулевого» маркера)
    n_samples = MAX_SAMPLES;
    for (i = MAX_SAMPLES-1; i >= 0; i = i - 1) begin
        if ((stim_i[i] == 0) && (stim_q[i] == 0) && (stim_mu[i] == 0)) begin
            n_samples = i;
        end
    end
    $display("[tb_sync_farrow_parab] Loaded %0d stimulus samples", n_samples);

    // Открытие выходного файла
    fout = $fopen("out_hdl.txt", "w");
    if (fout == 0) begin
        $display("[tb_sync_farrow_parab] ERROR: cannot open out_hdl.txt");
        $finish;
    end

    // Сброс
    @(posedge clk); @(posedge clk); @(posedge clk);
    @(negedge clk) reset = 1'b0;
    @(posedge clk);

    // Подача стимулов — по одному отсчёту на каждый такт clk
    for (i = 0; i < n_samples; i = i + 1) begin
        @(negedge clk);
        in_valid = 1'b1;
        in_i     = stim_i[i];
        in_q     = stim_q[i];
        mu_in    = stim_mu[i];
    end
    // Сбросить in_valid и подождать окончания конвейера (3 такта)
    @(negedge clk);
    in_valid = 1'b0;
    in_i     = 0;
    in_q     = 0;
    mu_in    = 0;

    repeat (10) @(posedge clk);

    $fclose(fout);
    $display("[tb_sync_farrow_parab] Done, output written to out_hdl.txt");
    $finish;
end

// Логирование выходных отсчётов в файл
always @(posedge clk) begin
    if (~reset) begin
        $fwrite(fout, "%0d %0d %0d\n", xi_i, xi_q, out_valid);
    end
end

// Опциональный дамп VCD для отладки
initial begin
    $dumpfile("tb_sync_farrow_parab.vcd");
    $dumpvars(0, tb_sync_farrow_parab);
end

endmodule
//==========================================================================
// end of tb_sync_farrow_parab
//==========================================================================
