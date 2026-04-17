`timescale 1ns / 1ps
//==========================================================================
// Тестбенч     : tb_sync_top
// Описание     : Интеграционная верификация sync_top.
//                Подаёт QPSK-сигнал с timing offset (sps_rx = 2),
//                записывает выходные символы и внутренние сигналы в файлы
//                для анализа в MATLAB/Python.
//
// Стимулы      : sync_stim_i.hex, sync_stim_q.hex
//                (генерируются gen_sync_top_stimulus.py)
//
// Выход        : sync_out_symbols.txt — I Q valid (по стробу)
//                sync_out_debug.txt   — W mu e (каждый такт)
//==========================================================================
module tb_sync_top;

// Параметры
localparam W_DATA   = 16;
localparam W_MU     = 12;
localparam W_COEF   = 16;
localparam W_NCO    = 16;
localparam CLK_PER  = 16;     // нс (~62.5 МГц)
localparam MAX_SAMP = 8000;

// Параметры PI (из sync_params.vh)
localparam N_STIM      = 3960;
localparam [15:0] K1_VAL    = 16'hFD8A;
localparam [15:0] K2_VAL    = 16'hFFEF;
localparam [15:0] W_NOM_VAL = 16'h8000;
localparam [15:0] CLAMP_VAL = 16'h4000;

// Сигналы DUT
reg                          clk;
reg                          reset;
reg  [2*W_DATA-1:0]          s_axis_tdata;
reg                          s_axis_tvalid;
wire                         s_axis_tready;
wire [2*W_DATA-1:0]          m_axis_tdata;
wire                         m_axis_tvalid;
wire [W_NCO-1:0]             debug_w;
wire [W_MU-1:0]              debug_mu;

// Регистровый интерфейс
reg                          ctrl_soft_reset;
reg                          ctrl_enable;
reg                          ctrl_agc_bypass;
reg  signed [W_COEF-1:0]     reg_k1;
reg  signed [W_COEF-1:0]     reg_k2;
reg         [W_NCO-1:0]      reg_w_nom;
reg         [W_DATA-1:0]     reg_clamp;
reg         [32:0]           reg_agc_target;

// DUT
sync_top #(
    .W_DATA (W_DATA),
    .W_MU   (W_MU),
    .W_COEF (W_COEF),
    .W_NCO  (W_NCO)
) dut (
    .clk             (clk),
    .reset           (reset),
    .s_axis_tdata    (s_axis_tdata),
    .s_axis_tvalid   (s_axis_tvalid),
    .s_axis_tready   (s_axis_tready),
    .m_axis_tdata    (m_axis_tdata),
    .m_axis_tvalid   (m_axis_tvalid),
    .ctrl_soft_reset (ctrl_soft_reset),
    .ctrl_enable     (ctrl_enable),
    .ctrl_agc_bypass (ctrl_agc_bypass),
    .reg_k1          (reg_k1),
    .reg_k2          (reg_k2),
    .reg_w_nom       (reg_w_nom),
    .reg_clamp       (reg_clamp),
    .reg_agc_target  (reg_agc_target),
    .debug_w         (debug_w),
    .debug_mu        (debug_mu)
);

// Тактовый сигнал
initial clk = 1'b0;
always #(CLK_PER/2) clk = ~clk;

// Память стимулов
reg signed [W_DATA-1:0] stim_i [0:MAX_SAMP-1];
reg signed [W_DATA-1:0] stim_q [0:MAX_SAMP-1];

integer i, fout_sym, fout_dbg;
integer n_sym_out;

initial begin
    $dumpfile("tb_sync_top.vcd");
    $dumpvars(0, tb_sync_top);

    // Инициализация
    for (i = 0; i < MAX_SAMP; i = i + 1) begin
        stim_i[i] = 0;
        stim_q[i] = 0;
    end
    $readmemh("sync_stim_i.hex", stim_i);
    $readmemh("sync_stim_q.hex", stim_q);

    // Начальные значения
    reset           = 1'b1;
    s_axis_tdata    = 0;
    s_axis_tvalid   = 1'b0;
    ctrl_soft_reset = 1'b0;
    ctrl_enable     = 1'b0;
    ctrl_agc_bypass = 1'b1;    // AGC отключена для bit-accurate сравнения
    reg_k1          = K1_VAL;
    reg_k2          = K2_VAL;
    reg_w_nom       = W_NOM_VAL;
    reg_clamp       = CLAMP_VAL;
    reg_agc_target  = {1'b0, 1'b1, {31{1'b0}}};  // P_target = 0.5 (не используется при bypass)

    // Открытие файлов
    fout_sym = $fopen("sync_out_symbols.txt", "w");
    fout_dbg = $fopen("sync_out_debug.txt", "w");

    // Сброс
    repeat(5) @(posedge clk);
    @(negedge clk) reset = 1'b0;
    repeat(3) @(posedge clk);

    // Включение
    @(negedge clk) ctrl_enable = 1'b1;
    @(posedge clk);

    // Подача стимулов
    $display("[tb_sync_top] Starting stimulus: %0d samples", N_STIM);
    n_sym_out = 0;

    for (i = 0; i < N_STIM; i = i + 1) begin
        @(negedge clk);
        s_axis_tdata  = {stim_i[i], stim_q[i]};
        s_axis_tvalid = 1'b1;
    end

    // Доработка конвейера
    @(negedge clk);
    s_axis_tvalid = 1'b0;
    s_axis_tdata  = 0;
    repeat(20) @(posedge clk);

    $fclose(fout_sym);
    $fclose(fout_dbg);
    $display("[tb_sync_top] Done. Output symbols: %0d", n_sym_out);
    $finish;
end

// Запись выходных символов
always @(posedge clk) begin
    if (!reset && m_axis_tvalid) begin
        $fwrite(fout_sym, "%0d %0d\n",
                $signed(m_axis_tdata[2*W_DATA-1:W_DATA]),
                $signed(m_axis_tdata[W_DATA-1:0]));
        n_sym_out = n_sym_out + 1;
    end
end

// Запись debug-сигналов каждый такт
always @(posedge clk) begin
    if (!reset && ctrl_enable) begin
        $fwrite(fout_dbg, "%0d %0d\n", debug_w, debug_mu);
    end
end

endmodule
