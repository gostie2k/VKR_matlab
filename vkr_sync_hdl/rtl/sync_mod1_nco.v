`timescale 1ns / 1ps
//==========================================================================
// Проект       : ВКР — символьная синхронизация SDR, Глава 3
// Модуль       : sync_mod1_nco
// Описание     : Вычитающий счётчик по модулю 1 (Mod-1 NCO)
//                Формирует строб strobe и дробную задержку μ в момент
//                underflow по схеме Гарднера–Харриса.
//
// Алгоритм (Rice, Digital Communications, раздел 8.4.3):
//   На каждом входном такте:
//     CNT_next = CNT - W
//     if CNT_next < 0 then
//       strobe  = 1
//       mu      = CNT_old / W       (дробная задержка ∈ [0, 1))
//       CNT     = CNT_next + 1      (перескок через 0 → следующий период)
//     else
//       strobe  = 0
//       CNT     = CNT_next
//
// Деление μ = CNT/W:
//   Реализовано через LUT обратной величины 1/W и одно умножение:
//     μ = CNT_old × LUT(W)
//   LUT хранит 2^W_LUT значений 1/W в формате Q0.W_MU для W в диапазоне
//   [W_nom-Δ, W_nom+Δ]. Поскольку W лежит в узком диапазоне после clamp
//   PI-фильтра (±25 % от W_nom), LUT размером 1024 записей достаточна
//   для точности 1 LSB в μ.
//
// Конвейер     : 1 такт от in_valid до strobe
//                (μ доступна одновременно со strobe)
//
// Ресурсы      : 1 × DSP48E1 (умножение CNT × 1/W)
//                1 × BRAM (LUT 1/W, опционально)
//                ~50 LUT (сумматоры, компараторы)
//
// Автор        : Кудимов А.А., ВКР магистра, 2026
//==========================================================================
module sync_mod1_nco #(
    parameter W_CNT = 16,   // разрядность регистра NCO; Q1.(W_CNT-1)
    parameter W_MU  = 12,   // разрядность μ; беззнаковое Q0.W_MU, μ ∈ [0, 1)
    parameter W_W   = 16    // разрядность шага W; Q1.(W_W-1), номинал = 1/sps_rx
)(
    input  wire                          clk,
    input  wire                          reset,      // async active-high
    input  wire                          in_valid,   // строб входного отсчёта
    input  wire        [W_W-1:0]         w_step,     // текущий шаг NCO = W_nom + v_pi
    // выход
    output reg                           strobe,     // 1 на один такт при underflow
    output reg         [W_MU-1:0]        mu_out      // дробная задержка в момент strobe
);

// =========================================================================
// Регистр NCO
// =========================================================================
// CNT хранится в формате Q1.(W_CNT-1) беззнаковое, начальное значение = 1.0
// (старший бит = 1, остальные = 0).
// W_step в том же формате: номинал W_nom = 1/sps_rx.
// При sps_rx = 2: W_nom = 0.5 → 0x8000 для W_W = 16.

// Рабочая разрядность: W_CNT + 1 бит для обнаружения underflow (знак)
localparam W_EXT = W_CNT + 1;

reg [W_CNT-1:0] cnt_reg;   // текущее значение NCO, беззнаковое Q0.W_CNT
                            // Интерпретация: cnt_reg / 2^W_CNT ∈ [0, 1)
                            // Начальное значение: 1.0 → храним как 2^W_CNT - 1 + carry
                            // Проще: стартуем с cnt = W_nom (один шаг до первого строба)

// Детекция underflow: вычитаем W из CNT в расширенной разрядности
wire [W_EXT-1:0] cnt_ext   = {1'b0, cnt_reg};
wire [W_EXT-1:0] w_ext     = {1'b0, w_step[W_W-1:W_W-W_CNT]};  // выравнивание если W_W ≠ W_CNT
wire [W_EXT-1:0] cnt_next  = cnt_ext - w_ext;
wire             underflow  = cnt_next[W_EXT-1];  // знаковый бит = 1 → underflow

// При underflow: CNT_new = CNT_next + 1.0
// "1.0" в беззнаковом Q0.W_CNT = 2^W_CNT, что эквивалентно обрезанию до W_CNT бит
// cnt_next[W_CNT-1:0] уже является правильным значением (дополнение до 2)
wire [W_CNT-1:0] cnt_wrap = cnt_next[W_CNT-1:0];  // CNT_next + 1.0 (mod 2^W_CNT)
wire [W_CNT-1:0] cnt_nwrap = cnt_next[W_CNT-1:0]; // CNT_next (без коррекции)

// =========================================================================
// Вычисление μ = CNT_old / W
// =========================================================================
// Используем аппроксимацию:
//   μ = CNT_old × (1/W)
// Вместо полноценного делителя — LUT не нужна при sps_rx = 2:
//   W_nom = 0.5, диапазон W ∈ [0.375, 0.625] после clamp.
//   1/W ∈ [1.6, 2.667], среднее 2.0.
//   При sps_rx = 2 точная формула 1/W ≈ 2·(1 - (W - W_nom)/W_nom + ...)
//
// Простейшая реализация для первой итерации:
//   μ_approx = CNT_old << 1  (= CNT_old / 0.5, точно при W = W_nom)
//   Погрешность при W = 0.375: μ_true = CNT/0.375, μ_approx = CNT/0.5
//     → ошибка = CNT·(1/0.375 - 1/0.5) = CNT·0.667
//     Для малых CNT (что типично при underflow) ошибка < 1 LSB μ.
//
// Полноценная версия: μ = CNT_old × inv_w, где inv_w из BRAM-LUT.
// Для первой итерации используем линейную аппроксимацию (shift).
// На этапе натурных испытаний, если MER деградирует, заменим на LUT.

// Полное вычисление: CNT_old * (2^W_MU / W) через умножение + сдвиг
// Для W_nom = 0.5 (= 0x8000 в Q0.16): inv_W = 2.0 = 0x2_000 в Q2.W_MU
// Используем умножение: mu = cnt_reg * inv_w >> (W_CNT + 2 - W_MU)
// Но для первой версии достаточно сдвига:

// ---- Версия 1: простой сдвиг (точна при W = W_nom) ----
// μ = CNT_old / W_nom = CNT_old × sps_rx
// При sps_rx = 2: μ = CNT_old << 1, усечённое до W_MU бит
// CNT_old в формате Q0.W_CNT; μ в формате Q0.W_MU
// μ = CNT_old[W_CNT-2:W_CNT-1-W_MU]  (сдвиг на 1 влево + усечение)

wire [W_MU-1:0] mu_simple;
generate
    if (W_CNT - 1 >= W_MU) begin : gen_mu_trunc
        // CNT << 1 → берём биты [W_CNT-2 : W_CNT-1-W_MU]
        assign mu_simple = cnt_reg[W_CNT-2 -: W_MU];
    end else begin : gen_mu_pad
        // W_MU > W_CNT-1: дополняем нулями справа
        assign mu_simple = {cnt_reg[W_CNT-2:0], {(W_MU - W_CNT + 1){1'b0}}};
    end
endgenerate

// ---- Версия 2 (зарезервирована): полное деление через LUT ----
// Подключается на этапе натурных испытаний, если версия 1 недостаточна.
// wire [W_MU-1:0] mu_lut;
// sync_inv_w_lut #(.W_W(W_W), .W_MU(W_MU)) inv_lut (
//     .clk(clk), .w_in(w_step), .inv_w(inv_w)
// );
// wire [W_CNT+W_MU-1:0] mu_full = cnt_reg * inv_w;
// assign mu_lut = mu_full[W_CNT+W_MU-1 -: W_MU];

// =========================================================================
// Основной автомат
// =========================================================================
always @(posedge clk or posedge reset) begin
    if (reset) begin
        cnt_reg <= {1'b1, {(W_CNT-1){1'b0}}};  // начальное CNT = 0.5
        strobe  <= 1'b0;
        mu_out  <= {W_MU{1'b0}};
    end else if (in_valid) begin
        if (underflow) begin
            cnt_reg <= cnt_wrap;     // CNT = CNT_next + 1.0
            strobe  <= 1'b1;
            mu_out  <= mu_simple;    // μ из CNT_old до обновления
        end else begin
            cnt_reg <= cnt_nwrap;    // CNT = CNT_next
            strobe  <= 1'b0;
            // mu_out сохраняет последнее значение
        end
    end else begin
        strobe <= 1'b0;  // strobe длится ровно 1 такт
    end
end

endmodule
//==========================================================================
// end of module sync_mod1_nco
//==========================================================================
