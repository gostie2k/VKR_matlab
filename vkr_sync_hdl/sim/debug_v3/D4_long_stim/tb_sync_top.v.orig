`timescale 1ns / 1ps
module tb_sync_top;

localparam W_DATA   = 16;
localparam W_MU     = 12;
localparam W_COEF   = 16;
localparam W_NCO    = 16;
localparam CLK_PER  = 16;
localparam MAX_SAMP = 8000;
localparam N_STIM      = 3960;
localparam [15:0] K1_VAL    = 16'hFD8A;
localparam [15:0] K2_VAL    = 16'hFFEF;
localparam [15:0] W_NOM_VAL = 16'h8000;
localparam [15:0] CLAMP_VAL = 16'h4000;

reg clk; initial clk=0; always #(CLK_PER/2) clk=~clk;
reg reset;
reg [2*W_DATA-1:0] s_axis_tdata;
reg s_axis_tvalid;
wire s_axis_tready;
wire [2*W_DATA-1:0] m_axis_tdata;
wire m_axis_tvalid;
wire [W_NCO-1:0] debug_w;
wire [W_MU-1:0] debug_mu;
reg ctrl_soft_reset, ctrl_enable, ctrl_agc_bypass;
reg signed [W_COEF-1:0] reg_k1, reg_k2;
reg [W_NCO-1:0] reg_w_nom;
reg [W_DATA-1:0] reg_clamp;
reg [32:0] reg_agc_target;

sync_top #(.W_DATA(W_DATA),.W_MU(W_MU),.W_COEF(W_COEF),.W_NCO(W_NCO)) dut (
    .clk(clk),.reset(reset),
    .s_axis_tdata(s_axis_tdata),.s_axis_tvalid(s_axis_tvalid),.s_axis_tready(s_axis_tready),
    .m_axis_tdata(m_axis_tdata),.m_axis_tvalid(m_axis_tvalid),
    .ctrl_soft_reset(ctrl_soft_reset),.ctrl_enable(ctrl_enable),.ctrl_agc_bypass(ctrl_agc_bypass),
    .reg_k1(reg_k1),.reg_k2(reg_k2),.reg_w_nom(reg_w_nom),.reg_clamp(reg_clamp),
    .reg_agc_target(reg_agc_target),.debug_w(debug_w),.debug_mu(debug_mu));

reg signed [W_DATA-1:0] stim_i [0:MAX_SAMP-1];
reg signed [W_DATA-1:0] stim_q [0:MAX_SAMP-1];
integer i, fout_sym, fout_int, n_sym_out, clk_count;

initial begin
    for(i=0;i<MAX_SAMP;i=i+1) begin stim_i[i]=0; stim_q[i]=0; end
    $readmemh("sync_stim_i.hex", stim_i);
    $readmemh("sync_stim_q.hex", stim_q);
    reset=1; s_axis_tdata=0; s_axis_tvalid=0;
    ctrl_soft_reset=0; ctrl_enable=0; ctrl_agc_bypass=1;
    reg_k1=K1_VAL; reg_k2=K2_VAL; reg_w_nom=W_NOM_VAL;
    reg_clamp=CLAMP_VAL; reg_agc_target={1'b0,1'b1,{31{1'b0}}};
    fout_sym=$fopen("sync_out_symbols.txt","w");
    fout_int=$fopen("sync_internal.txt","w");
    repeat(5) @(posedge clk); @(negedge clk) reset=0;
    repeat(3) @(posedge clk); @(negedge clk) ctrl_enable=1; @(posedge clk);
    $display("[tb] Starting: %0d samples", N_STIM);
    n_sym_out=0; clk_count=0;
    for(i=0;i<N_STIM;i=i+1) begin
        @(negedge clk); s_axis_tdata={stim_i[i],stim_q[i]}; s_axis_tvalid=1;
    end
    @(negedge clk); s_axis_tvalid=0; s_axis_tdata=0;
    repeat(20) @(posedge clk);
    $fclose(fout_sym); $fclose(fout_int);
    $display("[tb] Done. Symbols: %0d, Clocks: %0d", n_sym_out, clk_count);
    $finish;
end

always @(posedge clk) if(!reset && m_axis_tvalid) begin
    $fwrite(fout_sym,"%0d %0d\n",
        $signed(m_axis_tdata[2*W_DATA-1:W_DATA]),
        $signed(m_axis_tdata[W_DATA-1:0]));
    n_sym_out=n_sym_out+1;
end

always @(posedge clk) if(!reset && ctrl_enable) begin
    clk_count=clk_count+1;
    $fwrite(fout_int,"%0d %0d %0d %0d %0d %0d %0d %0d %0d\n",
        clk_count,
        dut.nco_strobe,
        dut.strobe_d2,
        dut.u_nco.cnt_reg,
        dut.u_nco.mu_out,
        debug_w,
        $signed(dut.u_ted.e_out),
        $signed(dut.v_pi_wire),
        $signed(dut.u_pi.vi_reg));
end
endmodule
