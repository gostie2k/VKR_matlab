`timescale 1ns / 1ps
//==========================================================================
// Модуль       : sync_agc
// Описание     : Автоматическая регулировка усиления (АРУ).
//                Нормирует амплитуду входного сигнала к целевому уровню.
//                IIR-петля: accum += (P_target - |x|²) >> N_AGC
//                Выход: Kagc = accum[MSB:MSB-15], вход умножается на Kagc.
//                Режим bypass: при agc_bypass = 1 вход проходит насквозь.
//
// Латентность  : 2 такта от in_valid до out_valid (после OOC-этапа 3.12
//                добавлена pipeline-ступень между квадратами I²/Q² и
//                накопителем, чтобы разорвать длинную CARRY-цепочку)
// Ресурсы      : 3 × DSP48E1 (I², Q², I·Kagc/Q·Kagc мультиплексированы)
//
// Автор        : Кудимов А.А., ВКР магистра, 2026
//==========================================================================
module sync_agc #(
    parameter W_IN    = 16,
    parameter W_OUT   = 16,
    parameter W_ACC   = 33,    // разрядность аккумулятора AGC
    parameter N_AGC   = 5      // сдвиг коэффициента обратной связи (2^-N_AGC)
)(
    input  wire                          clk,
    input  wire                          reset,
    input  wire                          in_valid,
    input  wire signed [W_IN-1:0]        in_i,
    input  wire signed [W_IN-1:0]        in_q,
    // Управление
    input  wire                          agc_bypass,
    input  wire        [W_ACC-1:0]       p_target,   // целевая мощность
    // Выход
    output reg                           out_valid,
    output reg  signed [W_OUT-1:0]       out_i,
    output reg  signed [W_OUT-1:0]       out_q
);

// =========================================================================
// Коэффициент усиления Kagc
// =========================================================================
reg [W_ACC-1:0] accum;
wire [16:0] kagc = accum[W_ACC-1 -: 17];  // старшие 17 бит аккумулятора

// =========================================================================
// Ступень 1: DSP-произведения (без сложения)
//   sq_i_reg <= in_i · in_i
//   sq_q_reg <= in_q · in_q
//   in_*_d   <= in_*   (продвижение входа для умножения на Kagc на ступени 2)
//   valid_sq <= in_valid
// Pipeline-вставка между квадратами и финальным сумматором/накопителем
// для разрыва критической цепи DSP→ADD→ADD→sub→shift→ACCUM одного такта.
// =========================================================================
wire signed [2*W_IN-1:0] sq_i_w = in_i * in_i;
wire signed [2*W_IN-1:0] sq_q_w = in_q * in_q;

reg signed [2*W_IN-1:0] sq_i_reg, sq_q_reg;
reg signed [W_IN-1:0]   in_i_d,   in_q_d;
reg                     valid_sq;
reg                     agc_bypass_d;

always @(posedge clk or posedge reset) begin
    if (reset) begin
        sq_i_reg     <= 0;
        sq_q_reg     <= 0;
        in_i_d       <= 0;
        in_q_d       <= 0;
        valid_sq     <= 1'b0;
        agc_bypass_d <= 1'b0;
    end else begin
        if (in_valid) begin
            sq_i_reg     <= sq_i_w;
            sq_q_reg     <= sq_q_w;
            in_i_d       <= in_i;
            in_q_d       <= in_q;
            agc_bypass_d <= agc_bypass;
        end
        valid_sq <= in_valid;
    end
end

// =========================================================================
// Ступень 2: сумма квадратов, ошибка по мощности, накопление и умножение на Kagc
// =========================================================================
// |x|² = I² + Q² (используем зарегистрированные квадраты)
wire signed [2*W_IN:0] power = {sq_i_reg[2*W_IN-1], sq_i_reg} +
                                {sq_q_reg[2*W_IN-1], sq_q_reg};

// Разность P_target − |x|², масштабированная >> N_AGC
wire signed [W_ACC-1:0] power_ext = {{(W_ACC - 2*W_IN - 1){power[2*W_IN]}}, power};
wire signed [W_ACC-1:0] p_tgt_signed = $signed(p_target);
wire signed [W_ACC-1:0] error_agc = p_tgt_signed - power_ext;
wire signed [W_ACC-1:0] error_scaled = error_agc >>> N_AGC;

// Умножение вход × Kagc (16 × 17 бит) — используем зарегистрированный вход
wire signed [W_IN+16:0] mult_i = in_i_d * $signed({1'b0, kagc});
wire signed [W_IN+16:0] mult_q = in_q_d * $signed({1'b0, kagc});

// Насыщающее усечение mult до W_OUT
localparam W_MG = W_IN + 17;
localparam SHIFT_G = W_MG - W_OUT;
wire signed [W_OUT-1:0] gain_i, gain_q;

// Нормировка: Kagc номинально ≈ 1.0, представлен в старших 17 битах аккумулятора.
// Предполагаем начальное значение accum с единицей в позиции MSB-1.
// Масштаб mult: Q(1+1).(W_IN-1+16) → для выхода Q1.(W_OUT-1) сдвигаем
// на (16) бит вправо (позиция Kagc).
localparam SH = 16;
assign gain_i = mult_i[SH +: W_OUT];
assign gain_q = mult_q[SH +: W_OUT];

// =========================================================================
// Регистры выхода
// =========================================================================
always @(posedge clk or posedge reset) begin
    if (reset) begin
        accum     <= {1'b0, 1'b1, {(W_ACC-2){1'b0}}};  // начальный Kagc ≈ 1.0
        out_valid <= 1'b0;
        out_i     <= 0;
        out_q     <= 0;
    end else if (valid_sq) begin
        // Обновление аккумулятора (только если AGC активна)
        if (!agc_bypass_d) begin
            accum <= $unsigned($signed(accum) + error_scaled);
        end
        // Выход: bypass или усиленный (используем зарегистрированный вход)
        if (agc_bypass_d) begin
            out_i <= in_i_d;
            out_q <= in_q_d;
        end else begin
            out_i <= gain_i;
            out_q <= gain_q;
        end
        out_valid <= 1'b1;
    end else begin
        out_valid <= 1'b0;
    end
end

endmodule
