`timescale 1ns / 1ps
//==========================================================================
// Модуль       : sync_ted_gardner
// Описание     : Детектор временной ошибки Гарднера для комплексного сигнала.
//                e = Re{y_mid · conj(y_prev − y_curr)}
//                  = Re(y_mid)·Re(y_prev−y_curr) + Im(y_mid)·Im(y_prev−y_curr)
//
// Работа       : На каждом входном такте обновляется сдвиговый регистр TEDBuff.
//                При sps_rx = 2 и W ≈ 0.5 NCO выдаёт strobe примерно каждые
//                2 такта; TEDBuff[0] (отсчёт с прошлого такта) попадает
//                в середину символьного интервала (y_mid), а TEDBuff[1]
//                (отсчёт с позапрошлого strobe) — это y_prev.
//
// Конвейер     : 2 такта от strobe до e_out_valid
// Ресурсы      : 2 × DSP48E1 (умножения Re·Re и Im·Im), 2 сумматора
//
// Автор        : Кудимов А.А., ВКР магистра, 2026
//==========================================================================
module sync_ted_gardner #(
    parameter W_IN  = 16,   // разрядность XI (вход от Фарроу)
    parameter W_ERR = 16    // разрядность выхода ошибки e
)(
    input  wire                          clk,
    input  wire                          reset,
    // Вход от интерполятора (каждый такт)
    input  wire                          in_valid,
    input  wire signed [W_IN-1:0]        xi_i,
    input  wire signed [W_IN-1:0]        xi_q,
    // Строб от NCO
    input  wire                          strobe,
    // Выход
    output reg                           e_out_valid,
    output reg  signed [W_ERR-1:0]       e_out
);

// =========================================================================
// Сдвиговый регистр TEDBuff — обновляется на КАЖДОМ входном такте
// TEDBuff[0] = XI с прошлого такта (→ y_mid при strobe)
// TEDBuff[1] = XI с позапрошлого такта (→ y_prev при strobe)
// =========================================================================
reg signed [W_IN-1:0] buf0_i, buf0_q;   // TEDBuff[0]
reg signed [W_IN-1:0] buf1_i, buf1_q;   // TEDBuff[1]

always @(posedge clk or posedge reset) begin
    if (reset) begin
        buf0_i <= 0; buf0_q <= 0;
        buf1_i <= 0; buf1_q <= 0;
    end else if (in_valid) begin
        buf1_i <= buf0_i;  buf1_q <= buf0_q;
        buf0_i <= xi_i;    buf0_q <= xi_q;
    end
end

// =========================================================================
// Ступень 1: разности и произведения (по стробу)
// diff = y_prev − y_curr = TEDBuff[1] − XI_current
// mult_re = Re(y_mid) · Re(diff) = buf0_i · diff_i
// mult_im = Im(y_mid) · Im(diff) = buf0_q · diff_q
// =========================================================================
localparam W_DIFF = W_IN + 1;     // +1 бит на вычитание
localparam W_MULT = W_IN + W_DIFF; // произведение

reg signed [W_DIFF-1:0] diff_s1_i, diff_s1_q;
reg signed [W_IN-1:0]   mid_s1_i, mid_s1_q;
reg                      valid_s1;

always @(posedge clk or posedge reset) begin
    if (reset) begin
        diff_s1_i <= 0; diff_s1_q <= 0;
        mid_s1_i  <= 0; mid_s1_q  <= 0;
        valid_s1  <= 1'b0;
    end else begin
        if (strobe && in_valid) begin
            // y_prev − y_curr
            diff_s1_i <= $signed({buf1_i[W_IN-1], buf1_i}) - $signed({xi_i[W_IN-1], xi_i});
            diff_s1_q <= $signed({buf1_q[W_IN-1], buf1_q}) - $signed({xi_q[W_IN-1], xi_q});
            // y_mid = TEDBuff[0]
            mid_s1_i  <= buf0_i;
            mid_s1_q  <= buf0_q;
            valid_s1  <= 1'b1;
        end else begin
            valid_s1  <= 1'b0;
        end
    end
end

// =========================================================================
// Ступень 2: умножения и суммирование
// e = mid_i · diff_i + mid_q · diff_q
// =========================================================================
wire signed [W_MULT-1:0] mult_re = mid_s1_i * diff_s1_i;
wire signed [W_MULT-1:0] mult_im = mid_s1_q * diff_s1_q;
wire signed [W_MULT:0]   e_full  = $signed({mult_re[W_MULT-1], mult_re}) +
                                   $signed({mult_im[W_MULT-1], mult_im});

// Округление и усечение до W_ERR бит
localparam SHIFT_E = W_MULT + 1 - W_ERR;

wire signed [W_ERR-1:0] e_rounded;
generate
    if (SHIFT_E > 0) begin : gen_round
        wire signed [W_MULT:0] e_rnd = e_full + ({{(W_MULT){1'b0}}, 1'b1} <<< (SHIFT_E - 1));
        assign e_rounded = e_rnd[SHIFT_E +: W_ERR];
    end else begin : gen_noround
        assign e_rounded = e_full[W_ERR-1:0];
    end
endgenerate

always @(posedge clk or posedge reset) begin
    if (reset) begin
        e_out       <= 0;
        e_out_valid <= 1'b0;
    end else begin
        if (valid_s1) begin
            e_out <= e_rounded;
        end
        e_out_valid <= valid_s1;
    end
end

endmodule
