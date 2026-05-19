`timescale 1ns / 1ps
//==========================================================================
// Модуль       : sync_loop_filter_pi
// Описание     : Пропорционально-интегральный фильтр второго порядка
//                с anti-windup (насыщение интегратора).
//                vp     = K1 · e
//                vi_new = sat(vi + K2 · e, ±clamp)
//                v_pi   = sat(vp + vi_new, ±clamp)
//
// Коэффициенты : K1, K2 загружаются через порты (от AXI-Lite в sync_top).
//                Формат — знаковое Q1.15 (16 бит).
//                Для рабочих параметров B_n·T = 0,02, ζ = 1/√2, K_p = 2,7:
//                  K1 ≈ −0,0192 → 0xFB12 в Q1.15
//                  K2 ≈ −5,13·10⁻⁴ → 0xFFEF в Q1.15
//
// Конвейер     : 2 такта от e_valid до v_pi_valid
// Ресурсы      : 2 × DSP48E1, ~100 LUT (насыщение + сумматоры)
//
// Автор        : Кудимов А.А., ВКР магистра, 2026
//==========================================================================
module sync_loop_filter_pi #(
    parameter W_ERR  = 16,   // разрядность входа ошибки e
    parameter W_COEF = 16,   // разрядность K1, K2 (Q1.15)
    parameter W_ACC  = 32,   // разрядность интегратора vi
    parameter W_OUT  = 16    // разрядность выхода v_pi
)(
    input  wire                          clk,
    input  wire                          reset,
    // Вход
    input  wire                          e_valid,
    input  wire signed [W_ERR-1:0]       e_in,
    // Коэффициенты (от AXI-Lite)
    input  wire signed [W_COEF-1:0]      k1,       // пропорциональный
    input  wire signed [W_COEF-1:0]      k2,       // интегральный
    input  wire        [W_OUT-1:0]       clamp_lim, // граница насыщения (беззнаковое)
    // Выход
    output reg                           v_pi_valid,
    output reg  signed [W_OUT-1:0]       v_pi_out
);

// =========================================================================
// Ступень 1: умножения K1·e и K2·e
// =========================================================================
localparam W_PROD = W_ERR + W_COEF;  // полная разрядность произведения

wire signed [W_PROD-1:0] prod_k1 = e_in * k1;
wire signed [W_PROD-1:0] prod_k2 = e_in * k2;

// Масштабирование: K в Q1.15, e в Q1.15 → произведение в Q2.30
// Для выхода в Q1.(W_OUT-1) нужен сдвиг вправо на (W_COEF - 1) бит
localparam SHIFT_P = W_COEF - 1;  // = 15

// vp в полной точности (для сложения с vi)
wire signed [W_ACC-1:0] vp_full;
wire signed [W_ACC-1:0] k2e_full;

// Сдвиг + sign-extension до W_ACC
assign vp_full  = {{(W_ACC - W_PROD + SHIFT_P){prod_k1[W_PROD-1]}}, prod_k1[W_PROD-1:SHIFT_P]};
assign k2e_full = {{(W_ACC - W_PROD + SHIFT_P){prod_k2[W_PROD-1]}}, prod_k2[W_PROD-1:SHIFT_P]};

reg signed [W_ACC-1:0] vp_s1;
reg signed [W_ACC-1:0] k2e_s1;
reg                    valid_s1;

always @(posedge clk or posedge reset) begin
    if (reset) begin
        vp_s1   <= 0;
        k2e_s1  <= 0;
        valid_s1 <= 1'b0;
    end else begin
        if (e_valid) begin
            vp_s1  <= vp_full;
            k2e_s1 <= k2e_full;
        end
        valid_s1 <= e_valid;
    end
end

// =========================================================================
// Ступень 2: обновление интегратора и формирование выхода
// =========================================================================
reg signed [W_ACC-1:0] vi_reg;  // регистр интегратора

// Граница насыщения в формате W_ACC с расширением
wire signed [W_ACC-1:0] clamp_pos = {{(W_ACC - W_OUT){1'b0}}, clamp_lim};
wire signed [W_ACC-1:0] clamp_neg = -clamp_pos;

// vi_new = vi + K2·e
wire signed [W_ACC-1:0] vi_sum = vi_reg + k2e_s1;

// Насыщение интегратора (anti-windup)
wire signed [W_ACC-1:0] vi_sat;
assign vi_sat = (vi_sum > clamp_pos) ? clamp_pos :
                (vi_sum < clamp_neg) ? clamp_neg : vi_sum;

// Выход петли: v_pi = vp + vi_sat
wire signed [W_ACC-1:0] v_pi_sum = vp_s1 + vi_sat;

// Насыщение выхода
wire signed [W_ACC-1:0] v_pi_clamped;
assign v_pi_clamped = (v_pi_sum > clamp_pos) ? clamp_pos :
                      (v_pi_sum < clamp_neg) ? clamp_neg : v_pi_sum;

// Усечение до W_OUT бит (берём младшие W_OUT)
wire signed [W_OUT-1:0] v_pi_trunc = v_pi_clamped[W_OUT-1:0];

always @(posedge clk or posedge reset) begin
    if (reset) begin
        vi_reg     <= 0;
        v_pi_out   <= 0;
        v_pi_valid <= 1'b0;
    end else begin
        if (valid_s1) begin
            vi_reg   <= vi_sat;
            v_pi_out <= v_pi_trunc;
        end
        v_pi_valid <= valid_s1;
    end
end

endmodule
