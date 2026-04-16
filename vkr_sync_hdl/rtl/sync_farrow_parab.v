`timescale 1ns / 1ps
//==========================================================================
// Проект       : ВКР — символьная синхронизация SDR, Глава 3
// Модуль       : sync_farrow_parab
// Описание     : Кусочно-параболический интерполятор Фарроу, коэффициент α = 1/2
//                Формирует XI = (v2*μ + v1)*μ + v0 по схеме Горнера из
//                четырёх последних входных комплексных отсчётов и дробной
//                задержки μ, поступающей от sync_mod1_nco.
//
// Базовые формулы (Rice, Digital Communications: A Discrete-Time Approach,
//                  раздел 8.4.2; идентично коду parse_deb_data.m советника):
//   v2 = ( x[n]   -   x[n-1] -   x[n-2] +   x[n-3]) / 2
//   v1 = (-x[n]   + 3*x[n-1] -   x[n-2] -   x[n-3]) / 2
//   v0 =   x[n-2]
//   XI = (v2*μ + v1)*μ + v0     (схема Горнера, 2 последовательных умножения)
//
// Конвейер     : 3 такта clk от in_valid до out_valid
//                Ступень 1: регистрируются v0, v1, v2, μ (латентность 1)
//                Ступень 2: t = v2*μ + v1                 (латентность 1)
//                Ступень 3: XI = t*μ + v0 + округление    (латентность 1)
//
// Ресурсы      : 4 × DSP48E1 (две ступени Горнера × два канала I/Q)
//                Умножение на 3 внутри v1 реализовано как shift+add, без DSP
//
// Интерфейс    : синхронный, однотактный. Сигнал in_valid может быть
//                снят и снова поднят; латентность 3 такта сохраняется.
//                μ обновляется извне NCO и используется как есть в момент
//                регистрации v-коэффициентов.
//
// Автор        : Кудимов А.А., ВКР магистра, 2026
//==========================================================================
module sync_farrow_parab #(
    parameter W_IN  = 16,   // разрядность вход/выход I, Q; знаковое Q1.(W_IN-1)
    parameter W_MU  = 12,   // разрядность μ; беззнаковое Q0.W_MU, μ ∈ [0, 1)
    parameter W_OUT = 16    // выходная разрядность интерполянта
)(
    input  wire                          clk,
    input  wire                          reset,     // asynchronous, active-high
    // входной поток
    input  wire                          in_valid,
    input  wire signed [W_IN-1:0]        in_i,
    input  wire signed [W_IN-1:0]        in_q,
    input  wire        [W_MU-1:0]        mu_in,     // μ от sync_mod1_nco
    // выход
    output wire                          out_valid,
    output wire signed [W_OUT-1:0]       xi_i,
    output wire signed [W_OUT-1:0]       xi_q
);

//--------------------------------------------------------------------------
// Расчёт разрядностей промежуточных сигналов
//--------------------------------------------------------------------------
// v-коэффициенты: максимум по модулю |v1| ≈ 3|x|_max; нужно
//   W_V = W_IN + 2 бит знакового (1 бит на сумму 4 членов, 1 на умножение на 3)
localparam W_V = W_IN + 2;

// μ интерпретируется как беззнаковое, но для умножения расширяется на 1 бит
// знакового нуля — W_MUS = W_MU + 1
localparam W_MUS = W_MU + 1;

// Произведение v × μ: разрядность W_V + W_MUS = W_IN + W_MU + 3 бит знакового
localparam W_MUL = W_V + W_MUS;

//--------------------------------------------------------------------------
// Ступень 0 (комбинационная): линия задержки на 3 регистра, x[n] берётся
// напрямую со входа. Это эквивалентно 4-элементной линии задержки, но
// экономит один W_IN-битный регистр на канал.
//--------------------------------------------------------------------------
reg signed [W_IN-1:0] dl_i1, dl_i2, dl_i3;
reg signed [W_IN-1:0] dl_q1, dl_q2, dl_q3;

always @(posedge clk or posedge reset) begin
    if (reset) begin
        dl_i1 <= 0; dl_i2 <= 0; dl_i3 <= 0;
        dl_q1 <= 0; dl_q2 <= 0; dl_q3 <= 0;
    end else if (in_valid) begin
        // Порядок обновления неважен — non-blocking assignments работают параллельно
        dl_i1 <= in_i;   dl_i2 <= dl_i1;   dl_i3 <= dl_i2;
        dl_q1 <= in_q;   dl_q2 <= dl_q1;   dl_q3 <= dl_q2;
    end
end

// Расширение разрядности отсчётов линии задержки до W_V бит (sign-extension)
wire signed [W_V-1:0] x0_i = $signed(in_i);    // x[n]
wire signed [W_V-1:0] x1_i = $signed(dl_i1);   // x[n-1]
wire signed [W_V-1:0] x2_i = $signed(dl_i2);   // x[n-2], базовый отсчёт
wire signed [W_V-1:0] x3_i = $signed(dl_i3);   // x[n-3]
wire signed [W_V-1:0] x0_q = $signed(in_q);
wire signed [W_V-1:0] x1_q = $signed(dl_q1);
wire signed [W_V-1:0] x2_q = $signed(dl_q2);
wire signed [W_V-1:0] x3_q = $signed(dl_q3);

//--------------------------------------------------------------------------
// Ступень 1: вычисление v0, v1, v2 и регистрация
// Умножение на 3 выполнено как (x << 1) + x — без DSP48.
// Деление на 2 выполнено арифметическим сдвигом >>> 1.
//--------------------------------------------------------------------------
wire signed [W_V-1:0] v2_c_i = (x0_i - x1_i - x2_i + x3_i) >>> 1;
wire signed [W_V-1:0] v1_c_i = (-x0_i + (x1_i <<< 1) + x1_i - x2_i - x3_i) >>> 1;
wire signed [W_V-1:0] v0_c_i = x2_i;

wire signed [W_V-1:0] v2_c_q = (x0_q - x1_q - x2_q + x3_q) >>> 1;
wire signed [W_V-1:0] v1_c_q = (-x0_q + (x1_q <<< 1) + x1_q - x2_q - x3_q) >>> 1;
wire signed [W_V-1:0] v0_c_q = x2_q;

reg signed [W_V-1:0]  v2_s1_i, v1_s1_i, v0_s1_i;
reg signed [W_V-1:0]  v2_s1_q, v1_s1_q, v0_s1_q;
reg        [W_MU-1:0] mu_s1;
reg                   valid_s1;

always @(posedge clk or posedge reset) begin
    if (reset) begin
        v2_s1_i <= 0; v1_s1_i <= 0; v0_s1_i <= 0;
        v2_s1_q <= 0; v1_s1_q <= 0; v0_s1_q <= 0;
        mu_s1    <= 0;
        valid_s1 <= 1'b0;
    end else begin
        if (in_valid) begin
            v2_s1_i <= v2_c_i; v1_s1_i <= v1_c_i; v0_s1_i <= v0_c_i;
            v2_s1_q <= v2_c_q; v1_s1_q <= v1_c_q; v0_s1_q <= v0_c_q;
            mu_s1   <= mu_in;
        end
        valid_s1 <= in_valid;
    end
end

//--------------------------------------------------------------------------
// Ступень 2: первая ступень Горнера
//    t = v2 · μ + v1
// μ интерпретируется как Q0.W_MU беззнаковое, расширено до W_MUS = W_MU + 1
// бит знакового с нулевым MSB — это допустимо, так как μ ∈ [0, 1).
//
// v2 · μ имеет масштаб Q(W_V - W_MU - 1).(W_MU + W_V - 1) в битах W_MUL
// v1 выравнивается сдвигом влево на W_MU бит и складывается.
//--------------------------------------------------------------------------
wire signed [W_MUS-1:0] mu_s1_sgn = {1'b0, mu_s1};

// Произведение v2 · μ (знаковое × знаковое с нулевым MSB)
wire signed [W_MUL-1:0] v2_mul_mu_i = v2_s1_i * mu_s1_sgn;
wire signed [W_MUL-1:0] v2_mul_mu_q = v2_s1_q * mu_s1_sgn;

// v1, сдвинутое влево на W_MU для выравнивания по масштабу с произведением
wire signed [W_MUL-1:0] v1_aligned_i = {{(W_MUS){v1_s1_i[W_V-1]}}, v1_s1_i} <<< W_MU;
wire signed [W_MUL-1:0] v1_aligned_q = {{(W_MUS){v1_s1_q[W_V-1]}}, v1_s1_q} <<< W_MU;

wire signed [W_MUL:0] t_full_i = $signed({v2_mul_mu_i[W_MUL-1], v2_mul_mu_i}) +
                                 $signed({v1_aligned_i[W_MUL-1], v1_aligned_i});
wire signed [W_MUL:0] t_full_q = $signed({v2_mul_mu_q[W_MUL-1], v2_mul_mu_q}) +
                                 $signed({v1_aligned_q[W_MUL-1], v1_aligned_q});

// Регистр промежуточного результата; для первой итерации храним полную точность
reg signed [W_MUL:0]   t_s2_i, t_s2_q;
reg signed [W_V-1:0]   v0_s2_i, v0_s2_q;
reg        [W_MU-1:0]  mu_s2;
reg                    valid_s2;

always @(posedge clk or posedge reset) begin
    if (reset) begin
        t_s2_i <= 0; t_s2_q <= 0;
        v0_s2_i <= 0; v0_s2_q <= 0;
        mu_s2   <= 0;
        valid_s2 <= 1'b0;
    end else begin
        if (valid_s1) begin
            t_s2_i <= t_full_i;
            t_s2_q <= t_full_q;
            v0_s2_i <= v0_s1_i;
            v0_s2_q <= v0_s1_q;
            mu_s2   <= mu_s1;
        end
        valid_s2 <= valid_s1;
    end
end

//--------------------------------------------------------------------------
// Ступень 3: вторая ступень Горнера
//    XI_scaled = t · μ + v0_aligned
// Масштаб t — Q(W_V - W_MU).(2·W_MU); после умножения на μ — Q.(W_MU)
// Для выхода XI в формате Q1.(W_OUT-1) округляем и обрезаем.
//--------------------------------------------------------------------------
wire signed [W_MUS-1:0] mu_s2_sgn = {1'b0, mu_s2};

// Произведение t · μ; t имеет W_MUL+1 бит, μ — W_MUS бит
localparam W_MUL2 = (W_MUL + 1) + W_MUS;
wire signed [W_MUL2-1:0] t_mul_mu_i = t_s2_i * mu_s2_sgn;
wire signed [W_MUL2-1:0] t_mul_mu_q = t_s2_q * mu_s2_sgn;

// v0 выравнивается сдвигом влево на 2·W_MU (он был Q(W_V-1).0, нужно .2W_MU)
wire signed [W_MUL2-1:0] v0_aligned_i = {{(W_MUS + W_MU){v0_s2_i[W_V-1]}}, v0_s2_i} <<< (2*W_MU);
wire signed [W_MUL2-1:0] v0_aligned_q = {{(W_MUS + W_MU){v0_s2_q[W_V-1]}}, v0_s2_q} <<< (2*W_MU);

// Полный результат XI в формате Q.(2·W_MU)
wire signed [W_MUL2:0] xi_scaled_i = $signed({t_mul_mu_i[W_MUL2-1], t_mul_mu_i}) +
                                     $signed({v0_aligned_i[W_MUL2-1], v0_aligned_i});
wire signed [W_MUL2:0] xi_scaled_q = $signed({t_mul_mu_q[W_MUL2-1], t_mul_mu_q}) +
                                     $signed({v0_aligned_q[W_MUL2-1], v0_aligned_q});

// Округление half-up и усечение до W_OUT бит знакового
// Q-формат анализ:
//   v   : Q3.(W_IN-1)    — W_V бит знакового (3 целых с учётом *3 и суммы 4 элементов)
//   μ   : Q0.W_MU        — беззнаковое
//   v·μ : Q3.(W_IN-1+W_MU)
//   t·μ : Q3.(W_IN-1+2·W_MU) = xi_scaled
//   Для выхода Q1.(W_OUT-1) при W_OUT = W_IN нужен сдвиг на 2·W_MU бит
//   (старшие биты сверх W_OUT — это «запас» Q3 → Q1, проверяется на overflow)
localparam SHIFT_OUT = 2*W_MU;

// Округляющая константа: 1 << (SHIFT_OUT - 1)
wire signed [W_MUL2:0] round_const = (SHIFT_OUT > 0) ? ({{(W_MUL2){1'b0}}, 1'b1} <<< (SHIFT_OUT - 1)) : 0;

wire signed [W_MUL2:0] xi_rounded_i = xi_scaled_i + round_const;
wire signed [W_MUL2:0] xi_rounded_q = xi_scaled_q + round_const;

// Насыщающее усечение до W_OUT бит
// После сдвига вправо на SHIFT_OUT бит старшие биты должны быть равны знаку,
// иначе имеет место переполнение (и нужно насыщение до ±max)
wire signed [W_MUL2-SHIFT_OUT:0] xi_shifted_i = xi_rounded_i >>> SHIFT_OUT;
wire signed [W_MUL2-SHIFT_OUT:0] xi_shifted_q = xi_rounded_q >>> SHIFT_OUT;

// Максимальные значения для насыщения Q1.(W_OUT-1)
localparam signed [W_OUT-1:0] SAT_POS = {1'b0, {(W_OUT-1){1'b1}}};  // +2^(W_OUT-1)-1
localparam signed [W_OUT-1:0] SAT_NEG = {1'b1, {(W_OUT-1){1'b0}}};  // -2^(W_OUT-1)

reg signed [W_OUT-1:0] xi_s3_i, xi_s3_q;
reg                    valid_s3;

// Проверка переполнения: старшие биты должны совпадать со знаком
wire overflow_i = ~((&xi_shifted_i[W_MUL2-SHIFT_OUT : W_OUT-1]) |
                    (~(|xi_shifted_i[W_MUL2-SHIFT_OUT : W_OUT-1])));
wire overflow_q = ~((&xi_shifted_q[W_MUL2-SHIFT_OUT : W_OUT-1]) |
                    (~(|xi_shifted_q[W_MUL2-SHIFT_OUT : W_OUT-1])));

always @(posedge clk or posedge reset) begin
    if (reset) begin
        xi_s3_i <= 0; xi_s3_q <= 0;
        valid_s3 <= 1'b0;
    end else begin
        if (valid_s2) begin
            // Насыщение при переполнении
            if (overflow_i)
                xi_s3_i <= xi_shifted_i[W_MUL2-SHIFT_OUT] ? SAT_NEG : SAT_POS;
            else
                xi_s3_i <= xi_shifted_i[W_OUT-1:0];

            if (overflow_q)
                xi_s3_q <= xi_shifted_q[W_MUL2-SHIFT_OUT] ? SAT_NEG : SAT_POS;
            else
                xi_s3_q <= xi_shifted_q[W_OUT-1:0];
        end
        valid_s3 <= valid_s2;
    end
end

assign xi_i = xi_s3_i;
assign xi_q = xi_s3_q;
assign out_valid = valid_s3;

endmodule
//==========================================================================
// end of module sync_farrow_parab
//==========================================================================
