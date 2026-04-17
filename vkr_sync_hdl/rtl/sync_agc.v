`timescale 1ns / 1ps
//==========================================================================
// Модуль       : sync_agc
// Описание     : Автоматическая регулировка усиления (АРУ).
//                Нормирует амплитуду входного сигнала к целевому уровню.
//                IIR-петля: accum += (P_target - |x|²) >> N_AGC
//                Выход: Kagc = accum[MSB:MSB-15], вход умножается на Kagc.
//                Режим bypass: при agc_bypass = 1 вход проходит насквозь.
//
// Латентность  : 2 такта (умножение |x|² + обновление аккумулятора)
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
// Ступень 1: вычисление мощности и умножение на Kagc
// =========================================================================
// |x|² = I² + Q² (используем старшие биты для экономии)
wire signed [2*W_IN-1:0] power_i = in_i * in_i;
wire signed [2*W_IN-1:0] power_q = in_q * in_q;
wire signed [2*W_IN:0]   power   = {power_i[2*W_IN-1], power_i} +
                                    {power_q[2*W_IN-1], power_q};

// Разность P_target − |x|², масштабированная >> N_AGC
wire signed [W_ACC-1:0] power_ext = {{(W_ACC - 2*W_IN - 1){power[2*W_IN]}}, power};
wire signed [W_ACC-1:0] p_tgt_signed = $signed(p_target);
wire signed [W_ACC-1:0] error_agc = p_tgt_signed - power_ext;
wire signed [W_ACC-1:0] error_scaled = error_agc >>> N_AGC;

// Умножение вход × Kagc (16 × 17 бит)
wire signed [W_IN+16:0] mult_i = in_i * $signed({1'b0, kagc});
wire signed [W_IN+16:0] mult_q = in_q * $signed({1'b0, kagc});

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
    end else if (in_valid) begin
        // Обновление аккумулятора (только если AGC активна)
        if (!agc_bypass) begin
            accum <= $unsigned($signed(accum) + error_scaled);
        end
        // Выход: bypass или усиленный
        if (agc_bypass) begin
            out_i <= in_i;
            out_q <= in_q;
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
