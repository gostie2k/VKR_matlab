`timescale 1ns / 1ps
//==========================================================================
// Тестбенч     : tb_sync_mod1_nco
// Описание     : Верификация модуля sync_mod1_nco
//                Подаёт постоянный W = W_nom = 0.5 (0x8000 для W_W=16),
//                проверяет, что strobe срабатывает каждые 2 такта (sps_rx=2).
//                Затем меняет W и проверяет изменение частоты стробирования.
//==========================================================================
module tb_sync_mod1_nco;

localparam W_CNT = 16;
localparam W_MU  = 12;
localparam W_W   = 16;
localparam CLK_PERIOD = 16;   // нс

reg                  clk;
reg                  reset;
reg                  in_valid;
reg  [W_W-1:0]       w_step;
wire                 strobe;
wire [W_MU-1:0]      mu_out;

sync_mod1_nco #(
    .W_CNT (W_CNT),
    .W_MU  (W_MU),
    .W_W   (W_W)
) dut (
    .clk      (clk),
    .reset    (reset),
    .in_valid (in_valid),
    .w_step   (w_step),
    .strobe   (strobe),
    .mu_out   (mu_out)
);

initial clk = 1'b0;
always #(CLK_PERIOD/2) clk = ~clk;

integer fout;
integer n;
integer strobe_count;
integer total_clocks;

initial begin
    $dumpfile("tb_sync_mod1_nco.vcd");
    $dumpvars(0, tb_sync_mod1_nco);

    fout = $fopen("nco_out.txt", "w");

    reset    = 1'b1;
    in_valid = 1'b0;
    w_step   = 16'h8000;   // W_nom = 0.5 → sps_rx = 2

    @(posedge clk); @(posedge clk); @(posedge clk);
    @(negedge clk) reset = 1'b0;
    @(posedge clk);

    // ============ Тест 1: W = 0.5 (номинал), 100 тактов ============
    $display("[Test 1] W = 0.5 (0x8000), expect strobe every 2 clocks");
    strobe_count = 0;
    total_clocks = 100;
    for (n = 0; n < total_clocks; n = n + 1) begin
        @(negedge clk);
        in_valid = 1'b1;
        @(posedge clk);
        #1;
        $fwrite(fout, "%0d %0d %0d %0d\n", n, strobe, mu_out, w_step);
        if (strobe) strobe_count = strobe_count + 1;
    end
    @(negedge clk) in_valid = 1'b0;
    $display("[Test 1] Strobes: %0d in %0d clocks (expected ~%0d)",
             strobe_count, total_clocks, total_clocks/2);

    repeat(5) @(posedge clk);

    // ============ Тест 2: W = 0.4 (< номинала → sps > 2) ============
    $display("[Test 2] W = 0.4 (0x6666), expect strobe every ~2.5 clocks");
    w_step = 16'h6666;   // ≈ 0.4
    strobe_count = 0;
    total_clocks = 100;
    for (n = 0; n < total_clocks; n = n + 1) begin
        @(negedge clk);
        in_valid = 1'b1;
        @(posedge clk);
        #1;
        $fwrite(fout, "%0d %0d %0d %0d\n", n, strobe, mu_out, w_step);
        if (strobe) strobe_count = strobe_count + 1;
    end
    @(negedge clk) in_valid = 1'b0;
    $display("[Test 2] Strobes: %0d in %0d clocks (expected ~%0d)",
             strobe_count, total_clocks, 100*4/10);  // 100 * 0.4 = 40

    repeat(5) @(posedge clk);

    // ============ Тест 3: W = 0.6 (> номинала → sps < 2) ============
    $display("[Test 3] W = 0.6 (0x999A), expect strobe every ~1.67 clocks");
    w_step = 16'h999A;   // ≈ 0.6
    strobe_count = 0;
    total_clocks = 100;
    for (n = 0; n < total_clocks; n = n + 1) begin
        @(negedge clk);
        in_valid = 1'b1;
        @(posedge clk);
        #1;
        $fwrite(fout, "%0d %0d %0d %0d\n", n, strobe, mu_out, w_step);
        if (strobe) strobe_count = strobe_count + 1;
    end
    @(negedge clk) in_valid = 1'b0;
    $display("[Test 3] Strobes: %0d in %0d clocks (expected ~%0d)",
             strobe_count, total_clocks, 100*6/10);  // 100 * 0.6 = 60

    $fclose(fout);
    $display("[tb_sync_mod1_nco] Done");
    $finish;
end

endmodule
