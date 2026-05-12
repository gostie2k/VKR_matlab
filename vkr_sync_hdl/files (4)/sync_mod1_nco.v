`timescale 1ns / 1ps
//==========================================================================
// Модуль       : sync_mod1_nco
// Описание     : Вычитающий счётчик по модулю 1 (Mod-1 NCO)
//                μ = CNT_old / W — полноценное деление.
//                Для синтеза заменяется на Divider IP или LUT(1/W).
//
// Автор        : Кудимов А.А., ВКР магистра, 2026
//==========================================================================
module sync_mod1_nco #(
    parameter W_CNT = 16,
    parameter W_MU  = 12,
    parameter W_W   = 16
)(
    input  wire                          clk,
    input  wire                          reset,
    input  wire                          in_valid,
    input  wire        [W_W-1:0]         w_step,
    output reg                           strobe,
    output reg         [W_MU-1:0]        mu_out
);

localparam W_EXT = W_CNT + 1;

reg [W_CNT-1:0] cnt_reg;

// Детекция underflow
wire [W_EXT-1:0] cnt_ext   = {1'b0, cnt_reg};
wire [W_EXT-1:0] w_ext     = {1'b0, w_step[W_W-1:W_W-W_CNT]};
wire [W_EXT-1:0] cnt_next  = cnt_ext - w_ext;
wire             underflow = cnt_next[W_EXT-1];

wire [W_CNT-1:0] cnt_wrap  = cnt_next[W_CNT-1:0];

// =========================================================================
// Полноценное деление μ = CNT_old / W
// μ_Q = (CNT_old << W_MU) / w_step
// Результат в Q0.W_MU, диапазон [0, 1)
//
// Для симуляции: поведенческое деление (synthesizable через Divider IP)
// =========================================================================
wire [W_CNT + W_MU - 1:0] cnt_shifted = {cnt_reg, {W_MU{1'b0}}};
wire [W_CNT + W_MU - 1:0] mu_full     = (w_step != 0) ? cnt_shifted / w_step : 0;
wire [W_MU-1:0]           mu_calc     = mu_full[W_MU-1:0];

// =========================================================================
// Основной автомат
// =========================================================================
always @(posedge clk or posedge reset) begin
    if (reset) begin
        cnt_reg <= {1'b1, {(W_CNT-1){1'b0}}};  // CNT_init = W_nom = 0.5
        strobe  <= 1'b0;
        mu_out  <= {W_MU{1'b0}};
    end else if (in_valid) begin
        if (underflow) begin
            cnt_reg <= cnt_wrap;
            strobe  <= 1'b1;
            mu_out  <= mu_calc;
        end else begin
            cnt_reg <= cnt_next[W_CNT-1:0];
            strobe  <= 1'b0;
        end
    end else begin
        strobe <= 1'b0;
    end
end

endmodule
