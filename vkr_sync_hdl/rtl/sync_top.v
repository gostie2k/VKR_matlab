`timescale 1ns / 1ps
//==========================================================================
// Модуль       : sync_top
// Описание     : Верхний уровень блока символьной синхронизации Gardner.
//                Объединяет: sync_agc, sync_farrow_parab, sync_mod1_nco,
//                sync_ted_gardner, sync_loop_filter_pi.
//                Потоковый интерфейс AXI-Stream 32 бит (16I + 16Q).
//                Управление через регистры (от AXI-Lite wrapper'а).
//
// Регистровая карта (от AXI-Lite, адресуется в sync_top_axi_lite):
//   0x00  CTRL       [0] soft_reset, [1] enable, [2] agc_bypass
//   0x04  STATUS     [0] lock (зарезервировано)
//   0x08  K1         Q1.15 коэффициент PI (пропорциональный)
//   0x0C  K2         Q1.15 коэффициент PI (интегральный)
//   0x10  W_NOM      Q0.16 номинальный шаг NCO (= 1/sps_rx)
//   0x14  CLAMP      Q0.16 граница насыщения PI
//   0x18  AGC_TGT    целевая мощность AGC
//   0x1C  DEBUG      {W[15:0], mu[15:0]} (read-only)
//
// Автор        : Кудимов А.А., ВКР магистра, 2026
//==========================================================================
module sync_top #(
    parameter W_DATA = 16,   // разрядность I/Q
    parameter W_MU   = 12,   // разрядность μ
    parameter W_COEF = 16,   // разрядность K1, K2
    parameter W_NCO  = 16    // разрядность счётчика NCO
)(
    input  wire                          clk,
    input  wire                          reset,

    // AXI-Stream вход (от DDC / RRC)
    input  wire [2*W_DATA-1:0]           s_axis_tdata,   // {I[15:0], Q[15:0]}
    input  wire                          s_axis_tvalid,
    output wire                          s_axis_tready,

    // AXI-Stream выход (символы после синхронизации)
    output wire [2*W_DATA-1:0]           m_axis_tdata,   // {I[15:0], Q[15:0]}
    output wire                          m_axis_tvalid,

    // Регистровый интерфейс (от AXI-Lite wrapper)
    input  wire                          ctrl_soft_reset,
    input  wire                          ctrl_enable,
    input  wire                          ctrl_agc_bypass,
    input  wire signed [W_COEF-1:0]      reg_k1,
    input  wire signed [W_COEF-1:0]      reg_k2,
    input  wire        [W_NCO-1:0]       reg_w_nom,
    input  wire        [W_DATA-1:0]      reg_clamp,
    input  wire        [32:0]            reg_agc_target,

    // Debug выход
    output wire [W_NCO-1:0]             debug_w,
    output wire [W_MU-1:0]              debug_mu
);

// =========================================================================
// Разделение входного потока
// =========================================================================
wire signed [W_DATA-1:0] in_i = s_axis_tdata[2*W_DATA-1 : W_DATA];
wire signed [W_DATA-1:0] in_q = s_axis_tdata[W_DATA-1 : 0];
wire                     in_valid = s_axis_tvalid & ctrl_enable;

// Всегда готовы принять данные (конвейерная архитектура без backpressure)
assign s_axis_tready = 1'b1;

// Общий сброс
wire rst = reset | ctrl_soft_reset;

// =========================================================================
// 1. AGC (опциональная)
// =========================================================================
wire                     agc_valid;
wire signed [W_DATA-1:0] agc_i, agc_q;

sync_agc #(
    .W_IN   (W_DATA),
    .W_OUT  (W_DATA),
    .W_ACC  (33),
    .N_AGC  (5)
) u_agc (
    .clk        (clk),
    .reset      (rst),
    .in_valid   (in_valid),
    .in_i       (in_i),
    .in_q       (in_q),
    .agc_bypass (ctrl_agc_bypass),
    .p_target   (reg_agc_target),
    .out_valid  (agc_valid),
    .out_i      (agc_i),
    .out_q      (agc_q)
);

// =========================================================================
// 2. Интерполятор Фарроу
// =========================================================================
wire                     farrow_valid;
wire signed [W_DATA-1:0] farrow_i, farrow_q;
wire        [W_MU-1:0]   mu_wire;

sync_farrow_parab #(
    .W_IN  (W_DATA),
    .W_MU  (W_MU),
    .W_OUT (W_DATA)
) u_farrow (
    .clk       (clk),
    .reset     (rst),
    .in_valid  (agc_valid),
    .in_i      (agc_i),
    .in_q      (agc_q),
    .mu_in     (mu_wire),
    .out_valid (farrow_valid),
    .xi_i      (farrow_i),
    .xi_q      (farrow_q)
);

// =========================================================================
// 3. NCO
// =========================================================================
wire         nco_strobe;
wire [W_MU-1:0] nco_mu;

// Шаг NCO = W_nom + v_pi
wire signed [W_NCO-1:0] v_pi_wire;
wire [W_NCO-1:0] w_step = $unsigned($signed(reg_w_nom) + v_pi_wire);

sync_mod1_nco #(
    .W_CNT (W_NCO),
    .W_MU  (W_MU),
    .W_W   (W_NCO)
) u_nco (
    .clk      (clk),
    .reset    (rst),
    .in_valid (agc_valid),     // NCO тактируется входным потоком
    .w_step   (w_step),
    .strobe   (nco_strobe),
    .mu_out   (nco_mu)
);

assign mu_wire = nco_mu;

// =========================================================================
// 4. Детектор ошибки Гарднера
// =========================================================================
wire         ted_valid;
wire signed [W_DATA-1:0] ted_error;

sync_ted_gardner #(
    .W_IN  (W_DATA),
    .W_ERR (W_DATA)
) u_ted (
    .clk        (clk),
    .reset      (rst),
    .in_valid   (farrow_valid),
    .xi_i       (farrow_i),
    .xi_q       (farrow_q),
    .strobe     (nco_strobe),
    .e_out_valid(ted_valid),
    .e_out      (ted_error)
);

// =========================================================================
// 5. PI-фильтр
// =========================================================================
wire         pi_valid;
wire signed [W_DATA-1:0] pi_out;

sync_loop_filter_pi #(
    .W_ERR  (W_DATA),
    .W_COEF (W_COEF),
    .W_ACC  (32),
    .W_OUT  (W_DATA)
) u_pi (
    .clk        (clk),
    .reset      (rst),
    .e_valid    (ted_valid),
    .e_in       (ted_error),
    .k1         (reg_k1),
    .k2         (reg_k2),
    .clamp_lim  (reg_clamp),
    .v_pi_valid (pi_valid),
    .v_pi_out   (pi_out)
);

assign v_pi_wire = pi_out;

// =========================================================================
// Выходной поток: символы по стробу NCO
// =========================================================================
// Стробированный выход: Фарроу выдаёт значения каждый такт, но «символом»
// является только тот XI, который пришёл на такте strobe NCO.
// Для простоты: выход формируется по nco_strobe с задержкой на конвейер Farrow.

// Задержка strobe на 3 такта (= латентность Фарроу) для совпадения с farrow_valid
reg strobe_d1, strobe_d2, strobe_d3;
always @(posedge clk or posedge reset) begin
    if (rst) begin
        strobe_d1 <= 0; strobe_d2 <= 0; strobe_d3 <= 0;
    end else begin
        strobe_d1 <= nco_strobe;
        strobe_d2 <= strobe_d1;
        strobe_d3 <= strobe_d2;
    end
end

wire sym_valid = farrow_valid & strobe_d3;

assign m_axis_tdata  = {farrow_i, farrow_q};
assign m_axis_tvalid = sym_valid;

// =========================================================================
// Debug
// =========================================================================
assign debug_w  = w_step;
assign debug_mu = nco_mu;

endmodule
