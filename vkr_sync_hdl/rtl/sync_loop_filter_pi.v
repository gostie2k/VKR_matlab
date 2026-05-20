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
// Конвейер     : 3 такта от e_valid до v_pi_valid
//                (ступень 3 добавлена после OOC-синтеза этапа 3.12
//                 для разрыва критической цепи adder→sat→adder→sat)
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
// Округление перед усечением (round-to-nearest), устраняет
// систематический отрицательный bias арифм. сдвига >>>15
wire signed [W_PROD-1:0] prod_k1_r = prod_k1 + (1 << 14);
wire signed [W_PROD-1:0] prod_k2_r = prod_k2 + (1 << 14);
assign vp_full  = {{(W_ACC - W_PROD + SHIFT_P){prod_k1_r[W_PROD-1]}}, prod_k1_r[W_PROD-1:SHIFT_P]};
assign k2e_full = {{(W_ACC - W_PROD + SHIFT_P){prod_k2_r[W_PROD-1]}}, prod_k2_r[W_PROD-1:SHIFT_P]};

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
// Ступень 2: обновление интегратора (vi_reg)
//   vi_sum = vi_reg + k2e_s1      (32-bit add, комб.)
//   vi_sat = saturate(vi_sum)     (32-bit compare, комб.)
//   vi_reg <= vi_sat              (на posedge clk при valid_s1)
//
// Одновременно проталкиваем vp_s1 → vp_s1_d на один такт вперёд,
// чтобы на ступени 3 сложить vp_s1_d с обновлённым vi_reg.
// =========================================================================
reg signed [W_ACC-1:0] vi_reg;   // регистр интегратора
reg signed [W_ACC-1:0] vp_s1_d;  // задержанный vp_s1 для ступени 3
reg                    valid_s2; // валид ступени 3

// Граница насыщения в формате W_ACC с расширением
wire signed [W_ACC-1:0] clamp_pos = {{(W_ACC - W_OUT){1'b0}}, clamp_lim};
wire signed [W_ACC-1:0] clamp_neg = -clamp_pos;

// vi_new = vi + K2·e
wire signed [W_ACC-1:0] vi_sum = vi_reg + k2e_s1;

// Насыщение интегратора (anti-windup)
wire signed [W_ACC-1:0] vi_sat;
assign vi_sat = (vi_sum > clamp_pos) ? clamp_pos :
                (vi_sum < clamp_neg) ? clamp_neg : vi_sum;

always @(posedge clk or posedge reset) begin
    if (reset) begin
        vi_reg   <= 0;
        vp_s1_d  <= 0;
        valid_s2 <= 1'b0;
    end else begin
        if (valid_s1) begin
            vi_reg  <= vi_sat;
            vp_s1_d <= vp_s1;
        end
        valid_s2 <= valid_s1;
    end
end

// =========================================================================
// Ступень 3: формирование выхода v_pi
//   v_pi_sum   = vp_s1_d + vi_reg          (32-bit add, комб.)
//   v_pi_clp   = saturate(v_pi_sum)        (32-bit compare, комб.)
//   v_pi_trunc = v_pi_clp[W_OUT-1:0]       (битовое усечение, комб.)
//   v_pi_out   <= v_pi_trunc               (на posedge clk при valid_s2)
//
// Pipeline-вставка добавляет 1 такт латентности (теперь 3 такта от
// e_valid до v_pi_valid). Это снимает критическую цепь
// adder→sat→adder→sat одного такта, выявленную при OOC-синтезе.
// =========================================================================
wire signed [W_ACC-1:0] v_pi_sum = vp_s1_d + vi_reg;

wire signed [W_ACC-1:0] v_pi_clamped;
assign v_pi_clamped = (v_pi_sum > clamp_pos) ? clamp_pos :
                      (v_pi_sum < clamp_neg) ? clamp_neg : v_pi_sum;

wire signed [W_OUT-1:0] v_pi_trunc = v_pi_clamped[W_OUT-1:0];

always @(posedge clk or posedge reset) begin
    if (reset) begin
        v_pi_out   <= 0;
        v_pi_valid <= 1'b0;
    end else begin
        if (valid_s2) begin
            v_pi_out <= v_pi_trunc;
        end
        v_pi_valid <= valid_s2;
    end
end

endmodule
