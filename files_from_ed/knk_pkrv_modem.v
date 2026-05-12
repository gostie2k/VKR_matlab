`timescale 1ns / 1ps
//`define SIMULATION 

//start_module------------------------------------------------------------
// Module Name     :  knk_en
// Date            :  14.05.13 
// Description     :  Create enable impulse.
module knk_en (clk,pre,step,imp);
    input clk,pre,step;
    output imp;
    reg dff0,dff1;
  always@(posedge clk)
    begin
        dff0<=(pre)?1'b1:step;
        dff1<=(pre)?1'b1:dff0;  
    end
  wire imp = dff0&(~dff1);
endmodule
//end module----------


//start_module------------------------------------------------------------
// Module Name     :  knk_resync2r
// Date            :  03.02.22 
// Description     :  Greate resync module.
module knk_resync2r(clk,in,out);
input clk,in;
output out;
reg [1:0] dt;
always @(posedge clk) begin
	dt[0] <= in;
	dt[1] <= dt[0];
end
wire out=dt[1]; 
endmodule
//end module----------


//start_module------------------------------------------------------------
// Module Name     :  knk_ad9361_rx_sample
// Date            :  21.05.25 
// Description     :  AD9361 rx sample (12 MHz), clk = 120MHz 
module knk_ad9361_rx_sample(clk,res, 
ad9361_rx_clk, res_ad9361_rx_clk, ad9361_rx_frame, ad9361_rx_data,
si,sq,sena);
    
input clk,res;
input ad9361_rx_clk, res_ad9361_rx_clk, ad9361_rx_frame;
input [11:0] ad9361_rx_data;
output [11:0] si,sq;
output sena;
      
reg [11:0] di,dq;
 always@(negedge ad9361_rx_clk or posedge res_ad9361_rx_clk)
 begin
  if (res_ad9361_rx_clk) begin di<=0; dq<=0; end
  else if (ad9361_rx_frame) di<=ad9361_rx_data;
  else  dq<=ad9361_rx_data;
end
   
reg [23:0] diq; 
reg val;
always@(negedge ad9361_rx_clk or posedge res_ad9361_rx_clk)
 begin if (res_ad9361_rx_clk) begin diq<=0; val<=0; end
 else if (ad9361_rx_frame) begin  diq<={di,dq}; val<=1; end 
 else val<=0;
end

wire val_clk;
knk_resync2r(.clk(clk),.in(val),.out(val_clk));
wire enad; 
knk_en ena_ld(.clk(clk),.pre(res),.step(val_clk),.imp(enad));


reg [23:0] s;
always@(posedge clk or posedge res)
 begin if (res)  s<=0;  
 else  if (enad)  s<=diq; 
end

reg [3:0] cnt;
always@(posedge clk or posedge res)
 begin if (res) cnt<=0;
 else cnt<=(cnt==9)?0:cnt+1;
end 

reg sena;
reg [11:0] si,sq;
always@(posedge clk or posedge res)
 begin if (res) begin  sena<=0; si<=0; sq<=0;  end
 else if (cnt==0) begin {si,sq}<=s; sena<=1; end
 else sena<=0;
end

//reg sena;
//reg [11:0] si,sq;
//always@(posedge clk or posedge res)
// begin if (res) begin  sena<=0; si<=0; sq<=0;  end
// else if (enad) begin {si,sq}<=diq; sena<=1; end
// else sena<=0;
//end

endmodule
//end module----------


//start_module------------------------------------------------------------
// Module Name     :  knk_quart_freq_shift
// Date            :  17.01.25 
// Description     :  
module knk_quart_freq_shift(clk,reset,ena,sw_on,dr,di,qr,qi,qena);
parameter w=12;
input clk,reset,ena;
input sw_on;
input  [w-1:0] dr, di;
output [w-1:0] qr, qi;
output qena;

reg [1:0] cnt;
always@(posedge clk or posedge reset) begin
if (reset) cnt<=0;
else if (ena) cnt<=cnt+1;
end

reg [w-1:0] qr,qi;
always@(posedge clk or posedge reset) begin
if (reset) begin qr<=0; qi<=0; end
else if (ena) begin
if (~sw_on) {qr,qi} <= {dr,di};
else if (cnt==0) begin qr<= dr;  qi<= di;  end 
else if (cnt==1) begin qr<= di;  qi<=-dr;  end
else if (cnt==2) begin qr<=-dr;  qi<=-di;  end
else if (cnt==3) begin qr<=-di;  qi<= dr;  end 
end end

reg qena;
always@(posedge clk or posedge reset) begin
if (reset) qena<=0;
else qena<=ena;
end 

endmodule
//end module----------

//start_module------------------------------------------------------------
// Module Name     :  knk_rcos_filt
// Date            :  17.01.25 
// Description     :  clk=120M, symbol speed = 3 MBod, sampling 12M 
// Matlab          :  ( rcosdesign(.2, 10, 4,'sqrt'); ) -> Matlab/filt_rcos.m
module knk_rcos_filt(clk,reset,ena,sw_on,dr,di,qr,qi,qena);
parameter vendor= "altera";
parameter w_in=12;
parameter w_out=16;
input clk,reset,ena;
input sw_on;
input  [w_in-1:0] dr, di;
output [w_out-1:0] qr, qi;
output qena;

wire [15:0] coef [20:0];

//assign coef[0] =16'hff7c;
//assign coef[1] =16'hffc0;
//assign coef[2] =16'h005f;
//assign coef[3] =16'h00e7;
//assign coef[4] =16'h00d4;
//assign coef[5] =16'h0000;
//assign coef[6] =16'hfed9;
//assign coef[7] =16'hfe3c;
//assign coef[8] =16'hfedb;
//assign coef[9] =16'h00a5;
//assign coef[10]=16'h0293;
//assign coef[11]=16'h0327;
//assign coef[12]=16'h016a;
//assign coef[13]=16'hfdd0;
//assign coef[14]=16'hfa65;
//assign coef[15]=16'hf9ef;
//assign coef[16]=16'hfe68;
//assign coef[17]=16'h07a7;
//assign coef[18]=16'h1307;
//assign coef[19]=16'h1c62;
//assign coef[20]=16'h2000;

assign coef[0] =16'h0002;
assign coef[1] =16'hffe1;
assign coef[2] =16'hfff1;
assign coef[3] =16'h0024;
assign coef[4] =16'h002a;
assign coef[5] =16'hffed;
assign coef[6] =16'hffc1;
assign coef[7] =16'hfff9;
assign coef[8] =16'h0051;
assign coef[9] =16'h0030;
assign coef[10]=16'hff99;
assign coef[11]=16'hff63;
assign coef[12]=16'h001c;
assign coef[13]=16'h00d3;
assign coef[14]=16'hffe3;
assign coef[15]=16'hfd79;
assign coef[16]=16'hfcee;
assign coef[17]=16'h0263;
assign coef[18]=16'h0e22;
assign coef[19]=16'h1a9d;
assign coef[20]=16'h2000;

reg [23:0] bufd [40:0];

always@(posedge clk or posedge reset) begin
 if (reset) bufd[0] <= 0;
 else if (ena) bufd[0] <= {dr,di};
end

genvar count;
generate for (count=1;count<=40;count=count+1) begin:gen_buf  
 always@(posedge clk or posedge reset) begin
  if (reset) bufd[count] <= 0;
  else if (ena) bufd[count] <= bufd[count-1];
 end
end endgenerate

reg [3:0] cnt_avt;
wire [w_in:0]  sum_r1, sum_r2, sum_i1, sum_i2;
wire [15:0]  coef1, coef2;
generate for (count=0;count<10;count=count+1) begin:gen_sum  
 assign sum_r1=(cnt_avt==count)? {bufd[2*count][23]  ,bufd[2*count][23:12]}   +  {bufd[40-2*count][23]  ,bufd[40-2*count][23:12]}   : {(w_in+1){1'bz}};
 assign sum_r2=(cnt_avt==count)? {bufd[2*count+1][23],bufd[2*count+1][23:12]} +  {bufd[40-2*count-1][23],bufd[40-2*count-1][23:12]} : {(w_in+1){1'bz}};
 assign sum_i1=(cnt_avt==count)? {bufd[2*count][11]  ,bufd[2*count][11:0]}   +  {bufd[40-2*count][11]  ,bufd[40-2*count][11:0]}   : {(w_in+1){1'bz}};
 assign sum_i2=(cnt_avt==count)? {bufd[2*count+1][11],bufd[2*count+1][11:0]} +  {bufd[40-2*count-1][11],bufd[40-2*count-1][11:0]} : {(w_in+1){1'bz}};
 assign coef1= (cnt_avt==count)? coef[2*count]   : {(16){1'bz}};
 assign coef2= (cnt_avt==count)? coef[2*count+1] : {(16){1'bz}};
end endgenerate

reg [w_in:0]  reg_sum_r1, reg_sum_r2, reg_sum_i1, reg_sum_i2;
reg [15:0] reg_coef1, reg_coef2;
always@(posedge clk or posedge reset) begin
 if (reset) begin reg_sum_r1<=0; reg_sum_r2<=0; reg_sum_i1<=0; reg_sum_i2<=0; reg_coef1<=0; reg_coef2<=0; end
 else begin 
     reg_sum_r1<=sum_r1; 
	 reg_sum_r2<=sum_r2; 
	 reg_sum_i1<=sum_i1;
	 reg_sum_i2<=sum_i2;
	 reg_coef1<=coef1;
	 reg_coef2<=coef2;
 end end

wire [28:0] mult_r1_q, mult_r2_q, mult_i1_q, mult_i2_q;

generate if (vendor=="altera") begin:gen_mult_altera
 lpm_mult #(.lpm_widtha(16),.lpm_widthb(13),.lpm_widthp(29),.lpm_representation("SIGNED")) mult_r1(.dataa(reg_coef1),.datab(reg_sum_r1),.result(mult_r1_q));	
 lpm_mult #(.lpm_widtha(16),.lpm_widthb(13),.lpm_widthp(29),.lpm_representation("SIGNED")) mult_r2(.dataa(reg_coef2),.datab(reg_sum_r2),.result(mult_r2_q));	
 lpm_mult #(.lpm_widtha(16),.lpm_widthb(13),.lpm_widthp(29),.lpm_representation("SIGNED")) mult_i1(.dataa(reg_coef1),.datab(reg_sum_i1),.result(mult_i1_q));	
 lpm_mult #(.lpm_widtha(16),.lpm_widthb(13),.lpm_widthp(29),.lpm_representation("SIGNED")) mult_i2(.dataa(reg_coef2),.datab(reg_sum_i2),.result(mult_i2_q));	
end endgenerate 
generate if (vendor=="xilinx") begin:gen_mult_xilinx 
 mult_gen_0 mult_r1(.A(reg_coef1), .B(reg_sum_r1), .P(mult_r1_q));
 mult_gen_0 mult_r2(.A(reg_coef2), .B(reg_sum_r2), .P(mult_r2_q));
 mult_gen_0 mult_i1(.A(reg_coef1), .B(reg_sum_i1), .P(mult_i1_q));
 mult_gen_0 mult_i2(.A(reg_coef2), .B(reg_sum_i2), .P(mult_i2_q));
end endgenerate 


always@(posedge clk or posedge reset) begin
 if (reset) cnt_avt <= 10;
 else if (ena) cnt_avt <= 0;
 else if (cnt_avt<10) cnt_avt <=cnt_avt +1;
end

reg [16:0] reg_mult_r1_q, reg_mult_r2_q, reg_mult_i1_q, reg_mult_i2_q;
always@(posedge clk or posedge reset) begin
 if (reset) begin reg_mult_r1_q<=0; reg_mult_r2_q<=0; reg_mult_i1_q<=0; reg_mult_i2_q<=0; end
 else begin
  reg_mult_r1_q <= mult_r1_q[27:11];
  reg_mult_r2_q <= mult_r2_q[27:11];
  reg_mult_i1_q <= mult_i1_q[27:11];
  reg_mult_i2_q <= mult_i2_q[27:11]; 
 end end


reg [3:0] cnt_out;
always@(posedge clk or posedge reset) begin
 if (reset) cnt_out<=10;
 else if (cnt_avt == 1) cnt_out<=0;
 else if (cnt_out<10) cnt_out<=cnt_out+1;
end

reg [16:0] accum_r, accum_i;
always@(posedge clk or posedge reset) begin
 if (reset) accum_r<=0;
 else if (cnt_out==0)  accum_r<= reg_mult_r1_q  + reg_mult_r2_q + { {(3){bufd[20][23]}},bufd[20][23:12],2'd0};
 else if (cnt_out<10)  accum_r<= reg_mult_r1_q  + reg_mult_r2_q + accum_r;
end

always@(posedge clk or posedge reset) begin
 if (reset) accum_i<=0;
 else if (cnt_out==0)  accum_i<= reg_mult_i1_q  + reg_mult_i2_q + { {(3){bufd[20][11]}},bufd[20][11:0],2'd0};
 else if (cnt_out<10)  accum_i<= reg_mult_i1_q  + reg_mult_i2_q + accum_i;
end

reg lock_out;
always@(posedge clk or posedge reset) begin
 if (reset) lock_out<=0;
 else lock_out<=(cnt_out == 9);
end

reg [w_out-1:0] qr,qi;
reg qena;
always@(posedge clk or posedge reset) begin
 if (reset) begin qena<=0; qr<=0; qi<=0; end
 else if (~sw_on) {qena,qr,qi} <= {ena,dr,4'd0,di,4'd0};
 else if (lock_out) begin qena<=1; qr<=accum_r[16:1]+{15'd0,accum_r[0]}; qi<=accum_i[16:1]+{15'd0,accum_i[0]}; end
 else qena<=0;
end 

endmodule
//end module----------




//start_module------------------------------------------------------------
// Module Name     :  knk_rcos_filt_stimulus
// Date            :  20.01.25 
// Description     :  
// Matlab          :  
module knk_rcos_filt_stimulus();

reg clk,reset;  
initial clk = 1'b1;
initial begin
reset=1;
#100 reset=0; 
end

always #8 clk = ~clk; 

reg [3:0] cnt;
always@(posedge clk or posedge reset) begin
 if (reset) cnt<=0;
 else if(cnt==9) cnt<=0;
 else cnt<=cnt+1;
end 

reg [11:0] dr,di;
reg ena;
always@(posedge clk or posedge reset) begin
 if (reset) begin {dr,di}<=0; ena<=0; end
 else if (cnt==9) begin {dr,di}<={12'h7ff,12'h7ff}; ena<=1; end
 else ena<=0;
end

knk_rcos_filt #(.vendor("altera"))rcos_filt(.clk(clk),.reset(reset),.ena(cnt==9),.dr(dr),.di(di));

endmodule
//end module----------




//start_module------------------------------------------------------------
// Module Name     :  knk_int_x2_filt
// Date            :  22.01.25 
// Description     :  clk=120M, symbol speed = 3 MBod, sampling 12M -> 24M 
// Matlab          :  Matlab/filt_int_x2.m
module knk_int_x2_filt(clk,reset,ena,dr,di,qr,qi,qena);
parameter vendor= "altera";
parameter w_in=16;
parameter w_out=16;
input clk,reset,ena;
input  [w_in-1:0] dr, di;
output [w_out-1:0] qr, qi;
output qena;
wire [15:0] coef [5:0];

assign coef[0] =16'hff5a;
assign coef[1] =16'hfc0d;
assign coef[2] =16'hfa3d;
assign coef[3] =16'h07e2;
assign coef[4] =16'h256f;
assign coef[5] =16'h1b12;//3625; to simplify the structure - half coeficient !!!

reg [31:0] bufd [5:0];

always@(posedge clk or posedge reset) begin
 if (reset) bufd[0] <= 0;
 else if (ena) bufd[0] <= {dr,di};
end

genvar count;
generate for (count=1;count<=5;count=count+1) begin:gen_buf  
 always@(posedge clk or posedge reset) begin
  if (reset) bufd[count] <= 0;
  else if (ena) bufd[count] <= bufd[count-1];
 end
end endgenerate


reg [2:0] cnt_avt;
wire [w_in:0]  sum_r, sum_i;
wire [15:0]  coeff;
generate for (count=0;count<3;count=count+1) begin:gen_sum  
 assign sum_r=(cnt_avt==count)? {bufd[count][31]  ,bufd[count][31:16]}   +  {bufd[5-count][31]  ,bufd[5-count][31:16]} : {(w_in+1){1'bz}};
 assign sum_i=(cnt_avt==count)? {bufd[count][15]  ,bufd[count][15:0]}   +  {bufd[5-count][15]  ,bufd[5-count][15:0]} : {(w_in+1){1'bz}};
 assign coeff= (cnt_avt==count)? coef[2*count]   : {(16){1'bz}};
 assign sum_r=(cnt_avt==count+3)? {bufd[1+count][31]  ,bufd[1+count][31:16]}   +  {bufd[5-count][31]  ,bufd[5-count][31:16]} : {(w_in+1){1'bz}};
 assign sum_i=(cnt_avt==count+3)? {bufd[1+count][15]  ,bufd[1+count][15:0]}   +  {bufd[5-count][15]  ,bufd[5-count][15:0]} : {(w_in+1){1'bz}};
 assign coeff= (cnt_avt==count+3)? coef[2*count+1]   : {(16){1'bz}};
end endgenerate

reg [w_in:0]  reg_sum_r, reg_sum_i;
reg [15:0] reg_coef;
always@(posedge clk or posedge reset) begin
 if (reset) begin reg_sum_r<=0; reg_sum_i<=0; reg_coef<=0; end
 else begin 
     reg_sum_r<=sum_r;  
	 reg_sum_i<=sum_i;
	 reg_coef<=coeff;
 end end

wire [32:0] mult_r_q, mult_i_q;
generate if (vendor=="altera") begin:gen_mult_altera
 lpm_mult #(.lpm_widtha(16),.lpm_widthb(17),.lpm_widthp(33),.lpm_representation("SIGNED")) mult_r(.dataa(reg_coef),.datab(reg_sum_r),.result(mult_r_q));
 lpm_mult #(.lpm_widtha(16),.lpm_widthb(17),.lpm_widthp(33),.lpm_representation("SIGNED")) mult_i(.dataa(reg_coef),.datab(reg_sum_i),.result(mult_i_q));	
end endgenerate 
generate if (vendor=="xilinx") begin:gen_mult_xilinx 
 mult_gen_1 mult_r(.A(reg_coef), .B(reg_sum_r), .P(mult_r_q));
 mult_gen_1 mult_i(.A(reg_coef), .B(reg_sum_i), .P(mult_i_q));
end endgenerate 

always@(posedge clk or posedge reset) begin
 if (reset) cnt_avt <= 6;
 else if (ena) cnt_avt <= 0;
 else if (cnt_avt<6) cnt_avt <=cnt_avt +1;
end

reg [23:0] reg_mult_r_q, reg_mult_i_q;
always@(posedge clk or posedge reset) begin
 if (reset) begin reg_mult_r_q<=0; reg_mult_i_q<=0; end
 else begin
  reg_mult_r_q <= mult_r_q[31:8];
  reg_mult_i_q <= mult_i_q[31:8]; 
 end end


reg [2:0] cnt_out;
always@(posedge clk or posedge reset) begin
 if (reset) cnt_out<=6;
 else if (cnt_avt == 1) cnt_out<=0;
 else if (cnt_out<6) cnt_out<=cnt_out+1;
end

reg [23:0] accum_r, accum_i;
always@(posedge clk or posedge reset) begin
 if (reset) accum_r<=0;
 else if ((cnt_out==0)|(cnt_out==3))  accum_r<= reg_mult_r_q;
 else if (cnt_out<6)   accum_r<= reg_mult_r_q + accum_r;
end

always@(posedge clk or posedge reset) begin
 if (reset) accum_i<=0;
 else if ((cnt_out==0)|(cnt_out==3))  accum_i<= reg_mult_i_q;
 else if (cnt_out<6)   accum_i<= reg_mult_i_q + accum_i;
end

reg lock1_out;
always@(posedge clk or posedge reset) begin
 if (reset) lock1_out<=0;
 else lock1_out<=(cnt_out == 2);
end

reg lock2_out;
always@(posedge clk or posedge reset) begin
 if (reset) lock2_out<=0;
 else lock2_out<=(cnt_out == 5);
end

reg [w_out-1:0] q1r,q1i;
reg q1ena;
always@(posedge clk or posedge reset) begin
 if (reset) begin q1ena<=0; q1r<=0; q1i<=0; end
 else if (lock1_out) begin q1ena<=1; q1r<=accum_r[22:7]+{15'd0,accum_r[6]}; q1i<=accum_i[22:7]+{15'd0,accum_i[6]}; end
 else q1ena<=0;
end 

reg [w_out-1:0] q2r,q2i;
reg q2ena;
always@(posedge clk or posedge reset) begin
 if (reset) begin q2ena<=0; q2r<=0; q2i<=0; end
 else if (lock2_out) begin q2ena<=1; q2r<=accum_r[22:7]+{15'd0,accum_r[6]}; q2i<=accum_i[22:7]+{15'd0,accum_i[6]}; end
 else q2ena<=0;
end 


reg [4*w_out-1:0] rd;
always@(posedge clk or posedge reset) begin
 if (reset) rd<=0;
 else if (ena) rd<={q1r,q1i,q2r,q2i};
end


reg [w_out-1:0] qr, qi;
reg qena;
always@(posedge clk or posedge reset) begin
 if (reset)  begin  qena<=0; qr<=0; qi<=0;  end
 else if (cnt_avt==0) begin qena<=1; {qr,qi}<=rd[31:0]; end
 else if (cnt_avt==5) begin qena<=1; {qr,qi}<=rd[63:32]; end
 else qena<=0;
end


endmodule
//end module----------







//start_module------------------------------------------------------------
// Module Name     :  knk_cor_func
// Date            :  01.04.25 
// Description     :  clk=120M, symbol speed = 3 MBod, preamble corellation function 
// Matlab          :  D:\knk_pkrv_2024\ModelSimPrj\knk_pkrv_modem\Matlab\test_pream_sync.m , APFC.m
module knk_cor_func(clk,reset,dr,di,q,q_stb,lock_pr,per,cnt_per,is_tdma, t_slot, deb_sig);
parameter vendor= "xilinx";
parameter w=16;
parameter mfl = 5;
parameter mf_bs = (1 << mfl);


//parameter t_slot = 22'd1920000; //8 ms tx, 8ms rx
//parameter t_slot = 22'd960000; //8 ms tx, 0ms rx
//parameter t_slot = 22'd1200000; //10 ms tx, 0ms rx
input clk,reset;
input  [w-1:0] dr, di;
output [7:0] q;
output q_stb;
output lock_pr;
output [21:0] per, cnt_per;
input is_tdma;
input [21:0] t_slot;
output [19:0] deb_sig;

reg [2*w-1:0] bf [40:0];
always@(posedge clk or posedge reset) begin
 if (reset) bf[0]<=0;
 else bf[0]<={dr,di};
end

genvar count;
generate for (count=1;count<=40;count=count+1) begin:bf_gen 
always@(posedge clk or posedge reset) begin
 if (reset) bf[count]<=0;
 else bf[count]<=bf[count-1];
end
end 
endgenerate

wire [23:0] mix_r, mix_i;
knk_mix #(.width_e(16),.width_d(16),.width_q(24),.vendor(vendor)) mix(.clk(clk),.reset(reset),.ena(1'b1),.er(bf[0][31:16]),.ei(bf[0][15:0]),.dr(bf[40][31:16]),.di(bf[40][15:0]),.qr(mix_r),.qi(mix_i),.inv(1'b1));

wire [23:0] amix_r = (mix_r[23])?~mix_r+1:mix_r;
wire [23:0] amix_i = (mix_i[23])?~mix_i+1:mix_i;

reg [23:0] mnr,mni,por;
always@(posedge clk or posedge reset) begin
 if (reset) por <= 0;
 else if ({amix_r[23],amix_r[23:1]} > amix_i) por <= {amix_r[23],amix_r[23:1]} ;
 else if ({amix_i[23],amix_i[23:1]} > amix_r) por <= {amix_i[23],amix_i[23:1]} ;
 else por <= {amix_r[23],amix_r[23:1]} + { {(2){amix_r[23]}} , amix_r[23:2] };
end

always@(posedge clk or posedge reset) begin
 if (reset) begin mnr <= 0; mni <=0; end
 else  begin mnr <= mix_r; mni <=mix_i; end
end

reg [15:0] shr,shi,shp;
always@(posedge clk or posedge reset) begin
 if (reset)             begin  shp <= 0;                 shi<=0;                        shr<=0;                     end
 else if (~|por[22:7])  begin  shp <= {por[7:0],8'd0};   shi <= {mni[8:0],7'd0};        shr <= {mnr[8:0],7'd0};     end
 else if (~|por[22:11]) begin  shp <= {por[11:0],4'd0};  shi <= {mni[12:0],3'd0};       shr <= {mnr[12:0],3'd0};    end
 else if (~|por[22:15]) begin  shp <= por[15:0];         shi <= mni[16:1];              shr <= mnr[16:1];           end
 else if (~|por[22:19]) begin  shp <= por[19:4];         shi <= mni[20:5];              shr <= mnr[20:5];           end
 else                   begin  shp <= por[23:8];         shi <= {mni[23],mni[23:9]};    shr <= {mnr[23],mnr[23:9]}; end
end

reg [15:0] shqr,shqi,shqp;
always@(posedge clk or posedge reset) begin
 if (reset)                        begin  shqp <= 0;                  shqi<=0;                    shqp<=0;                    end
 else if (~|shp[14:12])            begin  shqp <= {shp[13:0],2'd0};   shqi <= {shi[13:0],2'd0};   shqr <= {shr[13:0],2'd0};   end
 else if (~|{shp[14:13],~shp[12]}) begin  shqp <= {shp[14:0],1'd0};   shqi <= {shi[14:0],1'd0};   shqr <= {shr[14:0],1'd0};   end
 else if (~|{shp[14],~shp[13:12]}) begin  shqp <= shp;                shqi <= shi;                shqr <= shr;                end
 else if (&shp[14:12])             begin  shqp <= {shp[15],shp[15:1]};   shqi <= {shi[15],shi[15:1]};   shqr <= {shr[15],shr[15:1]};   end
end

reg [15:0] d2qr,d2qi,d2qp;
wire [15:0] d2ch = shqp+{1'd0,shqp[15:1]};
always@(posedge clk or posedge reset) begin
 if (reset)               begin  d2qr<=0;                              d2qi<=0;                               d2qp<=0;      end
 else if (~|d2ch[15:14])  begin  d2qr<= shqr + {shqr[15],shqr[15:1]};  d2qi<= shqi + {shqi[15],shqi[15:1]};   d2qp<=d2ch;   end     
 else                     begin  d2qr<= shqr;                          d2qi<= shqi;                           d2qp <= shqp; end
end


reg [15:0]  d4qr,d4qi,d4qp;
wire [15:0] d4ch = d2qp+{2'd0,d2qp[15:2]};
always@(posedge clk or posedge reset) begin
 if (reset)               begin  d4qr<=0;                                     d4qi<=0;                                      d4qp<=0;      end
 else if (~|d4ch[15:14])  begin  d4qr<= d2qr + {{(2){d2qr[15]}},d2qr[15:2]};  d4qi<= d2qi + {{(2){d2qi[15]}},d2qi[15:2]};   d4qp<=d4ch;   end     
 else                     begin  d4qr<= d2qr;                                 d4qi<= d2qi;                                  d4qp <= d2qp; end
end

reg [15:0]  d8qr,d8qi,d8qp;
wire [15:0] d8ch = d4qp+{3'd0,d4qp[15:3]};
always@(posedge clk or posedge reset) begin
 if (reset)               begin  d8qr<=0;                                     d8qi<=0;                                      d8qp<=0;      end
 else if (~|d8ch[15:14])  begin  d8qr<= d4qr + {{(3){d4qr[15]}},d4qr[15:3]};  d8qi<= d4qi + {{(3){d4qi[15]}},d4qi[15:3]};   d8qp<=d8ch;   end     
 else                     begin  d8qr<= d4qr;                                 d8qi<= d4qi;                                  d8qp <= d4qp; end
end
 
wire [7:0] dsr = d8qr[15:8];
wire [7:0] dsi = d8qi[15:8];

//wire [7:0] dsr = mix_r[23:16];
//wire [7:0] dsi = mix_i[23:16];

//mult 0,707 -> 8'h5a   
wire [15:0] m_5a_dsr = { {(7){dsr[7]}}, dsr,1'd0}+{{(5){dsr[7]}}, dsr, 3'd0}+{{(4){dsr[7]}}, dsr, 4'd0}+{{(2){dsr[7]}}, dsr, 6'd0};
wire [15:0] m_5a_dsi = { {(7){dsi[7]}}, dsi,1'd0}+{{(5){dsi[7]}}, dsi, 3'd0}+{{(4){dsi[7]}}, dsi, 4'd0}+{{(2){dsi[7]}}, dsi, 6'd0};

reg [7:0] rdsr, rdsi, rm_5a_dsr, rm_5a_dsi;
always@(posedge clk or posedge reset) begin
 if (reset) begin rdsr<=0; rdsi<=0; rm_5a_dsr<=0; rm_5a_dsi<=0; end
 else begin rdsr<=dsr; rdsi<=dsi; rm_5a_dsr<=m_5a_dsr[14:7]; rm_5a_dsi<=m_5a_dsi[14:7]; end
end

//wire [7:0] cor [14:0];
//assign cor [0]  =       rdsr              ;
//assign cor [1]  =       rdsr              ;
//assign cor [2]  = -rm_5a_dsr - rm_5a_dsi  ;
//assign cor [3]  =      -rdsr              ;
//assign cor [4]  = -rm_5a_dsr - rm_5a_dsi  ;
//assign cor [5]  =  rm_5a_dsr - rm_5a_dsi  ;
//assign cor [6]  =  rm_5a_dsr - rm_5a_dsi  ;
//assign cor [7]  =                   rdsi  ;
//assign cor [8]  = -rm_5a_dsr + rm_5a_dsi  ;
//assign cor [9]  =                   rdsi  ;
//assign cor [10] =  rm_5a_dsr + rm_5a_dsi  ;
//assign cor [11] =       rdsr              ;
//assign cor [12] =       rdsr              ;
//assign cor [13] =                  -rdsi  ;
//assign cor [14] = -rm_5a_dsr + rm_5a_dsi  ;


reg [7:0] cor [14:0];
generate for (count=0;count<15;count=count+1) begin:cor_gen 
  always@(posedge clk or posedge reset) begin
  if (reset) cor[count] <= 0;
  else begin
     if (count ==0)      cor [0]  <=       rdsr              ;
     if (count ==1)      cor [1]  <=       rdsr              ;
	 if (count ==2)      cor [2]  <= -rm_5a_dsr - rm_5a_dsi  ;
	 if (count ==3)      cor [3]  <=      -rdsr              ;
	 if (count ==4)      cor [4]  <= -rm_5a_dsr - rm_5a_dsi  ;
	 if (count ==5)      cor [5]  <=  rm_5a_dsr - rm_5a_dsi  ;
	 if (count ==6)      cor [6]  <=  rm_5a_dsr - rm_5a_dsi  ;
	 if (count ==7)      cor [7]  <=                   rdsi  ;
	 if (count ==8)      cor [8]  <= -rm_5a_dsr + rm_5a_dsi  ;
	 if (count ==9)      cor [9]  <=                   rdsi  ;
	 if (count ==10)     cor [10] <=  rm_5a_dsr + rm_5a_dsi  ;
	 if (count ==11)     cor [11] <=       rdsr              ;
	 if (count ==12)     cor [12] <=       rdsr              ;
	 if (count ==13)     cor [13] <=                  -rdsi  ;
	 if (count ==14)     cor [14] <= -rm_5a_dsr + rm_5a_dsi  ;
  end end
end endgenerate



reg [3:0] cnt_acc;
reg [5:0] cnt_cor;

 wire stg=(cnt_cor == 6'd39);
 always@(posedge clk or posedge reset) begin
  if (reset) cnt_cor <= 0;
  else if (stg) cnt_cor <= 0;
  else cnt_cor <= cnt_cor + 1;
 end

always@(posedge clk or posedge reset) begin
 if (reset)  cnt_acc  <= 0;
 else if (stg) begin
  if (cnt_acc == 4'd14) cnt_acc <= 0;
  else cnt_acc <= cnt_acc + 1;
 end end


reg [119:0] reg_cor;
always@(posedge clk or posedge reset) begin
 if (reset) reg_cor <= 0;
 else case(cnt_acc)
 4'd0 :reg_cor <= {cor[0]  ,cor[14]  ,cor[13] ,cor[12] ,cor[11] ,cor[10] ,cor[9]  ,cor[8]  ,cor[7]  ,cor[6]  ,cor[5]  ,cor[4]  ,cor[3]  ,cor[2]  ,cor[1]  };
 4'd1 :reg_cor <= {cor[1]  ,cor[0]   ,cor[14] ,cor[13] ,cor[12] ,cor[11] ,cor[10] ,cor[9]  ,cor[8]  ,cor[7]  ,cor[6]  ,cor[5]  ,cor[4]  ,cor[3]  ,cor[2]  };
 4'd2 :reg_cor <= {cor[2]  ,cor[1]   ,cor[0]  ,cor[14] ,cor[13] ,cor[12] ,cor[11] ,cor[10] ,cor[9]  ,cor[8]  ,cor[7]  ,cor[6]  ,cor[5]  ,cor[4]  ,cor[3]  };
 4'd3 :reg_cor <= {cor[3]  ,cor[2]   ,cor[1]  ,cor[0]  ,cor[14] ,cor[13] ,cor[12] ,cor[11] ,cor[10] ,cor[9]  ,cor[8]  ,cor[7]  ,cor[6]  ,cor[5]  ,cor[4]  };
 4'd4 :reg_cor <= {cor[4]  ,cor[3]   ,cor[2]  ,cor[1]  ,cor[0]  ,cor[14] ,cor[13] ,cor[12] ,cor[11] ,cor[10] ,cor[9]  ,cor[8]  ,cor[7]  ,cor[6]  ,cor[5]  };
 4'd5 :reg_cor <= {cor[5]  ,cor[4]   ,cor[3]  ,cor[2]  ,cor[1]  ,cor[0]  ,cor[14] ,cor[13] ,cor[12] ,cor[11] ,cor[10] ,cor[9]  ,cor[8]  ,cor[7]  ,cor[6]  };
 4'd6 :reg_cor <= {cor[6]  ,cor[5]   ,cor[4]  ,cor[3]  ,cor[2]  ,cor[1]  ,cor[0]  ,cor[14] ,cor[13] ,cor[12] ,cor[11] ,cor[10] ,cor[9]  ,cor[8]  ,cor[7]  };
 4'd7 :reg_cor <= {cor[7]  ,cor[6]   ,cor[5]  ,cor[4]  ,cor[3]  ,cor[2]  ,cor[1]  ,cor[0]  ,cor[14] ,cor[13] ,cor[12] ,cor[11] ,cor[10] ,cor[9]  ,cor[8]  };
 4'd8 :reg_cor <= {cor[8]  ,cor[7]   ,cor[6]  ,cor[5]  ,cor[4]  ,cor[3]  ,cor[2]  ,cor[1]  ,cor[0]  ,cor[14] ,cor[13] ,cor[12] ,cor[11] ,cor[10] ,cor[9]  };
 4'd9 :reg_cor <= {cor[9]  ,cor[8]   ,cor[7]  ,cor[6]  ,cor[5]  ,cor[4]  ,cor[3]  ,cor[2]  ,cor[1]  ,cor[0]  ,cor[14] ,cor[13] ,cor[12] ,cor[11] ,cor[10] };
 4'd10:reg_cor <= {cor[10] ,cor[9]   ,cor[8]  ,cor[7]  ,cor[6]  ,cor[5]  ,cor[4]  ,cor[3]  ,cor[2]  ,cor[1]  ,cor[0]  ,cor[14] ,cor[13] ,cor[12] ,cor[11] };
 4'd11:reg_cor <= {cor[11] ,cor[10]  ,cor[9]  ,cor[8]  ,cor[7]  ,cor[6]  ,cor[5]  ,cor[4]  ,cor[3]  ,cor[2]  ,cor[1]  ,cor[0]  ,cor[14] ,cor[13] ,cor[12] };
 4'd12:reg_cor <= {cor[12] ,cor[11]  ,cor[10] ,cor[9]  ,cor[8]  ,cor[7]  ,cor[6]  ,cor[5]  ,cor[4]  ,cor[3]  ,cor[2]  ,cor[1]  ,cor[0]  ,cor[14] ,cor[13] };
 4'd13:reg_cor <= {cor[13] ,cor[12]  ,cor[11] ,cor[10] ,cor[9]  ,cor[8]  ,cor[7]  ,cor[6]  ,cor[5]  ,cor[4]  ,cor[3]  ,cor[2]  ,cor[1]  ,cor[0]  ,cor[14] };
 4'd14:reg_cor <= {cor[14] ,cor[13]  ,cor[12] ,cor[11] ,cor[10] ,cor[9]  ,cor[8]  ,cor[7]  ,cor[6]  ,cor[5]  ,cor[4]  ,cor[3]  ,cor[2]  ,cor[1]  ,cor[0]  };
endcase end

reg  [11:0] acc [599:0]; //15*12*40
wire [39:0] ena_acc ;
reg  [39:0] rena_acc ;
always@(posedge clk or posedge reset) begin
 if (reset) rena_acc <= 0;
 else rena_acc <= ena_acc;
end

generate for (count=0;count<40;count=count+1) begin:ena_acc_gen 
 assign ena_acc[count] =  (cnt_cor == count);
end endgenerate

reg [3:0] rcnt_acc;
always@(posedge clk or posedge reset) begin
 if (reset) rcnt_acc <= 0;
 else rcnt_acc <= cnt_acc;
end

//wire [11:0] cor_q;
reg [7:0] ac [39:0];

genvar i, j;
generate 

for (j=0;j<40;j=j+1) begin:cor_j_gen 
for (i=0;i<15;i=i+1) begin:cor_i_gen 

always@(posedge clk or posedge reset) begin
if (reset) acc[j*15+i] <= 0;
else if (rena_acc[j]&(rcnt_acc == i) )  acc[j*15+i] <={ {(4){reg_cor[119-8*i]}},reg_cor[119-8*i:120-8*(i+1)]}; 
 else if (rena_acc[j])   acc[j*15+i] <= acc[j*15+i] + { {(4){reg_cor[119-8*i]}},reg_cor[119-8*i:120-8*(i+1)]};
end

//assign cor_q = (rena_acc[j]&(rcnt_acc == i) )? acc[j*15+i]:12'hzzzzzz;

end 

always@(posedge clk or posedge reset) begin
if (reset) ac[j] <= 0;
//else if (rena_acc[j]) case(rcnt_acc)
else if (rena_acc[j]) case(rcnt_acc)
4'd0:  ac[j] <= acc[j*15+0]  [11:4];
4'd1:  ac[j] <= acc[j*15+1]  [11:4];
4'd2:  ac[j] <= acc[j*15+2]  [11:4];
4'd3:  ac[j] <= acc[j*15+3]  [11:4];
4'd4:  ac[j] <= acc[j*15+4]  [11:4];
4'd5:  ac[j] <= acc[j*15+5]  [11:4];
4'd6:  ac[j] <= acc[j*15+6]  [11:4];
4'd7:  ac[j] <= acc[j*15+7]  [11:4];
4'd8:  ac[j] <= acc[j*15+8]  [11:4];
4'd9:  ac[j] <= acc[j*15+9]  [11:4];
4'd10: ac[j] <= acc[j*15+10] [11:4];
4'd11: ac[j] <= acc[j*15+11] [11:4];
4'd12: ac[j] <= acc[j*15+12] [11:4];
4'd13: ac[j] <= acc[j*15+13] [11:4];
4'd14: ac[j] <= acc[j*15+14] [11:4];
endcase end

end
endgenerate
  
reg [7:0] acp;
always@(posedge clk or posedge reset) begin
if (reset) acp <= 0;
else case(cnt_cor)
6'd2:  acp <= ac[0];
6'd3:  acp <= ac[1];
6'd4:  acp <= ac[2];
6'd5:  acp <= ac[3];
6'd6:  acp <= ac[4];
6'd7:  acp <= ac[5];
6'd8:  acp <= ac[6];
6'd9:  acp <= ac[7];
6'd10: acp <= ac[8];
6'd11: acp <= ac[9];
6'd12: acp <= ac[10];
6'd13: acp <= ac[11];
6'd14: acp <= ac[12];
6'd15: acp <= ac[13];
6'd16: acp <= ac[14];
6'd17: acp <= ac[15];
6'd18: acp <= ac[16];
6'd19: acp <= ac[17];
6'd20: acp <= ac[18];
6'd21: acp <= ac[19];
6'd22: acp <= ac[20];
6'd23: acp <= ac[21];
6'd24: acp <= ac[22];
6'd25: acp <= ac[23];
6'd26: acp <= ac[24];
6'd27: acp <= ac[25];
6'd28: acp <= ac[26];
6'd29: acp <= ac[27];
6'd30: acp <= ac[28];
6'd31: acp <= ac[29];
6'd32: acp <= ac[30];
6'd33: acp <= ac[31];
6'd34: acp <= ac[32];
6'd35: acp <= ac[33];
6'd36: acp <= ac[34];
6'd37: acp <= ac[35];
6'd38: acp <= ac[36];
6'd39: acp <= ac[37];
6'd0:  acp <= ac[38];
6'd1:  acp <= ac[39];
endcase end


reg [7:0] acp_bf [mf_bs-1:0];

always@(posedge clk or posedge reset) begin
 if (reset) acp_bf[0]<=0;
 else acp_bf[0]<=acp;
end

generate for (count=1;count<mf_bs;count=count+1) begin:acp_bf_gen 
always@(posedge clk or posedge reset) begin
 if (reset) acp_bf[count]<=0;
 else acp_bf[count]<=acp_bf[count-1];
end
end 
endgenerate

// wire [10:0] acpf = { {(3){acp_bf[0][7]}} ,acp_bf[0]} +
                   // { {(3){acp_bf[1][7]}} ,acp_bf[1]} +
                   // { {(3){acp_bf[2][7]}} ,acp_bf[2]} +
                   // { {(3){acp_bf[3][7]}} ,acp_bf[3]} +
                   // { {(3){acp_bf[4][7]}} ,acp_bf[4]} +
                   // { {(3){acp_bf[5][7]}} ,acp_bf[5]} +
				   // { {(3){acp_bf[6][7]}} ,acp_bf[6]} +
				   // { {(3){acp_bf[7][7]}} ,acp_bf[7]};
				   
				   
reg  [mfl+7:0] acpf;	   
always@(posedge clk or posedge reset) begin
 if (reset) acpf<=0;
 else   acpf<=acpf + { {(mfl){acp[7]}} ,acp } -   { {(mfl){acp_bf[mf_bs-1][7]}} ,acp_bf[mf_bs-1]};   
end			   


reg [7:0] q; 
reg q_stb;
always@(posedge clk or posedge reset) begin
 if (reset) begin q<=0; q_stb <= 0; end
 else begin q_stb <= (~acpf[mfl+7]&(acpf[mfl+7:mfl] > 8'd43)); q <= acpf[mfl+7:mfl]; end
end 


wire pen;
knk_en env(.clk(clk),.pre(reset),.step(q_stb),.imp(pen));

reg [5:0] cnt_fp;
always@(posedge clk or posedge reset) begin
 if (reset) cnt_fp <=6'h3f;
 else if (&cnt_fp&pen) cnt_fp <= 0;
 else if (~&cnt_fp) cnt_fp <= cnt_fp + 1;
end

reg [5:0] fp_max;
reg [mfl+7:0] acpf_max;

always@(posedge clk or posedge reset) begin
 if (reset) begin fp_max <=0; acpf_max <= 0; end
 else if (cnt_fp == 0) begin acpf_max <= 0; fp_max <= 0; end
 else if (~&cnt_fp) begin
  if ((~acpf[mfl+7]&(acpf > acpf_max)))  begin acpf_max <= acpf; fp_max <= cnt_fp; end 
end end

reg [5:0] cnt_sh_ena;
always@(posedge clk or posedge reset) begin
 if (reset) cnt_sh_ena <=6'h3f;
 else if (cnt_fp == 6'h3e) cnt_sh_ena <= 0;
 else if (~&cnt_sh_ena)  cnt_sh_ena <= cnt_sh_ena +1;
end


//wire lock = ~&cnt_sh_ena&(cnt_sh_ena == fp_max);


reg [21:0] m_lock;
wire val_lock = m_lock > (t_slot - 22'd120); 
always@(posedge clk or posedge reset) begin
 if (reset) m_lock <= t_slot;
 else if ((cnt_sh_ena == fp_max)&val_lock) m_lock <= 0;
 else if (m_lock<t_slot) m_lock <=m_lock + 1;
end

wire lock = (cnt_sh_ena == fp_max)&val_lock;


//DPLL


reg  [21+8:0] dpll_cnt;
wire [21+8:0] dpll_cor_cnt = (dpll_cnt[21+8:8] < {1'b0,t_slot[21:1]} )?-dpll_cnt: {t_slot, 8'd0}-dpll_cnt;
reg  [21+8:0] dpll_rcor_cnt;
reg  dpll_lock_rcor;
reg  dpll_q;





always@(posedge clk or posedge reset) begin
 if (reset) begin dpll_cnt<=0; dpll_rcor_cnt<=0; dpll_lock_rcor<=0; dpll_q<=0;  end
 else begin
 
  if (lock) begin
   dpll_rcor_cnt  <= dpll_rcor_cnt - { {(4){dpll_rcor_cnt[21+8]}} ,dpll_rcor_cnt[21+8:4]} + { {(4){dpll_cor_cnt[21+8]}} ,dpll_cor_cnt[21+8:4]};
   dpll_lock_rcor <= 1'b1;
  end
  
  if (dpll_lock_rcor & (dpll_cnt[21+8:8] > {1'b0,t_slot[21:1]}-2) & (dpll_cnt[21+8:8] < {1'b0,t_slot[21:1]}+2)) begin
   //if (dpll_cnt + dpll_rcor_cnt +30'd256 >={t_slot, 8'd0}) begin dpll_cnt<=dpll_cnt+ dpll_rcor_cnt +30'd256-{t_slot, 8'd0}; dpll_q<=1; end
   //else 
   dpll_cnt<=dpll_cnt+ dpll_rcor_cnt +30'd256;
   dpll_lock_rcor <= 1'b0;
  end else begin
   //if (dpll_cnt +30'd256 >={t_slot, 8'd0}) begin dpll_cnt<=dpll_cnt+30'd256-{t_slot, 8'd0}; dpll_q<=~dpll_cnt[7];  dpll_ro_q<=dpll_cnt[7];  end
   //else begin dpll_cnt<=dpll_cnt+30'd256;  dpll_q<=dpll_ro_q;  dpll_ro_q<=1'b0;   end
   
   if (~dpll_cnt[21+8]&(dpll_cnt +30'd256 >={t_slot, 8'd0})) begin dpll_cnt<=dpll_cnt+30'd256-{t_slot, 8'd0}; dpll_q<=1'b1;  end
   else begin dpll_cnt<=dpll_cnt+30'd256;  dpll_q<=1'b0;   end
   
  end
 
 end end

/* 
reg [28:0] aper;
reg  [21:0] cnt_per;
wire [21:0] per;
wire [21:0] sper = per + cnt_per;

always@(posedge clk or posedge reset) begin
 if (reset) cnt_per <= 0; 
 else  cnt_per <= (~sper[21]&(sper >= t_slot-1)) ? 0 : cnt_per + 1; 
 //else  cnt_per <= (~sper[21]&(sper >= t_slot-1)) ? sper - t_slot +1: cnt_per + 1; 
end

wire [21:0] dper = (~sper[21]&(sper >={1'b0,t_slot[21:1]})) ? sper - t_slot : sper;  
assign per = aper[28:7] + {21'd0,aper[6]};

wire [28:0] saper = aper - { {(3){dper[21]}} ,dper,4'd0};

//wire [20:0] gate_per = (saper[28])?~saper[28:8]+1:saper[28:8];

always@(posedge clk or posedge reset) begin
 if (reset) aper <= 0;
 else if (~is_tdma) aper <= 0;
 //else if (lock&(gate_per<21'd150000)) aper <= saper; 
 else if (lock) aper <= saper; 
end

*/

// reg m_lock_pr;
// always@(posedge clk or posedge reset) begin
 // if (reset)  m_lock_pr <=0;
 // else if (&cnt_fp&pen) m_lock_pr <=1;
 // else if (dpll_q) m_lock_pr <=0;
// end

// wire lock_pr = dpll_q&m_lock_pr;

wire  [21:0] a_dpll_rcor_cnt = (dpll_rcor_cnt[21+8])? -dpll_rcor_cnt[21+8:8] : dpll_rcor_cnt[21+8:8];
assign lock_pr = dpll_q & (a_dpll_rcor_cnt < 16);

assign deb_sig = {acp, q, q_stb, pen, lock, lock_pr};

assign per=dpll_rcor_cnt[21+8:8] + {21'd0,dpll_rcor_cnt[7]};


// reg [21:0] sh_ph;
// always@(posedge clk or posedge reset) begin
 // if (reset) sh_ph<=0;
 // else if (lock) sh_ph<=(dpll_cnt[21+8:8] > {1'b0,t_slot[21:1]})? dpll_cnt[21+8:8] + {21'd0,dpll_cnt[7]} - t_slot : dpll_cnt[21+8:8] + {21'd0,dpll_cnt[7]}; end

// reg [21:0] b_sh_ph [mf_bs-1:0];

// always@(posedge clk or posedge reset) begin
 // if (reset) b_sh_ph[0]<=0;
 // else if (lock) b_sh_ph[0]<=sh_ph;
// end

// generate for (count=1;count<mf_bs;count=count+1) begin:filt_sh_ph_gen 
// always@(posedge clk or posedge reset) begin
 // if (reset) b_sh_ph[count]<=0;
 // else if (lock) b_sh_ph[count]<=b_sh_ph[count-1];
// end
// end 
// endgenerate

			   				   
// reg  [mfl+21:0] ac_sh_ph;	   
// always@(posedge clk or posedge reset) begin
 // if (reset) ac_sh_ph<=0;
 // else  if (lock) ac_sh_ph<=ac_sh_ph + { {(mfl){sh_ph[21]}} ,sh_ph } -   { {(mfl){b_sh_ph[mf_bs-1][21]}} ,b_sh_ph[mf_bs-1]};   
// end			   


// wire [21:0] cnt_per = ac_sh_ph[mfl+21:mfl] + {21'd0,ac_sh_ph[mfl-1]};


 reg [21:0] temp_cnt;
 always@(posedge clk or posedge reset) begin
  if (reset) temp_cnt<=0;
  else if (lock) temp_cnt<=0;
  else temp_cnt<=temp_cnt+1; end


reg [21:0] cnt_per;
 always@(posedge clk or posedge reset) begin
  if (reset) cnt_per<=0;
  else if (lock) cnt_per<=temp_cnt; end


//ila_11 tmp_cor (
//	.clk(clk), // input wire clk
//	.probe0(cnt_per), // input wire [21:0]  probe0  
//	.probe1(lock) // input wire [0:0]  probe1
//);



 reg [21:0] temp_cntt;
 always@(posedge clk or posedge reset) begin
  if (reset) temp_cntt<=0;
  else if (lock_pr) temp_cntt<=0;
  else temp_cntt<=temp_cntt+1; end


reg [21:0] cnt_perr;
 always@(posedge clk or posedge reset) begin
  if (reset) cnt_perr<=0;
  else if (lock_pr) cnt_perr<=temp_cntt; end


//ila_11 tmp_corr (
//	.clk(clk), // input wire clk
//	.probe0(cnt_perr), // input wire [21:0]  probe0  
//	.probe1(lock_pr) // input wire [0:0]  probe1
//);

















endmodule
//end module----------


//start_module------------------------------------------------------------
// Module Name     :  knk_sum_bits
// Date            :  17.09.25 
// Description     :   
// Matlab          :  
module knk_sum_bits(d, q);
parameter wi = 8; // >=2
parameter wo = 4; // func(wi)
input [wi-1:0] d;
output [wo-1:0] q;

genvar count;
wire [wo-1:0] db[wi-1:0];
wire [wo-1:0] s[wi-2:0];
generate for (count=0;count<wi;count=count+1) begin:sum_gen 
assign db[count] = {{(wo-1){1'b0}},d[count]};
if (count == 0) assign s[count] = db[count]+db[count+1];
else if (count < wi-1)  assign s[count] = db[count+1]+s[count-1];
end endgenerate

assign q = s[wi-2];
//assign q = db[0]+db[1]+db[2]+db[3]+db[4]+db[5]+db[6]+db[7];

endmodule
//end module----------




//start_module------------------------------------------------------------
// Module Name     :  knk_lock_pream
// Date            :  17.09.25 
// Description     :  clk=120M, symbol speed = 3 MBod, bpsk preamble lock function 
// Matlab          :  D:\knk_pkrv_2024\ModelSimPrj\knk_pkrv_modem\Matlab\test_pream_sync_inc_length.m 
module knk_lock_pream(clk,reset,dr,di,lock,st_mod, q);
parameter vendor= "xilinx";
parameter w=16;
parameter wp=48;
parameter [wp-1:0] pream  = 48'b101101101100111000100110000111010110110110011100;
parameter [wp-2:0] dpream = pream[wp-2:0]^pream[wp-1:1];
parameter sum_dbs_bfd = 36;
parameter ac_sum_dbs_gr = 6;

input clk,reset;
input  [w-1:0] dr, di;
input st_mod;
output lock;
output [2*w-1:0] q;


reg [2*w-1:0] bf [40:0];
always@(posedge clk or posedge reset) begin
 if (reset) bf[0]<=0;
 else bf[0]<={dr,di};
end

genvar count;
generate for (count=1;count<=40;count=count+1) begin:bf_gen 
always@(posedge clk or posedge reset) begin
 if (reset) bf[count]<=0;
 else bf[count]<=bf[count-1];
end
end 
endgenerate

wire [23:0] mix_r, mix_i;
knk_mix #(.width_e(16),.width_d(16),.width_q(24),.vendor(vendor)) mix(.clk(clk),.reset(reset),.ena(1'b1),.er(bf[0][31:16]),.ei(bf[0][15:0]),.dr(bf[40][31:16]),.di(bf[40][15:0]),.qr(mix_r),.qi(mix_i),.inv(1'b1));

reg [23:0] mnr,mni;
always@(posedge clk or posedge reset) begin
 if (reset) begin mnr <= 0; mni <=0; end
 else  begin mnr <= mix_r; mni <=mix_i; end
end

reg [5:0] cnt_sample;
 always@(posedge clk or posedge reset) begin
  if (reset) cnt_sample <= 0;
  else if (cnt_sample == 39) cnt_sample <= 0;
  else cnt_sample <= cnt_sample + 1;
 end

reg [wp-2:0] sh_data [39:0];
reg [wp-2:0] data;
wire [wp-2:0] wdata;
generate for (count=0;count<40;count=count+1) begin:sh_gen_gen 
  always@(posedge clk or posedge reset) begin
  if (reset) sh_data[count] <= 0;
  else if (cnt_sample == count) sh_data[count]<={sh_data[count][wp-3:0], mnr[23]}; end
  assign wdata = (cnt_sample == count)?{sh_data[count][wp-3:0], mnr[23]}:{(wp-1){1'bz}};
end endgenerate

 always@(posedge clk or posedge reset) begin
  if (reset) data<=0;
  //else if (cnt_sample == count)   data<=~({sh_data[count][wp-3:0], mnr[23]}^dpream);
  else data<=~wdata^dpream;
  end



wire [3:0] bs [5:0];
reg  [3:0] rbs [5:0];
wire [wp-1:0] ndata = {1'b0, data};
generate for (count=0;count<6;count=count+1) begin:sum_bits   
  knk_sum_bits sum_bits(.d(ndata[47-count*8:48-(count+1)*8]), .q(bs[count])); 
  always@(posedge clk or posedge reset) begin
  if (reset) rbs[count]<=0;
  else rbs[count]<=bs[count];
  end
end endgenerate

reg [5:0] sum_dbs;
always@(posedge clk or posedge reset) begin
if (reset) sum_dbs<=0;
else sum_dbs <= {2'd0,rbs[0]}+{2'd0,rbs[1]}+{2'd0,rbs[2]}+{2'd0,rbs[3]}+{2'd0,rbs[4]}+{2'd0,rbs[5]};
end


reg [5:0] sum_dbs_bf [sum_dbs_bfd-1:0];

always@(posedge clk or posedge reset) begin
 if (reset) sum_dbs_bf[0]<=0;
 else sum_dbs_bf[0]<=sum_dbs;
end

generate for (count=1;count<sum_dbs_bfd;count=count+1) begin:sum_dbs_bf_gen 
always@(posedge clk or posedge reset) begin
 if (reset) sum_dbs_bf[count]<=0;
 else sum_dbs_bf[count]<=sum_dbs_bf[count-1];
end
end 
endgenerate

			   
reg  [ac_sum_dbs_gr+5:0] ac_sum_dbs;	   
always@(posedge clk or posedge reset) begin
 if (reset) ac_sum_dbs<=0;
 else   ac_sum_dbs<=ac_sum_dbs + { {(ac_sum_dbs_gr){1'b0}} ,sum_dbs } -   { {(ac_sum_dbs_gr){1'b0}} ,sum_dbs_bf[sum_dbs_bfd-1]};   
end	

wire por = (ac_sum_dbs >= 12'd1438); //36*47*0.85 

wire pen;
knk_en env(.clk(clk),.pre(reset),.step(por),.imp(pen));

reg [4:0] cnt_fp;
reg [4:0] cnt_sh_ena;

always@(posedge clk or posedge reset) begin
 if (reset) cnt_fp <=5'h1f;
 else if ((&cnt_fp)&(&cnt_sh_ena)&pen) cnt_fp <= 0;
 else if (~&cnt_fp) cnt_fp <= cnt_fp + 1;
end

reg [4:0] fp_max;
reg [ac_sum_dbs_gr+5:0] ac_sum_dbs_max;

always@(posedge clk or posedge reset) begin
 if (reset) begin fp_max <=0; ac_sum_dbs_max <= 0; end
 else if (cnt_fp == 0) begin ac_sum_dbs_max <= 0; fp_max <= 0; end
 else if (~&cnt_fp) begin
  if (ac_sum_dbs > ac_sum_dbs_max)  begin ac_sum_dbs_max <= ac_sum_dbs; fp_max <= cnt_fp; end 
end end


always@(posedge clk or posedge reset) begin
 if (reset) cnt_sh_ena <=5'h1f;
 else if (cnt_fp == 5'h1e) cnt_sh_ena <= 0;
 else if (~&cnt_sh_ena)  cnt_sh_ena <= cnt_sh_ena +1;
end

assign lock = (cnt_sh_ena == fp_max);
assign q = bf[16]; // delay samples to lock position -> knk_lock_pream_stimulus

//reg [21:0] m_lock;
//wire val_lock = m_lock > (t_slot - 22'd120); 
//always@(posedge clk or posedge reset) begin
// if (reset) m_lock <= t_slot;
// else if ((cnt_sh_ena == fp_max)&val_lock) m_lock <= 0;
// else if (m_lock<t_slot) m_lock <=m_lock + 1;
//end

//reg [21:0] cnt_deb;
//always@(posedge clk or posedge reset) begin
// if (reset) cnt_deb<=0;
// else if (st_mod) cnt_deb<=0;
// else cnt_deb<=cnt_deb+1;
// end

//ila_11 pream_ila (
//	.clk(clk), // input wire clk
//	.probe0(cnt_deb), // input wire [21:0]  probe0  
//	.probe1(lock) // input wire [0:0]  probe1
//);

endmodule
//end module----------





//start_module------------------------------------------------------------
// Module Name     :  knk_cor_func_stimulus
// Date            :  02.04.25 
// Description     :  
// Matlab          :  
module knk_lock_pream_stimulus();

reg clk,reset;  
initial clk = 1'b1;
initial begin
reset=1;
#100 reset=0; 
end

always #8 clk = ~clk; 

reg [31:0] d;
wire [15:0] dr, di;
assign dr={d[23:16],d[31:24]};
assign di={d[7:0],d[15:8]};

integer fid;
initial fid=$fopen("D:/knk_pkrv_2024/ModelSimPrj/knk_pkrv_modem/Matlab/test.dat","rb");

wire [31:0] lock_pream_q;
wire lock;
knk_lock_pream #(.vendor("altera")) lock_pream(.clk(clk),.reset(reset),.dr(dr),.di(di), .lock(lock), .q(lock_pream_q));
knk_start_solve_ap start_solve_ap(.clk(clk),.reset(reset),.dr(lock_pream_q[31:16]),.di(lock_pream_q[15:0]),.start(lock));


reg [31:0] cnt;
always@(posedge clk or posedge reset) begin 
if (reset) begin d<=0; cnt<=0; end
else begin 
cnt<=cnt+1;
if (cnt >= 45000) begin
 d<=0;
 $fclose(fid);
// $fclose(result);
// $fclose(res_dem);
 $stop; //terminate the simulation
end else begin
 $fread(d,fid);  
// if (qena) $fwrite(result,"%U",q[31:0]);
// if (qsena) $fwrite(res_dem,"%U",dem_q[31:0]);
end end end

endmodule
//end module----------




//start_module------------------------------------------------------------
// Module Name     :  knk_solve_gain
// Date            :  07.10.25 
// Description     :  clk=120M, reverse number -> q = 1/d * 2^20 
// Matlab          :  D:\knk_pkrv_2024\ModelSimPrj\knk_pkrv_modem\Matlab\table_div.m 
module knk_solve_gain(clk,reset,d,q );
//parameter vendor= "xilinx";
input clk, reset;
input [15:0] d;
output [15:0] q;

reg [10:0] table_addr;
wire [15:0] table_q;
rom_table_div_func table_div_func(.clka(clk), .addra(table_addr), .douta(table_q));

always@(posedge clk or posedge reset) begin
 if (reset) table_addr <= 0;
 else if (d < 16'd256)       table_addr <= d[10:0];
 else if (d < 16'd512)       table_addr <= d[11:1]-11'd128+11'd256;
 else if (d < 16'd1024)      table_addr <= d[12:2]-11'd128+11'd384;
 else if (d < 16'd2048)      table_addr <= d[13:3]-11'd128+11'd512;
 else if (d < 16'd4096)      table_addr <= d[14:4]-11'd128+11'd640;
 else if (d < 16'd8192)      table_addr <= d[15:5]-11'd128+11'd768;
 else if (d < 16'd16384)     table_addr <= {1'b0,d[15:6]}-11'd128+11'd896;
 else                        table_addr <= {2'b0,d[15:7]}-11'd128+11'd1024;
end

assign q = table_q;

endmodule
//end module----------

//start_module------------------------------------------------------------
// Module Name     :  knk_solve_gain_stimulus
// Date            :  08.10.25 
// Description     :  
// Matlab          :  D:\knk_pkrv_2024\ModelSimPrj\knk_pkrv_modem\Matlab\result_solve_gain.m
module knk_solve_gain_stimulus();

reg clk,reset;  
initial clk = 1'b1;
initial begin
reset=1;
#100 reset=0; 
end

always #8 clk = ~clk; 

reg [15:0] d;
wire [15:0] q;

knk_solve_gain   solve_gain(.clk(clk),.reset(reset),.d(d), .q(q));


always@(posedge clk or posedge reset) begin
 if (reset) d<=0;
 else if (~&d) d<=d+1; end

integer result;
initial result=$fopen("D:/knk_pkrv_2024/ModelSimPrj/knk_pkrv_modem/Matlab/result_solve_gain.dat","wb");




reg stp;
always@(posedge clk or posedge reset) begin 
if (reset) stp <=0;
else stp<=&d[14:0]; end 


reg [16:0] del1,del2;
always@(posedge clk or posedge reset) begin 
if (reset) begin del1<=0; del2<=0; end
else begin del1<= {stp,d}; del2 <= del1; end end



wire [31:0] res = {q,del2[15:0]}; 


always@(posedge clk or posedge reset) begin 
if (reset) begin end
else if (~del2[16]) begin

 $fwrite(result,"%U",res);

end 
else begin
 $fclose(result);
 $stop; //terminate the simulation
end end

endmodule
//end module----------

//start_module------------------------------------------------------------
// Module Name     :  knk_start_solve_ap
// Date            :  06.10.25 
// Description     :  clk=120M, symbol speed = 3 MBod, 8 symbols after preamble with fix bits for solve amplitude and phase correction coefficients 
// Matlab          :  D:\knk_pkrv_2024\ModelSimPrj\knk_pkrv_modem\Matlab\test_pream_sync_inc_length.m 
module knk_start_solve_ap(clk,reset,dr,di,start, gain, pha, gain_set, pha_set, q, q_start , deb_is_pr);
//parameter vendor= "xilinx";
parameter w=16;
input clk, reset;
input [w-1:0] dr, di;
input start;
output [16:0] gain;
output [31:0] pha;
output gain_set, pha_set;
output [2*w-1:0] q;
output q_start;
input deb_is_pr;


reg [3:0] cnt_sym;
reg [5:0] cnt_ena;
always@(posedge clk or posedge reset) begin
 if (reset) begin cnt_ena<=0; cnt_sym<=4'd9; end
 else if (start) begin cnt_ena<=0; cnt_sym<=0; end
 else if (~(cnt_sym == 4'd9)) begin
 cnt_ena<=(cnt_ena == 6'd39)?0:cnt_ena+1;
 if (cnt_ena == 6'd39) cnt_sym<=cnt_sym+1;
 end end

reg [15:0] x,y;
always@(posedge clk or posedge reset) begin
 if (reset)  {x,y}<=0; 
 else if (start) {x,y}<={dr,di};
 else if (~cnt_sym[3]&(cnt_ena == 6'd39)) {x,y}<={dr,di};
end
 
wire [31:0] p;
wire [15:0] r;
knk_cordic_polar #(.width(16), .section(12)) cordic_polar(.clk(clk),.reset(reset),.ena(1'b1),.x_in(x),.y_in(y) ,.p_out(p), .r_out(r));

wire [15:0] g;
knk_solve_gain solve_gain(.clk(clk),.reset(reset),.d(r),.q(g));

wire ac_sclr = start;
wire ac_p_ena = (cnt_ena == 6'h0f)&(cnt_sym < 4'd8);      
wire ac_g_ena = (cnt_ena == 6'h13)&(cnt_sym < 4'd8);      

reg [34:0] ac_p0, ac_p1;
reg [18:0] ac_g;
reg [7:0] deb_p_sign;
wire deb_is_p_sign_change = ~((deb_p_sign == 8'h00)|(deb_p_sign == 8'hFF));

reg sw_ac_p;

wire [31:0] a_p = (p[31])? -p : p;


always@(posedge clk or posedge reset) begin
 if (reset) begin ac_p0 <=0; ac_p1 <=0; ac_g<=0; deb_p_sign<=0;  sw_ac_p<=0; end
 else if (ac_sclr) begin ac_p0 <=0; ac_p1 <=0; ac_g<=0; deb_p_sign<=0; sw_ac_p<=0; end
 else if (ac_p_ena) begin 
 
 ac_p0<=ac_p0 + { {(3){p[31]}},p};
 ac_p1<=ac_p1 + {3'd0,p};  
 
 if (~sw_ac_p) sw_ac_p<=(a_p > 32'h60000000);
 
 deb_p_sign<={deb_p_sign[6:0],p[31]}; end 
 else if (ac_g_ena) ac_g<=ac_g + {3'd0,g}; 
end 

//assign gain = {1'b0,ac_g[18:3]};            
//assign pha  = (sw_ac_p)? ac_p1[34:3] : ac_p0[34:3];                   
//assign gain_set = (cnt_ena == 6'h14)&(cnt_sym == 4'd7); 
//assign pha_set  = (cnt_ena == 6'h10)&(cnt_sym == 4'd7); 



reg [16:0] gain;
reg gain_set;
always@(posedge clk or posedge reset) begin
 if (reset) begin gain<=0; gain_set<=0; end
 else if ((cnt_ena == 6'h14)&(cnt_sym == 4'd7)) begin gain<={1'b0,ac_g[18:3]};  gain_set<=1'b1; end
 else  gain_set<=1'b0; end



reg [31:0] pha;
reg pha_set;
always@(posedge clk or posedge reset) begin
 if (reset) begin pha<=0; pha_set<=0; end
 else if ((cnt_ena == 6'h10)&(cnt_sym == 4'd7)) begin pha<=(sw_ac_p)? ac_p1[34:3] : ac_p0[34:3];  pha_set<=1'b1; end
 else  pha_set<=1'b0; end



reg [2*w-1:0]  q;    
reg q_start;

always@(posedge clk or posedge reset) begin
 if (reset) begin  q<=0; q_start<=0; end
 else begin
 
    q_start<=((cnt_ena == 6'd39)&(cnt_sym == 4'd7));
    q<= {dr,di};

 end end
 
/*
ila_knk_start_solve_ap your_instance_name (
	.clk(clk), // input wire clk


	.probe0(dr), // input wire [15:0]  probe0  
	.probe1(di), // input wire [15:0]  probe1 
	.probe2(start), // input wire [0:0]  probe2 
	.probe3(gain), // input wire [16:0]  probe3 
	.probe4(pha), // input wire [31:0]  probe4 
	.probe5(gain_set), // input wire [0:0]  probe5 
	.probe6(pha_set), // input wire [0:0]  probe6 
	.probe7(q), // input wire [31:0]  probe7 
	.probe8(q_start), // input wire [0:0]  probe8 
	.probe9(cnt_sym), // input wire [3:0]  probe9 
	.probe10(cnt_ena), // input wire [5:0]  probe10 
	.probe11(x), // input wire [15:0]  probe11 
	.probe12(y), // input wire [15:0]  probe12 
	.probe13(p), // input wire [31:0]  probe13 
	.probe14(r), // input wire [15:0]  probe14 
	.probe15(g), // input wire [15:0]  probe15 
	.probe16(ac_p_ena), // input wire [0:0]  probe16 
	.probe17(ac_g_ena), // input wire [0:0]  probe17 
	.probe18(deb_is_pr), // input wire [0:0]  probe18 
	.probe19(ac_p0), // input wire [34:0]  probe19 
	.probe20(ac_g), // input wire [18:0]  probe20
	.probe21(deb_p_sign), // input wire [7:0]  probe21 
	.probe22(deb_is_p_sign_change) // input wire [0:0]  probe22
);

*/









endmodule
//end module----------










//start_module------------------------------------------------------------
// Module Name     :  knk_cor_func_stimulus
// Date            :  02.04.25 
// Description     :  
// Matlab          :  
module knk_cor_func_stimulus();

reg clk,reset;  
initial clk = 1'b1;
initial begin
reset=1;
#100 reset=0; 
end

always #8 clk = ~clk; 

reg [31:0] d;
wire [15:0] dr, di;
assign dr={d[23:16],d[31:24]};
assign di={d[7:0],d[15:8]};
integer fid;
//, result,res_dem;

initial fid=$fopen("D:/knk_pkrv_2024/ModelSimPrj/knk_pkrv_modem/Matlab/test.dat","rb");

//initial result=$fopen("D:/knk_pkrv_2024/QtPrj/build-com_debug-Desktop_Qt_5_12_9_MinGW_32_bit-Debug/result.dat","wb");
//initial res_dem=$fopen("D:/knk_pkrv_2024/QtPrj/build-com_debug-Desktop_Qt_5_12_9_MinGW_32_bit-Debug/res_dem.dat","wb");


knk_cor_func #(.vendor("altera")) cor_func(.clk(clk),.reset(reset),.dr(dr),.di(di));



//wire [15:0] qr, qi;
//wire qena;
//assign q={qi[15:8],qi[7:0],qr[15:8],qr[7:0]};


//wire [15:0] qsr, qsi;
//wire qsena;
//wire [31:0] dem_q;
//wire [31:0] rotr,roti;
///assign dem_q={qsi[15:8],qsi[7:0],qsr[15:8],qsr[7:0]};
//assign dem_q={roti[31:16],rotr[31:16]};


reg [31:0] cnt;
always@(posedge clk or posedge reset) begin 
if (reset) begin d<=0; cnt<=0; end
else begin 
cnt<=cnt+1;
if (cnt >= 45000) begin
 d<=0;
 $fclose(fid);
// $fclose(result);
// $fclose(res_dem);
 $stop; //terminate the simulation
end else begin
 $fread(d,fid);  
// if (qena) $fwrite(result,"%U",q[31:0]);
// if (qsena) $fwrite(res_dem,"%U",dem_q[31:0]);
end end end

endmodule
//end module----------





//start_module------------------------------------------------------------
// Module Name     :  knk_int_x2_filt_stimulus
// Date            :  23.01.25 
// Description     :  
// Matlab          :  
module knk_int_x2_filt_stimulus();

reg clk,reset;  
initial clk = 1'b1;
initial begin
reset=1;
#100 reset=0; 
end

always #8 clk = ~clk; 

reg [3:0] cnt;
always@(posedge clk or posedge reset) begin
 if (reset) cnt<=0;
 else if(cnt==9) cnt<=0;
 else cnt<=cnt+1;
end 

reg [15:0] dr,di;
reg ena;
always@(posedge clk or posedge reset) begin
 if (reset) begin {dr,di}<=0; ena<=0; end
 else if (cnt==9) begin {dr,di}<={16'h3fff,16'h3fff}; ena<=1; end
 else ena<=0;
end

knk_int_x2_filt #(.vendor("xilinx")) filt(.clk(clk),.reset(reset),.ena(cnt==9),.dr(dr),.di(di));

endmodule
//end module----------




//start_module------------------------------------------------------------
// Module Name     :  knk_gardner_sync
// Date            :  04.02.25 
// Description     :  symbol synchronization, clk = 120MHz 
// Matlab          :  D:\knk_pkrv_2024\QtPrj\build-com_debug-Desktop_Qt_5_12_9_MinGW_32_bit-Debug\parse_deb_data.m   -> output parsing
module knk_gardner_sync(clk,reset, sset, is_tdma,  dr,di,qr,qi,qena, cnt_sample, nSig, run, deb_Kagc, deb_per, deb_dper, pkt_length, last_sym, start_sym,  pream_gain);
//parameter pkt_len = 15'd24000; // symbols
parameter vendor= "altera";
//parameter w_one=26; // '1'=2^w_one-1  //git ver
parameter w_one=22; // '1'=2^w_one-1
//parameter wg=24;//git ver
parameter wg=24;
//parameter agc_por = {{(6){1'b0}},1'b1,{(26){1'b0}}};//git ver
parameter agc_por = {{(10){1'b0}},1'b1,{(22){1'b0}}};
input clk, reset;
input sset;
input  [15:0] dr,di;
output [15:0] qr,qi;
output qena;
output [5:0] cnt_sample;
input is_tdma;
output nSig;
output run;
output [16:0] deb_Kagc; 
output [8+5:0] deb_per, deb_dper;
input [19:0] pkt_length;
output last_sym;
output start_sym;
input [16:0] pream_gain;



//delay  dr, di  
reg [15:0] r_dr,r_di;
always@(posedge clk or posedge reset) begin
if (reset) begin  r_dr<=0; r_di<=0; end
else begin  r_dr<=dr; r_di<=di; end end



reg [15:0] qr,qi;
reg qena;

reg [15:0] rdr_last, rdr_half, rdr;
reg [15:0] rdi_last, rdi_half, rdi;
reg [16:0] sub_dr, sub_di;

reg [15:0]  gc_rdr, gc_rdi;



reg [8+5:0] per, dper;

assign deb_per=per;
assign deb_dper=dper;

reg [5:0]   rp, per_round;
reg [5:0]   cnt_sample;

reg [31:0] er,ei,e;
reg [31:0] vp,vi,v;

reg [15:0] mult_a;
reg [16:0] mult_b;
wire [32:0] mult_q;


reg [19:0] cnt_sym;
reg last_sym, start_sym;
reg m_start_sym;

generate if (vendor=="altera") begin:gen_mult_altera
 lpm_mult #(.lpm_widtha(16),.lpm_widthb(17),.lpm_widthp(33),.lpm_representation("SIGNED")) mult_r(.dataa(mult_a),.datab(mult_b),.result(mult_q));
end endgenerate 
generate if (vendor=="xilinx") begin:gen_mult_xilinx 
 mult_gen_1 mult(.A(mult_a), .B(mult_b), .P(mult_q));
end endgenerate 


reg [19:0]  pkt_len;


//wire nSig=(cnt_sym == pkt_len)&is_tdma;

reg nSig;



always@(posedge clk or posedge reset) begin
if (reset) cnt_sample<=0;
 else if ((cnt_sample == per_round-1)&(cnt_sample >22)) cnt_sample <= 0;
 else if (sset&nSig)  cnt_sample <= 6'd39;
 else if (nSig&(cnt_sample == 0)) cnt_sample <= 0;
 else cnt_sample <= cnt_sample + 1;
end
 
reg [16:0] Kagc; 

assign deb_Kagc=Kagc;

reg [32:0] power_rdr;
reg [32:0] accum_agc; 
wire [32:0] sum_accum_agc=accum_agc + {  {(5){power_rdr[32]}},      power_rdr[32:5]}; // git ver
//wire [32:0] sum_accum_agc=accum_agc + {  {(7){power_rdr[32]}},      power_rdr[32:7]};

wire run=~(is_tdma&(cnt_sym <= 2));

always@(posedge clk or posedge reset) begin
 if (reset) begin   

nSig<=1; 
 
qr <= 0; qi <= 0; qena <= 0;
gc_rdr<=0;  gc_rdi<=0;
rdr_last <= 0; rdr_half <= 0; rdr <= 0;
rdi_last <= 0; rdi_half <= 0; rdi <= 0;
per <= 0; dper <=0;  per_round=6'd40;rp<=0;
er <= 0; ei <= 0; e <= 0;
mult_a<=0; mult_b<=0;
vp <= 0; vi <= 0; v <= 0;
Kagc<=17'h00200;
power_rdr <= 0;
//accum_agc <= {{(6){1'b0}},1'b1,{(26){1'b0}}};
accum_agc <= agc_por;

pkt_len<=pkt_length;
cnt_sym<=pkt_length;

//cnt_sym<=pkt_len;

last_sym <= 0;
start_sym<=0;
m_start_sym<=0;

end 

else if (sset&nSig) begin

gc_rdr<=0;  gc_rdi<=0;
qr <= 0; qi <= 0; qena <= 0;
rdr_last <= 0; rdr_half <= 0; rdr <= 0;
rdi_last <= 0; rdi_half <= 0; rdi <= 0;
per <= 0; dper <=0;  per_round=6'd40;rp<=0;
er <= 0; ei <= 0; e <= 0;
mult_a<=0; mult_b<=0;
vp <= 0; vi <= 0; v <= 0;
cnt_sym<=0;
last_sym <= 0;
start_sym<=0; 
m_start_sym<=1;
Kagc<=pream_gain;

nSig<=0;

end 

//else if (nSig)      begin pkt_len<=pkt_length; cnt_sym<=pkt_length;  end

else begin

if (cnt_sample == per_round - 1) begin
 rdr <= r_dr; rdi <= r_di; 
 rdr_last <= rdr; rdi_last <= rdi; 
 
 nSig = (cnt_sym == pkt_len)&is_tdma;
 
end 

//case (cnt_sample)
if (cnt_sample == 0) begin //6'd0: begin
 mult_b <= Kagc;
 mult_a <= rdr;
 
 if (nSig)  begin pkt_len<=pkt_length; cnt_sym<=pkt_length;  end
 
end 
if (cnt_sample == 1) begin//6'd1: begin
 //if (~mult_q[32]&(|mult_q[31:24])) rdr <= 16'h7fff;
 //else if (mult_q[32]&(~(&mult_q[31:24]))) rdr <= 16'h8001;
 //else rdr <= mult_q[24:9]; 
 
 if (~mult_q[32]&(|mult_q[31:wg])) rdr <= 16'h7fff;
 else if (mult_q[32]&(~(&mult_q[31:wg]))) rdr <= 16'h8001;
 else rdr <= mult_q[wg:wg-15]; 
 
 
 if (~mult_q[32]&(|mult_q[31:wg-2])) gc_rdr <= 16'h7fff;
 else if (mult_q[32]&(~(&mult_q[31:wg-2]))) gc_rdr <= 16'h8001;
 else gc_rdr <= mult_q[wg-2:wg-2-15];
 
 
 mult_b <= Kagc;
 mult_a <= rdi;
end
if (cnt_sample == 2) begin//6'd2: begin
 //if (~mult_q[32]&(|mult_q[31:24])) rdi <= 16'h7fff;
 //else if (mult_q[32]&(~(&mult_q[31:24]))) rdi <= 16'h8001;
 //else rdi <= mult_q[24:9]; 
 
 if (~mult_q[32]&(|mult_q[31:wg])) rdi <= 16'h7fff;
 else if (mult_q[32]&(~(&mult_q[31:wg]))) rdi <= 16'h8001;
 else rdi <= mult_q[wg:wg-15]; 
 
 if (~mult_q[32]&(|mult_q[31:wg-2])) gc_rdi <= 16'h7fff;
 else if (mult_q[32]&(~(&mult_q[31:wg-2]))) gc_rdi <= 16'h8001;
 else gc_rdi <= mult_q[wg-2:wg-2-15]; 
 
 mult_b <= {rdr[15],rdr};
 mult_a <= rdr;
end
if (cnt_sample == 3) begin//6'd3: begin
 //qr <= rdr; qi <= rdi; //git ver
 qr <= gc_rdr; qi <= gc_rdi; 
 
 qena <=  1'b1; last_sym<= (cnt_sym == pkt_len - 1);
 m_start_sym<=0;
 start_sym<=m_start_sym;
 
 sub_dr <= {rdr_last[15],rdr_last}-{rdr[15],rdr};
 sub_di <= {rdi_last[15],rdi_last}-{rdi[15],rdi};
 mult_b <= {rdi[15],rdi};
 mult_a <= rdi;
 power_rdr <= mult_q;
end
if (cnt_sample == 4) begin//6'd4: begin
 qena <= 0; last_sym<=0; start_sym<=0;
 mult_b <= sub_dr;
 mult_a <= rdr_half;
 power_rdr <= power_rdr + mult_q;
  
 if (~(cnt_sym == pkt_len))  cnt_sym <= cnt_sym + 1;
 
 
end
if (cnt_sample == 5) begin//6'd5: begin
 er <= mult_q[31:0];
 mult_b <= sub_di;
 mult_a <= rdi_half;
 //power_rdr <=  {{(6){1'b0}},1'b1,{(26){1'b0}}}-power_rdr;
 power_rdr  <= agc_por - power_rdr;
end
if (cnt_sample == 6) begin//6'd6: begin
 ei <= mult_q[31:0];
 if (run&(~sum_accum_agc[32])&(|sum_accum_agc[31:20])) accum_agc <= sum_accum_agc;
end
if (cnt_sample == 7) begin//6'd7: begin
 e <= {er[31],er[31:1]} + {ei[31],ei[31:1]};//div 2 
 
 if (run) Kagc <= accum_agc[32:16];
  
  
end
if (cnt_sample == 8) begin//6'd8: begin
 vp <= {{(1){e[31]}},e[31:1]};     //div 1
 if (run) vi <= vi-{{(7){e[31]}},e[31:7]};
 
 //vp <= e[31:0];                      //div 2  - > working with div =4,8 ?
 //if (run) vi <= vi-{{(6){e[31]}},e[31:6]};
 
 
end
if (cnt_sample == 9) begin//6'd9: begin
 v <= vi-vp;
end
if (cnt_sample == 10) begin//6'd10: begin


if (run) per <= {6'd40,8'd0}-v[w_one+5:w_one+5-13] +dper;



end
if (cnt_sample == 11) begin//6'd11: begin
 rp <=per[13:8]+{5'd0,per[7]};
end
if (cnt_sample == 12) begin//6'd12: begin
 if ((rp>6'd42)|(rp<6'd38)) begin
 per <= 0; dper <=0;  per_round=6'd40; vi <= 0;
 //end else if (run) begin per_round <= rp; dper <= per - {rp,8'd0}; end
 //end else if (run) begin per_round <= rp; dper <= (per[7])? {6'd0,per[7:0]} - {5'd0, 1'b1, 8'd0} + 14'd1  : {7'd0,per[6:0]}  ;    end
 //end else if (run) begin per_round <= rp; dper <= (per[7])? ~{6'd0,~per[7:0]} + 14'd1  : {7'd0,per[6:0]}  ;    end
  end else if (run) begin per_round <= rp; dper <= (per[7])?  {7'b1111111 , per[6:0]} + 14'd1  : {7'b0000000,per[6:0]}  ;    end
 
 
end

if (cnt_sample == 19) begin//6'd19: begin
 rdr_half <= r_dr; rdi_half <= r_di;
end
if (cnt_sample == 20) begin//6'd20: begin
 mult_b <= Kagc;
 mult_a <= rdr_half;
end
if (cnt_sample == 21) begin//6'd21: begin
 //if (~mult_q[32]&(|mult_q[31:24])) rdr_half <= 16'h7fff;
 //else if (mult_q[32]&(~(&mult_q[31:24]))) rdr_half <= 16'h8001;
 //else rdr_half <= mult_q[24:9]; 
 
 if (~mult_q[32]&(|mult_q[31:wg])) rdr_half <= 16'h7fff;
 else if (mult_q[32]&(~(&mult_q[31:wg]))) rdr_half <= 16'h8001;
 else rdr_half <= mult_q[wg:wg-15]; 
 
 mult_b <= Kagc;
 mult_a <= rdi_half;
end
if (cnt_sample == 22) begin//6'd22: begin
 //if (~mult_q[32]&(|mult_q[31:24])) rdi_half <= 16'h7fff;
 //else if (mult_q[32]&(~(&mult_q[31:24]))) rdi_half <= 16'h8001;
 //else rdi_half <= mult_q[24:9]; 
 
 if (~mult_q[32]&(|mult_q[31:wg])) rdi_half <= 16'h7fff;
 else if (mult_q[32]&(~(&mult_q[31:wg]))) rdi_half <= 16'h8001;
 else rdi_half <= mult_q[wg:wg-15]; 
 
 
 
 
end

//default:begin  end;

//endcase
end end


/*
ila_7 ilaa (
	.clk(clk), // input wire clk
	.probe0(qena), // input wire [0:0]  probe0  
	.probe1(per), // input wire [13:0]  probe1 
	.probe2(dper), // input wire [13:0]  probe2 
	.probe3(cnt_sample), // input wire [5:0]  probe3 
	.probe4(per_round), // input wire [5:0]  probe4 
	.probe5(v), // input wire [31:0]  probe5 
	.probe6(vi), // input wire [31:0]  probe6 
	.probe7(Kagc), // input wire [16:0]  probe7
	.probe8(rdr), // input wire [15:0]  probe8 
	.probe9(rdi), // input wire [15:0]  probe9 
	.probe10(rdr_last), // input wire [15:0]  probe10 
	.probe11(rdi_last), // input wire [15:0]  probe11 
	.probe12(rdr_half), // input wire [15:0]  probe12 
	.probe13(rdi_half), // input wire [15:0]  probe13 
	.probe14(v), // input wire [31:0]  probe14 
	.probe15(vi) // input wire [31:0]  probe15
);
*/

endmodule
//end module----------





//start_module------------------------------------------------------------
// Module Name     :  knk_demaper_8psk
// Date            :  20.02.25 
// Description     :  LLR computation algorithms,  clk = 120MHz 
// PP(n)=-abs( (sr+1i*si) - si(n))^2/(2*sig^2);
// si(i)=exp(1i*pi*i/4); 1=0,..,7; sig=1/8;
// bb2(k)=max([PP(1),PP(2),PP(3),PP(4)])-max([PP(5),PP(6),PP(7),PP(8)]);
// bb1(k)=max([PP(1),PP(2),PP(5),PP(6)])-max([PP(3),PP(4),PP(7),PP(8)]);
// bb0(k)=max([PP(1),PP(3),PP(5),PP(7)])-max([PP(2),PP(4),PP(6),PP(8)]); 
// Matlab          :  D:\knk_pkrv_2024\QtPrj\build-com_debug-Desktop_Qt_5_12_9_MinGW_32_bit-Debug\demaper.m
module knk_demaper_8psk(clk,reset,sr,si,sena, sym, qsr,qsi, qr,qi, qena, deb_sr, deb_si);
parameter vendor= "altera";
parameter w_one=13; // '1'=2^w_one-1
input clk, reset;
input  [15:0] sr,si;
input sena;

output [2:0] sym;

output [15:0]  qsr,qsi;
output [31:0]  qr,qi;
output qena;

output [15:0] deb_sr, deb_si;

wire [15:0] c18_0=16'h1fff;   
wire [15:0] c18_1=16'h16a0;   
wire [15:0] c18_2=16'h0000;   
wire [15:0] c18_3=16'he960;   
wire [15:0] c18_4=16'he001;   
wire [15:0] c18_5=16'he960;   
wire [15:0] c18_6=16'h0000;   
wire [15:0] c18_7=16'h16a0;

wire [15:0] s18_0=16'h0000; 
wire [15:0] s18_1=16'h16a0;
wire [15:0] s18_2=16'h1fff;
wire [15:0] s18_3=16'h16a0;
wire [15:0] s18_4=16'h0000;
wire [15:0] s18_5=16'he960;
wire [15:0] s18_6=16'he001;
wire [15:0] s18_7=16'he960;

reg [5:0] cnt;

always@(posedge clk or posedge reset) begin
 if (reset) cnt <= 0;
 else if (sena) cnt <= 0;
 else if (cnt<39) cnt<=cnt+1;
end

reg [15:0]  mult_a;
reg [15:0]  mult_b;
wire [31:0] mult_q;

generate if (vendor=="altera") begin:gen_mult_altera
 lpm_mult #(.lpm_widtha(16),.lpm_widthb(16),.lpm_widthp(32),.lpm_representation("SIGNED")) mult_r(.dataa(mult_a),.datab(mult_b),.result(mult_q));
end endgenerate 
generate if (vendor=="xilinx") begin:gen_mult_xilinx 
 mult_gen_2 mult(.A(mult_a), .B(mult_b), .P(mult_q));
end endgenerate 

reg [15:0] sub, reg_sr, reg_si;
reg [31:0] reg_mult_q;
reg [31:0] p0,p1,p2,p3,p4,p5,p6,p7,p;
reg [15:0] qsr,qsi;
reg [31:0] qr,qi;
reg [2:0] sym;
reg qena;
reg [15:0] deb_sr, deb_si;
always@(posedge clk or posedge reset) begin
 if (reset) begin
 sub<=0; reg_sr<=0; reg_si<=0;
 reg_mult_q<=0;
 p0<=0; p1<=0; p2<=0; p3<=0; p4<=0; p5<=0; p6<=0; p7<=0;p<=0;
 qsr<=0;qsi<=0; qr<=0;qi<=0; qena<=0; sym<=0;
 deb_sr<=0;  deb_si<=0;
 end else if (sena)  begin reg_sr<=sr; reg_si<=si; end
 else case (cnt)
 6'd0:  begin sub<=reg_sr-c18_0;                                                                      end
 6'd1:  begin sub<=reg_si-s18_0; mult_a<=sub; mult_b<=sub;                                            end
 6'd2:  begin sub<=reg_sr-c18_1; mult_a<=sub; mult_b<=sub; reg_mult_q<=mult_q;                        end
 6'd3:  begin sub<=reg_si-s18_1; mult_a<=sub; mult_b<=sub;                     p0<=reg_mult_q+mult_q; end
 6'd4:  begin sub<=reg_sr-c18_2; mult_a<=sub; mult_b<=sub; reg_mult_q<=mult_q;                        end
 6'd5:  begin sub<=reg_si-s18_2; mult_a<=sub; mult_b<=sub;                     p1<=reg_mult_q+mult_q; end
 6'd6:  begin sub<=reg_sr-c18_3; mult_a<=sub; mult_b<=sub; reg_mult_q<=mult_q;                        end
 6'd7:  begin sub<=reg_si-s18_3; mult_a<=sub; mult_b<=sub;                     p2<=reg_mult_q+mult_q; end
 6'd8:  begin sub<=reg_sr-c18_4; mult_a<=sub; mult_b<=sub; reg_mult_q<=mult_q;                        end
 6'd9:  begin sub<=reg_si-s18_4; mult_a<=sub; mult_b<=sub;                     p3<=reg_mult_q+mult_q; end
 6'd10: begin sub<=reg_sr-c18_5; mult_a<=sub; mult_b<=sub; reg_mult_q<=mult_q;                        end
 6'd11: begin sub<=reg_si-s18_5; mult_a<=sub; mult_b<=sub;                     p4<=reg_mult_q+mult_q; end
 6'd12: begin sub<=reg_sr-c18_6; mult_a<=sub; mult_b<=sub; reg_mult_q<=mult_q;                        end
 6'd13: begin sub<=reg_si-s18_6; mult_a<=sub; mult_b<=sub;                     p5<=reg_mult_q+mult_q; end
 6'd14: begin sub<=reg_sr-c18_7; mult_a<=sub; mult_b<=sub; reg_mult_q<=mult_q;                        end
 6'd15: begin sub<=reg_si-s18_7; mult_a<=sub; mult_b<=sub;                     p6<=reg_mult_q+mult_q; end
 6'd16: begin                    mult_a<=sub; mult_b<=sub; reg_mult_q<=mult_q;                        end
 6'd17: begin                                                                  p7<=reg_mult_q+mult_q; end
 6'd18: begin  if(p0<p1)  begin p<=p0; qsr<=c18_0; qsi<=s18_0; sym<=3'd0; end 
               else       begin p<=p1; qsr<=c18_1; qsi<=s18_1; sym<=3'd1; end  end   
 6'd19: begin  if(p>p2)   begin p<=p2; qsr<=c18_2; qsi<=s18_2; sym<=3'd2; end  end  
 6'd20: begin  if(p>p3)   begin p<=p3; qsr<=c18_3; qsi<=s18_3; sym<=3'd3; end  end  
 6'd21: begin  if(p>p4)   begin p<=p4; qsr<=c18_4; qsi<=s18_4; sym<=3'd4; end  end  
 6'd22: begin  if(p>p5)   begin p<=p5; qsr<=c18_5; qsi<=s18_5; sym<=3'd5; end  end  
 6'd23: begin  if(p>p6)   begin p<=p6; qsr<=c18_6; qsi<=s18_6; sym<=3'd6; end  end  
 6'd24: begin  if(p>p7)   begin p<=p7; qsr<=c18_7; qsi<=s18_7; sym<=3'd7; end  end  
 
 6'd25: begin mult_a<=qsr; mult_b<=reg_si;                                end
 6'd26: begin mult_a<=qsi; mult_b<=reg_sr;   reg_mult_q<=mult_q;          end
 
 6'd27: begin mult_a<=qsr; mult_b<=reg_sr;   qi<=reg_mult_q - mult_q;     end
 6'd28: begin mult_a<=qsi; mult_b<=reg_si;   reg_mult_q<=mult_q;          end
 
 6'd29: begin qena<=1; qr<=reg_mult_q + mult_q; deb_sr<= sr; deb_si<=si;  end
 6'd30: qena<=0;
 endcase end

endmodule
//end module----------



//start_module------------------------------------------------------------
// Module Name     :  knk_demaper_psk
// Date            :  16.10.25 
// Description     :  minimum distance ,  clk = 120MHz  
// Matlab          :  
module knk_demaper_psk(clk,reset,sr,si,sena,slast,sstart, typ_mod, sym, qsr,qsi, qr,qi, qena,qlast,qstart, deb_sr, deb_si);
parameter vendor= "altera";
input clk, reset;
input  [15:0] sr,si;
input sena, slast, sstart;
input [1:0] typ_mod;

output [2:0] sym;

output [15:0]  qsr,qsi;
output [31:0]  qr,qi;
output qena, qlast, qstart;

output [15:0] deb_sr, deb_si;

wire [15:0] c18_0=16'h1fff;   
wire [15:0] c18_1=16'h16a0;   
wire [15:0] c18_2=16'h0000;   
wire [15:0] c18_3=16'he960;   
wire [15:0] c18_4=16'he001;   
wire [15:0] c18_5=16'he960;   
wire [15:0] c18_6=16'h0000;   
wire [15:0] c18_7=16'h16a0;

wire [15:0] s18_0=16'h0000; 
wire [15:0] s18_1=16'h16a0;
wire [15:0] s18_2=16'h1fff;
wire [15:0] s18_3=16'h16a0;
wire [15:0] s18_4=16'h0000;
wire [15:0] s18_5=16'he960;
wire [15:0] s18_6=16'he001;
wire [15:0] s18_7=16'he960;

reg [5:0] cnt;

always@(posedge clk or posedge reset) begin
 if (reset) cnt <= 0;
 else if (sena) cnt <= 0;
 else if (cnt<39) cnt<=cnt+1;
end

reg [15:0]  mult_a;
reg [15:0]  mult_b;
wire [31:0] mult_q;

generate if (vendor=="altera") begin:gen_mult_altera
 lpm_mult #(.lpm_widtha(16),.lpm_widthb(16),.lpm_widthp(32),.lpm_representation("SIGNED")) mult_r(.dataa(mult_a),.datab(mult_b),.result(mult_q));
end endgenerate 
generate if (vendor=="xilinx") begin:gen_mult_xilinx 
 mult_gen_2 mult(.A(mult_a), .B(mult_b), .P(mult_q));
end endgenerate 


wire is_bpsk = (typ_mod == 0);
wire is_qpsk = (typ_mod == 1);
wire is_8psk = (typ_mod == 2);


reg [15:0] sub, reg_sr, reg_si;
reg [31:0] reg_mult_q;
reg [31:0] p0,p1,p2,p3,p4,p5,p6,p7,p;
reg [15:0] qsr,qsi;
reg [31:0] qr,qi;
reg [2:0] sym;
reg qena,qlast,mlast,qstart,mstart;
reg [15:0] deb_sr, deb_si;
always@(posedge clk or posedge reset) begin
 if (reset) begin
 sub<=0; reg_sr<=0; reg_si<=0;
 reg_mult_q<=0;
 p0<=0; p1<=0; p2<=0; p3<=0; p4<=0; p5<=0; p6<=0; p7<=0;p<=0;
 qsr<=0;qsi<=0; qr<=0;qi<=0; qena<=0; sym<=0; qlast<=0; mlast<=0;
 deb_sr<=0;  deb_si<=0; qstart<=0; mstart<=0;
 end else if (sena)  begin reg_sr<=sr; reg_si<=si; mlast<=slast; mstart<=sstart; end
 else case (cnt)
 6'd0:  begin sub<=reg_sr-c18_0;                                                                      end
 6'd1:  begin sub<=reg_si-s18_0; mult_a<=sub; mult_b<=sub;                                            end
 6'd2:  begin sub<=reg_sr-c18_1; mult_a<=sub; mult_b<=sub; reg_mult_q<=mult_q;                        end
 6'd3:  begin sub<=reg_si-s18_1; mult_a<=sub; mult_b<=sub;                     p0<=reg_mult_q+mult_q; end
 6'd4:  begin sub<=reg_sr-c18_2; mult_a<=sub; mult_b<=sub; reg_mult_q<=mult_q;                        end
 6'd5:  begin sub<=reg_si-s18_2; mult_a<=sub; mult_b<=sub;                     p1<=reg_mult_q+mult_q; end
 6'd6:  begin sub<=reg_sr-c18_3; mult_a<=sub; mult_b<=sub; reg_mult_q<=mult_q;                        end
 6'd7:  begin sub<=reg_si-s18_3; mult_a<=sub; mult_b<=sub;                     p2<=reg_mult_q+mult_q; end
 6'd8:  begin sub<=reg_sr-c18_4; mult_a<=sub; mult_b<=sub; reg_mult_q<=mult_q;                        end
 6'd9:  begin sub<=reg_si-s18_4; mult_a<=sub; mult_b<=sub;                     p3<=reg_mult_q+mult_q; end
 6'd10: begin sub<=reg_sr-c18_5; mult_a<=sub; mult_b<=sub; reg_mult_q<=mult_q;                        end
 6'd11: begin sub<=reg_si-s18_5; mult_a<=sub; mult_b<=sub;                     p4<=reg_mult_q+mult_q; end
 6'd12: begin sub<=reg_sr-c18_6; mult_a<=sub; mult_b<=sub; reg_mult_q<=mult_q;                        end
 6'd13: begin sub<=reg_si-s18_6; mult_a<=sub; mult_b<=sub;                     p5<=reg_mult_q+mult_q; end
 6'd14: begin sub<=reg_sr-c18_7; mult_a<=sub; mult_b<=sub; reg_mult_q<=mult_q;                        end
 6'd15: begin sub<=reg_si-s18_7; mult_a<=sub; mult_b<=sub;                     p6<=reg_mult_q+mult_q; end
 6'd16: begin                    mult_a<=sub; mult_b<=sub; reg_mult_q<=mult_q;                        end
 6'd17: begin                                                                  p7<=reg_mult_q+mult_q; end
 
 
 
 
 
 6'd18: begin  if((p1<p3)&(is_qpsk|is_8psk))    begin p<=p1; qsr<=c18_1; qsi<=s18_1; sym<=3'd1; end 
               else if    (is_qpsk|is_8psk)     begin p<=p3; qsr<=c18_3; qsi<=s18_3; sym<=3'd3; end  end   
 6'd19: begin  if((p>p5) &(is_qpsk|is_8psk))    begin p<=p5; qsr<=c18_5; qsi<=s18_5; sym<=3'd5; end  end  
 6'd20: begin  if((p>p7) &(is_qpsk|is_8psk))    begin p<=p7; qsr<=c18_7; qsi<=s18_7; sym<=3'd7; end  end  
 6'd21: begin  if((p>p0) &(is_8psk))            begin p<=p0; qsr<=c18_0; qsi<=s18_0; sym<=3'd0; end  end  
 6'd22: begin  if((p>p2) &(is_8psk))            begin p<=p2; qsr<=c18_2; qsi<=s18_2; sym<=3'd2; end  end  
 6'd23: begin  if((p>p4) &(is_8psk))            begin p<=p4; qsr<=c18_4; qsi<=s18_4; sym<=3'd4; end  end  
 6'd24: begin  if((p>p6) &(is_8psk))            begin p<=p6; qsr<=c18_6; qsi<=s18_6; sym<=3'd6; end  end  

 6'd25: begin  if((p0<p4)&(is_bpsk))            begin p<=p0; qsr<=c18_0; qsi<=s18_0; sym<=3'd0; end 
               else if    (is_bpsk)             begin p<=p4; qsr<=c18_4; qsi<=s18_4; sym<=3'd4; end  end   


 6'd26: begin mult_a<=qsr; mult_b<=reg_si;                                end
 6'd27: begin mult_a<=qsi; mult_b<=reg_sr;   reg_mult_q<=mult_q;          end
 
 6'd28: begin mult_a<=qsr; mult_b<=reg_sr;   qi<=reg_mult_q - mult_q;     end
 6'd29: begin mult_a<=qsi; mult_b<=reg_si;   reg_mult_q<=mult_q;          end
 
 6'd30: begin qena<=1; qr<=reg_mult_q + mult_q; deb_sr<= sr; deb_si<=si; qlast<=mlast; qstart<=mstart; end
 6'd31: begin qena<=0; qlast<=0; mlast<=0; qstart<=0; mstart<=0; end
 endcase end

endmodule
//end module----------



























//start cordic modules
//start_module------------------------------------------------------------
// Module Name     :  knk_cordic_stage
// Date            :  07.10.13 
// Description     :  cordic stage with: x,y [width-1..0] & p[31..0]
module knk_cordic_stage(clk,reset,ena,x_in,y_in,p_in,x_out,y_out,p_out);
parameter width=20;
parameter section=1;
input clk,reset,ena;
input  [width-1:0] x_in,y_in;
input [31:0] p_in;
output [width-1:0] x_out,y_out;
output [31:0] p_out;
wire [31:0] phase;
generate case (section)
1:  assign phase=32'h12e4051d;
2:  assign phase=32'h09fb385b;
3:  assign phase=32'h051111d4;
4:  assign phase=32'h028b0d43;
5:  assign phase=32'h0145d7e1;
6:  assign phase=32'h00a2f61e;
7:  assign phase=32'h00517c55;
8:  assign phase=32'h0028be53;
9:  assign phase=32'h00145f2e;
10: assign phase=32'h000a2f98;
11: assign phase=32'h000517cc;
12: assign phase=32'h00028be6;
13: assign phase=32'h000145f3;
14: assign phase=32'h0000a2f9;
15: assign phase=32'h0000517c;
16: assign phase=32'h000028be;
17: assign phase=32'h0000145f;
18: assign phase=32'h00000a30;
19: assign phase=32'h00000518;
endcase endgenerate

reg [width-1:0] x_out,y_out;
reg [31:0] p_out;

wire [width-1:0] x_sh={{(section){x_in[width-1]}},x_in[width-1:section]};
wire [width-1:0] y_sh={{(section){y_in[width-1]}},y_in[width-1:section]};

always@(posedge clk or posedge reset) begin 
 if (reset) x_out<={(width){1'b0}}; 
 else if (ena) begin if (p_in[31]) x_out<=x_in+y_sh; else x_out<=x_in-y_sh; end
end

always@(posedge clk or posedge reset) begin 
 if (reset) y_out<={(width){1'b0}}; 
 else if (ena) begin if (p_in[31]) y_out<=y_in-x_sh; else y_out<=y_in+x_sh; end
end

always@(posedge clk or posedge reset) begin 
  if (reset) p_out<={32{1'b0}}; 
  else if (ena) begin if (p_in[31]) p_out<=p_in+phase; else p_out<=p_in-phase; end
end
endmodule
//end module----------



//start_module------------------------------------------------------------
// Module Name     :  knk_cordic
// Date            :  11.10.13 
// Description     :  cordic with: x,y [width-1..0] & p[31..0]
// stimulus        :  knk_cordic_stimulus 
module knk_cordic(clk,reset,ena,set,f_in,x_out,y_out,x_f_in,y_f_in,set_p);
parameter width=20;
parameter section=19;
input clk,reset,ena,set;
input [31:0] f_in;
output [width-1:0] x_out,y_out,x_f_in,y_f_in;
input set_p;

reg [31:0] f,p_in,p;
reg  [width-1:0] x,y,x_out,y_out,x_f_in,y_f_in;

reg set_ena;

always@(posedge clk or posedge reset) begin 
 if (reset) f<={32{1'b0}};
 else if (set) f<=f_in;
end 

always@(posedge clk or posedge set) begin 
 if (set) set_ena<=1'b1;
 else if (ena) set_ena<=1'b0;
end 

always@(posedge clk or posedge reset) begin 
 if (reset) p_in<={32{1'b0}}; 
 else if (ena) p_in<=(set_p)?f:p_in+f; 
end

//wire [23:0] start_amp=24'h4db9fb;
wire [23:0] start_amp=24'h4db800;
reg sign;
always@(posedge clk or posedge reset)
begin
if (reset) begin  p<={32{1'b0}};x<={width{1'b0}};y<={width{1'b0}};sign<=1'b0;end
else if (ena) begin  
case (p_in[31:30]) 
2'b00: begin p=p_in-32'h20000000; x<=start_amp[23:23-width+1]; y<=start_amp[23:23-width+1];  sign<=1'b0;  end
2'b01: begin p=32'h60000000-p_in; x<=start_amp[23:23-width+1]; y<=start_amp[23:23-width+1];  sign<=1'b1;  end
2'b10: begin p=32'ha0000000-p_in; x<=start_amp[23:23-width+1]; y<=-start_amp[23:23-width+1]; sign<=1'b1;  end
2'b11: begin p=p_in+32'h20000000; x<=start_amp[23:23-width+1]; y<=-start_amp[23:23-width+1]; sign<=1'b0;  end
endcase
end
end

wire [width-1:0] stage_x_out[0:section],stage_y_out[0:section];
wire [31:0]  stage_p_out[0:section];
assign stage_x_out[0]=x; assign stage_y_out[0]=y; assign stage_p_out[0]=p; 

genvar count;
generate for (count=1;count<=section;count=count+1) begin:stage_gen 
 knk_cordic_stage #(.width(width),.section(count)) stage_count(.clk(clk),.reset(reset),.ena(ena),
 .x_in(stage_x_out[count-1]),.y_in(stage_y_out[count-1]),.p_in(stage_p_out[count-1]),
 .x_out(stage_x_out[count]),.y_out(stage_y_out[count]),.p_out(stage_p_out[count]));
end 
endgenerate

reg [section-1:0] sign_sh;
always@(posedge clk or posedge reset)
begin 
 if (reset) sign_sh<={(section){1'b0}};
 else if (ena) sign_sh<={sign,sign_sh[section-1:1]}; 
end

always@(posedge clk or posedge reset)
begin
if (reset) begin x_out<={width{1'b0}};y_out<={width{1'b0}};end 
else if (ena) begin
 x_out<=(sign_sh[0])?-stage_x_out[section]:stage_x_out[section];
 y_out<=stage_y_out[section];
end
end

reg [section+2:0] set_sh;
always@(posedge clk or posedge reset)
begin 
if (reset) set_sh<={(section+3){1'b0}};  
else  if (ena) set_sh<={set_ena,set_sh[section+2:1]}; 
end

always@(posedge clk or posedge reset) begin 
if (reset) begin x_f_in<=0; y_f_in<=0; end
else if (set_sh[0]) begin x_f_in<=x_out; y_f_in<=y_out; end end
  
endmodule
//end module----------




//start_module------------------------------------------------------------
// Module Name     :  knk_cordic_stimulus
// Date            :  14.10.13 
// Description     :  cordic function modeling
// Matlab          :  matlab/knk_cordic_stimulus/scan.m
module knk_cordic_stimulus;
parameter width=18;
wire [width-1:0] x,y,xf,yf;
reg clk,reset,ena,set;
reg [31:0] f_in;
wire [31:0] p;

initial clk = 1'b1; 
always #5 clk = ~clk; 

initial
begin
 f_in=32'h35555555;
 reset =1'b1;
 set=1'b0;
 #315 reset=1'b0;
 #70 set=1'b1;
 #10 set=1'b0;
 #10 ena=1;
end

// reg [1:0] cnt;
// always@(posedge clk or posedge reset) begin
// if (reset) cnt<=2'b00;
// else cnt<=cnt+1;
// ena<=&cnt;
//ena<=1'b1;
// end

 reg [3:0] cnt_clks;
 reg ena_c;
 always@(posedge clk or posedge reset)
 begin if (reset) begin cnt_clks<=0; ena_c<=0; end
 else if (cnt_clks==4'd4) begin cnt_clks<=0; ena_c<=1'b1; end
 else begin cnt_clks<=cnt_clks+1; ena_c<=1'b0;  end end


knk_cordic #(.width(width),.section(width-2)) gen(.clk(clk),.reset(reset),.ena(ena_c),.set(set),.f_in(f_in),.x_out(x),.y_out(y),.x_f_in(xf),.y_f_in(yf),.set_p(1'b0));

integer fid;
initial fid=$fopen("D:/knk_pkrv_2024/QtPrj/build-com_debug-Desktop_Qt_5_12_9_MinGW_32_bit-Debug/cordic.dat","wb");
 
integer count;
initial count=0;

always@(posedge clk) begin  
//  if (count>100) $fwrite(fid,"%u",{x,14'd0},"%u",{y,14'd0});   
  count=count+1;
end
 
 always@(posedge clk) begin
  if (count==50000) begin
    $fclose(fid); 
   $stop; //terminate the simulation
   
  end
 end

endmodule
//end module----------
//end cordic modules






//start cordic_polar modules
//start_module------------------------------------------------------------
// Module Name     :  knk_cordic_polar_stage
// Date            :  21.09.17 
// Description     :  cordic stage with: x,y [width-1..0] & p[31..0]
module knk_cordic_polar_stage(clk,reset,ena,x_in,y_in,p_in,x_out,y_out,p_out,quad_in,quad_out);
parameter width=24;
parameter section=1;
input clk,reset,ena;
input  [width-1:0] x_in,y_in;
input [31:0] p_in;
output [width-1:0] x_out,y_out;
output [31:0] p_out;
input [1:0] quad_in;
output [1:0] quad_out;
wire [31:0] phase;
generate case (section)
1:  assign phase=32'h12e4051e;
2:  assign phase=32'h09fb385b;
3:  assign phase=32'h051111d4;
4:  assign phase=32'h028b0d43;
5:  assign phase=32'h0145d7e1;
6:  assign phase=32'h00a2f61e;
7:  assign phase=32'h00517c55;
8:  assign phase=32'h0028be53;
9:  assign phase=32'h00145f2f;
10: assign phase=32'h000a2f98;
11: assign phase=32'h000517cc;
12: assign phase=32'h00028be6;
13: assign phase=32'h000145f3;
14: assign phase=32'h0000a2fa;
15: assign phase=32'h0000517d;
16: assign phase=32'h000028be;
17: assign phase=32'h0000145f;
18: assign phase=32'h00000a30;
19: assign phase=32'h00000518;
20: assign phase=32'h0000028c;
21: assign phase=32'h00000146;
22: assign phase=32'h000000a3;
23: assign phase=32'h00000051;
endcase endgenerate

reg [width-1:0] x_out,y_out;
reg [31:0] p_out;

wire [width-1:0] x_sh={{(section){x_in[width-1]}},x_in[width-1:section]};
wire [width-1:0] y_sh={{(section){y_in[width-1]}},y_in[width-1:section]};

always@(posedge clk or posedge reset) begin 
 if (reset) y_out<={(width){1'b0}}; 
 else if (ena) begin if (y_in[width-1]) y_out<=y_in+x_sh; else y_out<=y_in-x_sh; end
end

always@(posedge clk or posedge reset) begin 
 if (reset) x_out<={(width){1'b0}}; 
 else if (ena) begin if (y_in[width-1]) x_out<=x_in-y_sh; else x_out<=x_in+y_sh; end
end

always@(posedge clk or posedge reset) begin 
  if (reset) p_out<={32{1'b0}}; 
  else if (ena) begin if (y_in[width-1]) p_out<=p_in+phase; else p_out<=p_in-phase; end
end

reg [1:0] quad_out;
always@(posedge clk or posedge reset) begin 
 if (reset) quad_out<={(2){1'b0}}; 
 else if (ena)  quad_out<=quad_in;
end



endmodule
//end module----------



//start_module------------------------------------------------------------
// Module Name     :  knk_cordic_polar
// Date            :  21.09.17 
// Description     :  cordic with: x,y [width-1..0] & p[31..0]
// stimulus        :  knk_cordic_polar_stimulus 
module knk_cordic_polar(clk,reset,ena,    x_in,y_in,   r_out,p_out);
parameter width=24;
parameter section=width-1;
input clk,reset,ena;
input [width-1:0] x_in,y_in;
output [width-1:0] r_out;
output [31:0]  p_out;

reg [width-1:0] r_out;
reg [31:0] p_out;

reg [width:0] x,y;

wire [width:0] x_ext={x_in[width-1],x_in[width-1:0]};
wire [width:0] y_ext={y_in[width-1],y_in[width-1:0]};


always@(posedge clk or posedge reset)
begin
if (reset) begin  x<={(width+1){1'b0}};y<={(width+1){1'b0}}; end
else if (ena) begin  
case ({x_in[width-1],y_in[width-1]}) 
2'b00: begin x<= x_ext; y<= y_ext; end
2'b01: begin x<= x_ext; y<=-y_ext; end
2'b10: begin x<=-x_ext; y<= y_ext; end
2'b11: begin x<=-x_ext; y<=-y_ext; end
endcase
end
end

reg [1:0] quad;
always@(posedge clk or posedge reset)
begin
if (reset) quad<=2'd0;
else if (ena) quad<={x_in[width-1],y_in[width-1]};
end


wire [width:0] stage_x_out[0:section],stage_y_out[0:section];
wire [31:0]  stage_p_out[0:section];
wire [1:0]  stage_quad_out[0:section];
assign stage_x_out[0]=x+y; assign stage_y_out[0]=y-x; assign stage_p_out[0]=32'he0000000; assign stage_quad_out[0]= quad;

genvar count;
generate for (count=1;count<=section;count=count+1) begin:stage_gen 
 knk_cordic_polar_stage #(.width(width+1),.section(count)) stage_count(.clk(clk),.reset(reset),.ena(1'b1),
 .x_in(stage_x_out[count-1]),.y_in(stage_y_out[count-1]),.p_in(stage_p_out[count-1]),
 .x_out(stage_x_out[count]),.y_out(stage_y_out[count]),.p_out(stage_p_out[count]),
 .quad_in(stage_quad_out[count-1]),.quad_out(stage_quad_out[count]));
end 
endgenerate


wire [width:0] r_gain;//cordic coefficient
assign r_gain=stage_x_out[section]-{{(2){stage_x_out[section][width]}},stage_x_out[section][width:2]}  
                                  -{{(3){stage_x_out[section][width]}},stage_x_out[section][width:3]}
                                  -{{(6){stage_x_out[section][width]}},stage_x_out[section][width:6]} 
                                  -{{(9){stage_x_out[section][width]}},stage_x_out[section][width:9]}
                                  -{{(13){stage_x_out[section][width]}},stage_x_out[section][width:13]}
                                  -{{(14){stage_x_out[section][width]}},stage_x_out[section][width:14]};

always@(posedge clk or posedge reset)
begin
if (reset) r_out<={width{1'b0}}; 
else if (ena)  r_out<=r_gain[width-1:0];
end

always@(posedge clk or posedge reset)
begin
if (reset) p_out<={32{1'b0}}; 
else if (ena)  begin 
case (stage_quad_out[section])
2'b00:p_out<=-stage_p_out[section];
2'b01:p_out<=stage_p_out[section];
2'b10:p_out<=32'h80000000+stage_p_out[section];
2'b11:p_out<=32'h80000000-stage_p_out[section];
endcase
end end

endmodule
//end module----------






//start_module------------------------------------------------------------
// Module Name     :  knk_cordic_polar_stimulus
// Date            :  14.10.13 
// Description     :  cordic function modeling
// Matlab          :  matlab/knk_cordic_stimulus/scan.m
module knk_cordic_polar_stimulus;
parameter width=16;
reg clk,reset;

initial clk = 1'b1; 
always #5 clk = ~clk; 

initial
begin
 reset =1'b1;
 #35 reset=1'b0;
end

wire [31:0] d_0=32'h7fff0000;
wire [31:0] d_1=32'h5a825a82;
wire [31:0] d_2=32'h00007fff;
wire [31:0] d_3=32'ha57e5a82;
wire [31:0] d_4=32'h80010000;
wire [31:0] d_5=32'ha57ea57e;
wire [31:0] d_6=32'h00008001;
wire [31:0] d_7=32'h5a82a57e;

reg [5:0] cnt;
always@(posedge clk or posedge reset) begin
if (reset) cnt<=6'd0;
else if (~&cnt) cnt<=cnt+1;
end

reg [15:0] x,y;
always@(posedge clk or posedge reset) begin
if (reset) {x,y}<=0;
else case (cnt)
6'd1:{x,y}<=d_0;
6'd2:{x,y}<=d_1;
6'd3:{x,y}<=d_2;
6'd4:{x,y}<=d_3;
6'd5:{x,y}<=d_4;
6'd6:{x,y}<=d_5;
6'd7:{x,y}<=d_6;
6'd8:{x,y}<=d_7;
default:{x,y}<=0;
endcase end


wire [width-1:0]  r_out;
wire [31:0] p_out;
knk_cordic_polar #(.width(16), .section(12) ) gen(.clk(clk),.reset(reset),.ena(1'b1),.x_in(x),.y_in(y),.r_out(r_out),.p_out(p_out));



//integer fidd;
//initial fidd=$fopen("matlab/knk_cordic_polar/cordic_stage.dat","w+");

// always@(posedge clk) begin  
  // if (ena) begin
  // $fdisplay(fidd,"%h",gen.stage_x_out[0],"%h",gen.stage_y_out[0],"%h",gen.stage_p_out[0],"%h",gen.stage_quad_out[0]);   
  // $fdisplay(fidd,"%h",gen.stage_x_out[1],"%h",gen.stage_y_out[1],"%h",gen.stage_p_out[1],"%h",gen.stage_quad_out[1]); 
  // $fdisplay(fidd,"%h",gen.stage_x_out[2],"%h",gen.stage_y_out[2],"%h",gen.stage_p_out[2],"%h",gen.stage_quad_out[2]); 
  // $fdisplay(fidd,"%h",gen.stage_x_out[3],"%h",gen.stage_y_out[3],"%h",gen.stage_p_out[3],"%h",gen.stage_quad_out[3]); 
  // $fdisplay(fidd,"%h",gen.stage_x_out[4],"%h",gen.stage_y_out[4],"%h",gen.stage_p_out[4],"%h",gen.stage_quad_out[4]); 
  // $fdisplay(fidd,"%h",gen.stage_x_out[5],"%h",gen.stage_y_out[5],"%h",gen.stage_p_out[5],"%h",gen.stage_quad_out[5]); 
  // $fdisplay(fidd,"%h",gen.stage_x_out[6],"%h",gen.stage_y_out[6],"%h",gen.stage_p_out[6],"%h",gen.stage_quad_out[6]); 
  // $fdisplay(fidd,"%h",gen.stage_x_out[7],"%h",gen.stage_y_out[7],"%h",gen.stage_p_out[7],"%h",gen.stage_quad_out[7]); 
  // $fdisplay(fidd,"%h",gen.stage_x_out[8],"%h",gen.stage_y_out[8],"%h",gen.stage_p_out[8],"%h",gen.stage_quad_out[8]); 
  // $fdisplay(fidd,"%h",gen.stage_x_out[9],"%h",gen.stage_y_out[9],"%h",gen.stage_p_out[9],"%h",gen.stage_quad_out[9]); 
  // $fdisplay(fidd,"%h",gen.stage_x_out[10],"%h",gen.stage_y_out[10],"%h",gen.stage_p_out[10],"%h",gen.stage_quad_out[10]); 
  // $fdisplay(fidd,"%h",gen.stage_x_out[11],"%h",gen.stage_y_out[11],"%h",gen.stage_p_out[11],"%h",gen.stage_quad_out[11]);
  // $fdisplay(fidd,"%h",gen.stage_x_out[12],"%h",gen.stage_y_out[12],"%h",gen.stage_p_out[12],"%h",gen.stage_quad_out[12]);
  // $fdisplay(fidd,"%h",gen.stage_x_out[13],"%h",gen.stage_y_out[13],"%h",gen.stage_p_out[13],"%h",gen.stage_quad_out[13]);
  // $fdisplay(fidd,"%h",gen.stage_x_out[14],"%h",gen.stage_y_out[14],"%h",gen.stage_p_out[14],"%h",gen.stage_quad_out[14]);
  // $fdisplay(fidd,"%h",gen.stage_x_out[15],"%h",gen.stage_y_out[15],"%h",gen.stage_p_out[15],"%h",gen.stage_quad_out[15]);
  // $fdisplay(fidd,"%h",gen.stage_x_out[16],"%h",gen.stage_y_out[16],"%h",gen.stage_p_out[16],"%h",gen.stage_quad_out[16]);
  // $fdisplay(fidd,"%h",gen.stage_x_out[17],"%h",gen.stage_y_out[17],"%h",gen.stage_p_out[17],"%h",gen.stage_quad_out[17]);
  // $fdisplay(fidd,"%h",gen.stage_x_out[18],"%h",gen.stage_y_out[18],"%h",gen.stage_p_out[18],"%h",gen.stage_quad_out[18]);
  // $fdisplay(fidd,"%h",gen.stage_x_out[19],"%h",gen.stage_y_out[19],"%h",gen.stage_p_out[19],"%h",gen.stage_quad_out[19]);
  // $fdisplay(fidd,"%h",gen.stage_x_out[20],"%h",gen.stage_y_out[20],"%h",gen.stage_p_out[20],"%h",gen.stage_quad_out[20]);
  // $fdisplay(fidd,"%h",gen.stage_x_out[21],"%h",gen.stage_y_out[21],"%h",gen.stage_p_out[21],"%h",gen.stage_quad_out[21]);
  // $fdisplay(fidd,"%h",gen.stage_x_out[22],"%h",gen.stage_y_out[22],"%h",gen.stage_p_out[22],"%h",gen.stage_quad_out[22]);
  // $fdisplay(fidd,"%h",gen.stage_x_out[23],"%h",gen.stage_y_out[23],"%h",gen.stage_p_out[23],"%h",gen.stage_quad_out[23]);
// end
// end



// integer count;
// initial count=0;

// always@(posedge clk) begin  
  // if (ena)    
  // count=count+1;
// end
 
 always@(posedge clk) begin
  if (&cnt) begin
    //$fclose(fidd); 
   $stop; //terminate the simulation
   
  end
 end


endmodule
//end module----------
//end cordic modules








//start modules of cliping
//start_module------------------------------------------------------------
// Module Name     :  knk_clip
// Date            :  06.11.13 
// Description     :  Cliping
module knk_clip(data,q);
parameter width_in=27;
parameter width_out=24;
input [width_in-1:0] data;
output [width_out-1:0]  q;
wire [width_in-1:0]  absdata=(data[width_in-1])?-data:data;
wire [width_out-1:0] clipdata=(|absdata[width_in-1:width_out-1])?{1'b0,{(width_out-1){1'b1}}}:absdata[width_out-1:0];
wire [width_out-1:0] q=(data[width_in-1])?-clipdata:clipdata;
endmodule
//end module----------


//start_module------------------------------------------------------------
// Module Name     :  knk_mix
// Date            :  30.05.16 
// Description     :  complex signal and carier mixer
module knk_mix(clk,reset,ena,er,ei,dr,di,qr,qi,inv);
parameter width_e=16;
parameter width_d=16;
parameter width_q=16;
parameter vendor= "altera";

input  clk,reset,ena;
input  [width_e-1:0] er,ei;
input  [width_d-1:0] dr,di;
output [width_q-1:0] qr,qi;
input inv;

reg [width_e-1:0] reg_er, reg_ei;		
always@(posedge clk or posedge reset) begin 	
 if (reset) reg_er<={(width_d){1'b0}};
 else if (ena) reg_er<=er;
end
always@(posedge clk or posedge reset) begin 	
 if (reset) reg_ei<={(width_d){1'b0}};
 else if (ena) reg_ei<=ei;
end

reg [width_d-1:0] reg_dr, reg_di;		
always@(posedge clk or posedge reset) begin 	
 if (reset) reg_dr<={(width_d){1'b0}};
 else if (ena) reg_dr<=dr;
end
always@(posedge clk or posedge reset) begin 	
 if (reset) reg_di<={(width_d){1'b0}};
 else if (ena) reg_di<=di;
end

wire [width_e+width_d-1:0] mult_dr_er, mult_dr_ei, mult_di_er, mult_di_ei;



generate if (vendor=="altera") begin:gen_mult_altera

lpm_mult #(.lpm_widtha(width_e),.lpm_widthb(width_d),.lpm_widthp(width_e+width_d),.lpm_representation("SIGNED"))
mul_dr_er(.dataa(reg_er),.datab(reg_dr),.result(mult_dr_er));		

lpm_mult #(.lpm_widtha(width_e),.lpm_widthb(width_d),.lpm_widthp(width_e+width_d),.lpm_representation("SIGNED"))
mul_dr_ei(.dataa(reg_ei),.datab(reg_dr),.result(mult_dr_ei));		

lpm_mult #(.lpm_widtha(width_e),.lpm_widthb(width_d),.lpm_widthp(width_e+width_d),.lpm_representation("SIGNED"))
mul_di_er(.dataa(reg_er),.datab(reg_di),.result(mult_di_er));		

lpm_mult #(.lpm_widtha(width_e),.lpm_widthb(width_d),.lpm_widthp(width_e+width_d),.lpm_representation("SIGNED"))
mul_di_ei(.dataa(reg_ei),.datab(reg_di),.result(mult_di_ei));	

end endgenerate 
generate if (vendor=="xilinx") begin:gen_mult_xilinx 
 mult_gen_2 mul_dr_er(.A(reg_er), .B(reg_dr), .P(mult_dr_er));
 mult_gen_2 mul_dr_ei(.A(reg_ei), .B(reg_dr), .P(mult_dr_ei));
 mult_gen_2 mul_di_er(.A(reg_er), .B(reg_di), .P(mult_di_er));
 mult_gen_2 mul_di_ei(.A(reg_ei), .B(reg_di), .P(mult_di_ei));
end endgenerate 

  
 reg [width_e+width_d-1:0] rmult_dr_er, rmult_dr_ei, rmult_di_er, rmult_di_ei;
 always@(posedge clk or posedge reset) begin 	
  if (reset) begin rmult_dr_er <= 0;  rmult_dr_ei <= 0;  rmult_di_er <= 0; rmult_di_ei <= 0; end
  else begin rmult_dr_er <=mult_dr_er; rmult_dr_ei <= mult_dr_ei; rmult_di_er <= mult_di_er; rmult_di_ei <= mult_di_ei; end
 end
  
wire [width_e+width_d-1:0] sumr=(inv)? rmult_dr_er+rmult_di_ei:rmult_dr_er-rmult_di_ei;
wire [width_e+width_d-1:0] sumi=(inv)? rmult_di_er-rmult_dr_ei:rmult_dr_ei+rmult_di_er;	
   
   
wire [width_q-1:0] sumr_clip, sumi_clip;
knk_clip #(.width_in(width_q+1),.width_out(width_q)) clip_sumr(.data(sumr[width_e+width_d-1:width_e+width_d-width_q-1]),.q(sumr_clip));
knk_clip #(.width_in(width_q+1),.width_out(width_q)) clip_sumi(.data(sumi[width_e+width_d-1:width_e+width_d-width_q-1]),.q(sumi_clip));	
    
reg	[width_q-1:0] qr,qi;
always@(posedge clk or posedge reset) begin 	
 if (reset) qr<={(width_q){1'b0}};
 else if (ena) qr<=sumr_clip;
end
always@(posedge clk or posedge reset) begin 	
 if (reset) qi<={(width_q){1'b0}};
 else if (ena) qi<=sumi_clip;
end

endmodule
//end module----------



//start_module------------------------------------------------------------
// Module Name     :  knk_rx_rot
// Date            :  21.03.25 
// Description     :  rotate vector, clk = 120MHz 
// Matlab          : 
module knk_rx_rot(clk,reset,sw_on,dr,di,ph,set,qr,qi,is_tdma,pr_set_ph,pr_ph, deb_accum_ph, st_pkt, st_pkt_del,sclr, deb_is_pr); 
parameter vendor="xilinx";
input clk, reset;
input [15:0] dr,di;
input [31:0] ph;
input set;
input sw_on; 
output [15:0] qr,qi;
input is_tdma;
input pr_set_ph;
input [31:0] pr_ph;
output [31:0] deb_accum_ph;
input st_pkt;
output st_pkt_del;
input sclr;

input deb_is_pr;

//reg [31:0] reg_ph;
//always@(posedge clk or posedge reset) begin 	
// if (reset) reg_ph <= 0;
// else if (set) reg_ph <= ph;
//end

reg [31:0] accum_ph;
assign deb_accum_ph = accum_ph;
always@(posedge clk or posedge reset) begin 	
if (reset) accum_ph<=0;

//else if (sclr)

else if (is_tdma&pr_set_ph) accum_ph <= pr_ph;

//else accum_ph<=accum_ph + {{(4){reg_ph[31]}},reg_ph}; 

else if (set) 
//accum_ph<=accum_ph+{{(1){ph[31]}},ph[31:1]};

accum_ph<=accum_ph+ph;

//if ((ph[31:28]==4'h0)|(ph[31:28]==4'hf)) accum_ph<=accum_ph+{ph[28:0],3'b0};
//else if ((ph[31:29]==3'h0)|(ph[31:29]==3'h7)) accum_ph<=accum_ph+{ph[29:0],2'b0};
//else if ((ph[31:30]==2'h0)|(ph[31:30]==2'h3)) accum_ph<=accum_ph+{ph[30:0],1'b0};
//else accum_ph<=accum_ph+ph;

end

reg set_cor;
always@(posedge clk or posedge reset) begin 	
 if (reset) set_cor<=0;
 else if (set) set_cor<=1'b1;
 else if (is_tdma&pr_set_ph) set_cor<=1'b1;
 else set_cor<=1'b0;
end

//wire set_cor = 1'b1;


wire [17:0] er, ei;
wire [15:0] mix_qr,mix_qi;
knk_cordic #(.width(18),.section(16)) gen(.clk(clk),.reset(reset),.ena(1'b1),.set(set_cor),.f_in(accum_ph),.x_f_in(er),.y_f_in(ei),.set_p(1'b1));
knk_mix  #(.vendor(vendor))   mix(.clk(clk),.reset(reset),.ena(1'b1),.er(er[17:2]),.ei(ei[17:2]),.dr(dr),.di(di),.qr(mix_qr),.qi(mix_qi),.inv(1'b1));

reg st_pkt_del;
reg [2:0] del_st;
always@(posedge clk or posedge reset) begin 	
 if (reset) del_st<=0;
 else begin del_st[0]<=st_pkt; del_st[1]<=del_st[0]; del_st[2]<=del_st[1]; end end



reg [15:0] qr,qi;
always@(posedge clk or posedge reset) begin 	
 if (reset) begin qr<=0; qi<=0; end
 else if (sw_on) begin qr<=mix_qr; qi<=mix_qi; st_pkt_del<=del_st[2]; end  // mix delay 3 tacts
 else begin qr<=dr; qi<=di; st_pkt_del<=st_pkt; end end
 
 
 /*
 ila_knk_rot your_instance_name (
	.clk(clk), // input wire clk


	.probe0(ph), // input wire [31:0]  probe0  
	.probe1(set), // input wire [0:0]  probe1 
	.probe2(pr_ph), // input wire [31:0]  probe2 
	.probe3(pr_set_ph), // input wire [0:0]  probe3 
	.probe4(accum_ph), // input wire [31:0]  probe4 
	.probe5(set_cor), // input wire [0:0]  probe5 
	.probe6(deb_is_pr) // input wire [0:0]  probe6
);
 
 */
 
 
 
 
 
 
 
endmodule
//end module----------






//start_module------------------------------------------------------------
// Module Name     :  knk_rx_del
// Date            :  17.04.25 
// Description     :  delay input sample, clk = 120MHz 
// Matlab          : 
module knk_rx_del(clk,reset,dr,di,del,qr,qi,lock_pr, set_ph, ph, set_gardner,tmp_deb_pream,cor_sh_ad); 
parameter vendor="xilinx";
//parameter cor_sh_ad = 10'd727;
input clk, reset;
input [15:0] dr,di;
input [9:0] del, cor_sh_ad;
output [15:0] qr,qi;
input lock_pr;
output set_ph;
output [31:0] ph;
output set_gardner;
input tmp_deb_pream;

reg [9:0] wad, rad;
always@(posedge clk or posedge reset) begin 	
 if (reset) wad <= 0; 
 else wad <= wad + 1; end

reg [5:0] cnt;
always@(posedge clk or posedge reset) begin 	
 if (reset) cnt<=6'd63;
 else if (lock_pr)  cnt<=0;
 else if (~&cnt) cnt<=cnt+1; end

reg [9:0] st_wad;
always@(posedge clk or posedge reset) begin 	
 if (reset) st_wad<=0;
 else if (lock_pr) st_wad<=wad - cor_sh_ad; end


always@(posedge clk or posedge reset) begin 	
if (reset) rad <= 0;
else if (cnt < 6'd16) case (cnt[3:0])
6'd0: rad <= st_wad;
6'd1: rad <= st_wad +10'd40;
6'd2: rad <= st_wad +10'd80;
6'd3: rad <= st_wad +10'd120;
6'd4: rad <= st_wad +10'd160;
6'd5: rad <= st_wad +10'd200;
6'd6: rad <= st_wad +10'd240;
6'd7: rad <= st_wad +10'd280;
6'd8: rad <= st_wad +10'd320;
6'd9: rad <= st_wad +10'd360;
6'd10:rad <= st_wad +10'd400;
6'd11:rad <= st_wad +10'd440;
6'd12:rad <= st_wad +10'd480;
6'd13:rad <= st_wad +10'd520;
6'd14:rad <= st_wad +10'd560;
6'd15:rad <= st_wad +10'd600;
endcase else rad <= wad - del; end

wire [31:0] del_mem_q;
reg [15:0] x,y;
always@(posedge clk or posedge reset) begin 	
if (reset) {x,y} <= 0;
else if((cnt>1)&(cnt<18)) {x,y}<=del_mem_q;
else {x,y} <= 0; end

wire [31:0] p;
wire [15:0] r;
knk_cordic_polar #(.width(16)) cordic_polar(.clk(clk),.reset(reset),.ena(1'b1),.x_in(x),.y_in(y) ,.p_out(p), .r_out(r));

wire [31:0] ph_0  = 32'he0000000;
wire [31:0] ph_1  = 32'he0000000;
wire [31:0] ph_2  = 32'he0000000;
wire [31:0] ph_3  = 32'h40000000;
wire [31:0] ph_4  = 32'hc0000000;
wire [31:0] ph_5  = 32'h20000000;
wire [31:0] ph_6  = 32'h40000000;
wire [31:0] ph_7  = 32'h60000000;
wire [31:0] ph_8  = 32'h20000000;
wire [31:0] ph_9  = 32'hc0000000;
wire [31:0] ph_10 = 32'h80000000;
wire [31:0] ph_11 = 32'h60000000;
wire [31:0] ph_12 = 32'h60000000;
wire [31:0] ph_13 = 32'h60000000;
wire [31:0] ph_14 = 32'ha0000000;
wire [31:0] ph_15 = 32'h40000000;



reg [31:0] dp;
wire [31:0] adp = (dp[31])?~dp+32'd1:dp;
reg [35:0] ap;
reg [36:0] apz;
always@(posedge clk or posedge reset) begin 	
if (reset) dp <=0;
else case (cnt)
6'd20: dp <= p - ph_0 ;
6'd21: dp <= p - ph_1 ;
6'd22: dp <= p - ph_2 ;
6'd23: dp <= p - ph_3 ;
6'd24: dp <= p - ph_4 ;
6'd25: dp <= p - ph_5 ;
6'd26: dp <= p - ph_6 ;
6'd27: dp <= p - ph_7 ;
6'd28: dp <= p - ph_8 ;
6'd29: dp <= p - ph_9 ;
6'd30: dp <= p - ph_10;
6'd31: dp <= p - ph_11;
6'd32: dp <= p - ph_12;
6'd33: dp <= p - ph_13;
6'd34: dp <= p - ph_14;
6'd35: dp <= p - ph_15;
default:dp<=0;
endcase end


reg is_arz;
always@(posedge clk or posedge reset) begin 	
if (reset) is_arz <= 0;
else if (cnt == 6'd20) is_arz <= 0;
else if (cnt == 6'd21) is_arz <= (adp < 32'h40000000);
else if (cnt < 6'd37) is_arz <= is_arz&(adp < 32'h40000000); end

always@(posedge clk or posedge reset) begin 	
if (reset) ap<=0;
else if (cnt == 6'd20) ap<=0;
else if (cnt < 6'd37) ap<=ap + { {(4){1'b0}} ,dp}; end


always@(posedge clk or posedge reset) begin 	
if (reset) apz<=0;
else if (cnt == 6'd20) apz<=0;
else if (cnt < 6'd37) apz<=apz + { {(4){1'b0}} ,~dp[31],dp}; end


wire set_ph = (cnt == 6'd38);
wire set_gardner = (cnt == 6'd60);
reg [31:0] ph;
always@(posedge clk or posedge reset) begin 	
if (reset) ph<=0;
else if (cnt == 6'd37) ph <= (is_arz)?apz[35:4]:ap[35:4]; end


blk_mem_gen_1 del_mem(
  .clka(clk),    // input wire clka
  .wea(1'b1),      // input wire [0 : 0] wea
  .addra(wad),  // input wire [9 : 0] addra
  .dina({dr,di}),    // input wire [31 : 0] dina
  .clkb(clk),    // input wire clkb
  .addrb(rad),  // input wire [9 : 0] addrb
  .doutb(del_mem_q)  // output wire [31 : 0] doutb
);



reg [15:0] qr, qi;
always@(posedge clk or posedge reset) begin 	
 if (reset) {qr,qi}<=0;
 else {qr,qi}<=del_mem_q; end
 

/*
 
ila_14 pream_ph (
	.clk(clk), // input wire clk
	.probe0(lock_pr), // input wire [0:0]  probe0  
	.probe1(cnt), // input wire [5:0]  probe1 
	.probe2(rad), // input wire [9:0]  probe2 
	.probe3(x), // input wire [15:0]  probe3 
	.probe4(y), // input wire [15:0]  probe4 
	.probe5(p), // input wire [31:0]  probe5 
	.probe6(ap), // input wire [35:0]  probe6 
	.probe7(dp), // input wire [31:0]  probe7 
	.probe8(ph), // input wire [31:0]  probe8 
	.probe9(set_ph), // input wire [0:0]  probe9 
	.probe10(set_gardner), // input wire [0:0]  probe10
    .probe11(apz), // input wire [36:0]  probe11 
	.probe12(is_arz), // input wire [0:0]  probe12
    .probe13(tmp_deb_pream), // input wire [0:0]  probe13
	.probe14(r) // input wire [15:0]  probe14
);
*/

endmodule
//end module----------






//start_module------------------------------------------------------------
// Module Name     :  knk_gardner_sync_stimulus
// Date            :  05.02.25 
// Description     :  
// Matlab          :  
module knk_gardner_sync_stimulus();

reg clk,reset;  
initial clk = 1'b1;
initial begin
reset=1;
#100 reset=0; 
end

always #8 clk = ~clk; 

reg [31:0] d;
wire [15:0] dr,di;
wire [31:0] q;
assign dr={d[23:16],d[31:24]};
assign di={d[7:0],d[15:8]};
integer fid, result,res_dem;
initial fid=$fopen("D:/knk_pkrv_2024/QtPrj/build-com_debug-Desktop_Qt_5_12_9_MinGW_32_bit-Debug/test.dat","rb");
initial result=$fopen("D:/knk_pkrv_2024/QtPrj/build-com_debug-Desktop_Qt_5_12_9_MinGW_32_bit-Debug/result.dat","wb");
initial res_dem=$fopen("D:/knk_pkrv_2024/QtPrj/build-com_debug-Desktop_Qt_5_12_9_MinGW_32_bit-Debug/res_dem.dat","wb");


wire [15:0] qr, qi;
wire qena;
assign q={qi[15:8],qi[7:0],qr[15:8],qr[7:0]};


wire [15:0] qsr, qsi;
wire qsena;
wire [31:0] dem_q;
wire [31:0] rotr,roti;
assign dem_q={qsi[15:8],qsi[7:0],qsr[15:8],qsr[7:0]};
//assign dem_q={roti[31:16],rotr[31:16]};


reg [31:0] cnt;
always@(posedge clk or posedge reset) begin 
if (reset) begin d<=0; cnt<=0; end
else begin 
cnt<=cnt+1;
if (cnt >= 25000*40) begin
 d<=0;
 $fclose(fid);
 $fclose(result);
 $fclose(res_dem);
 $stop; //terminate the simulation
end else begin
 $fread(d,fid);  
 if (qena) $fwrite(result,"%U",q[31:0]);
 if (qsena) $fwrite(res_dem,"%U",dem_q[31:0]);
end

end
end
wire [2:0] sym;
wire [15:0] rot_qr,rot_qi;
knk_rx_rot #(.vendor("altera")) rot(.clk(clk),.reset(reset),.sw_on(1'b1),.dr(dr),.di(di),.ph(roti),.set(qsena),.qr(rot_qr),.qi(rot_qi)); 
knk_gardner_sync #(.vendor("altera")) gardner_sync(.clk(clk),.reset(reset),.dr(rot_qr),.di(rot_qi),.qr(qr),.qi(qi),.qena(qena),.pkt_length(15'd24000));
knk_demaper_8psk   #(.vendor("altera")) demaper_8psk(.clk(clk),.reset(reset),.sr(qr),.si(qi),.sena(qena), .sym(sym), .qsr(qsr),.qsi(qsi),.qr(rotr),.qi(roti),.qena(qsena));


endmodule
//end module----------


//start_module------------------------------------------------------------
// Module Name     :  knk_rx_pr_bin
// Date            :  04.03.25 
// Description     :  finding binary preamble, rotate symbol, speed 3MBod, clk = 120MHz 
// Matlab          : D:\knk_pkrv_2024\ModelSimPrj\knk_pkrv_modem\Matlab\test_pkt_sync.m   -> preamble
module knk_rx_pr_bin(clk,reset,sym,sym_ena,q,qena, q_32b_stbv,q_32b_stbl,q_32b_d, pkt_sym);
parameter mis_bit=3;
//parameter pkt_sym = 15'd24000;  
input clk,reset;
input [2:0] sym;
input sym_ena;
output [2:0] q;
output qena;
output  q_32b_stbv,q_32b_stbl;
output [31:0] q_32b_d;
input [15:0] pkt_sym;

reg [15:0] cnt_sym_pkt;

reg [2:0] rs, s, sub_s;
reg [44:0] sub_pr;
reg [47:0] pr, epr;
always@(posedge clk or posedge reset) begin 	
 if (reset) begin s<=0; rs<=0; sub_s<=0; sub_pr<=0;pr<=0; end
 else if (sym_ena) begin s<=sym; rs<=s; sub_s<=rs-s; sub_pr<={sub_pr[41:0],sub_s}; pr<={pr[44:0],rs}; end
end 

reg [5:0] cnt;
always@(posedge clk or posedge reset) begin 	
 if (reset) cnt<=0;
 else if (sym_ena) cnt<=0;
 else if (cnt<6'd35) cnt<=cnt+1;
end

reg [2:0] rot, sym_rot,q;
reg qena;
reg  [4:0] in_cnt_bits, w2_cnt, w1_cnt, w0_cnt;
reg  [5:0] ac_cnt_bits;
wire [4:0] cnt_bits={4'd0,in_cnt_bits[0]}+{4'd0,in_cnt_bits[1]}+{4'd0,in_cnt_bits[2]}+{4'd0,in_cnt_bits[3]}+{4'd0,in_cnt_bits[4]};

reg [44:0] xor_sub_pr;
reg is_pr;
always@(posedge clk or posedge reset) begin 	
 if (reset) begin xor_sub_pr<=0; in_cnt_bits<=0; ac_cnt_bits<=0; is_pr<=0; epr<=0; w2_cnt<=0; w1_cnt<=0; w0_cnt<=0; rot<=0; sym_rot<=0; q<=0; qena<=0; end
 else case (cnt) 
 6'd0:  xor_sub_pr<=sub_pr^{3'd0,3'd0,3'd5,3'd4,3'd5,3'd7,3'd7,3'd2,3'd3,3'd2,3'd1,3'd0,3'd0,3'd6,3'd3};
 6'd1:        in_cnt_bits<=xor_sub_pr[4:0];
 6'd2:  begin in_cnt_bits<=xor_sub_pr[9:5];   ac_cnt_bits<={1'b0,cnt_bits};             end
 6'd3:  begin in_cnt_bits<=xor_sub_pr[14:10]; ac_cnt_bits<={1'b0,cnt_bits}+ac_cnt_bits; end
 6'd4:  begin in_cnt_bits<=xor_sub_pr[19:15]; ac_cnt_bits<={1'b0,cnt_bits}+ac_cnt_bits; end
 6'd5:  begin in_cnt_bits<=xor_sub_pr[24:20]; ac_cnt_bits<={1'b0,cnt_bits}+ac_cnt_bits; end
 6'd6:  begin in_cnt_bits<=xor_sub_pr[29:25]; ac_cnt_bits<={1'b0,cnt_bits}+ac_cnt_bits; end
 6'd7:  begin in_cnt_bits<=xor_sub_pr[34:30]; ac_cnt_bits<={1'b0,cnt_bits}+ac_cnt_bits; end
 6'd8:  begin in_cnt_bits<=xor_sub_pr[39:35]; ac_cnt_bits<={1'b0,cnt_bits}+ac_cnt_bits; end
 6'd9:  begin in_cnt_bits<=xor_sub_pr[44:40]; ac_cnt_bits<={1'b0,cnt_bits}+ac_cnt_bits; end
 6'd10: ac_cnt_bits<={1'b0,cnt_bits}+ac_cnt_bits;
 //6'd11: begin is_pr<=(ac_cnt_bits<=mis_bit)&(cnt_sym_pkt >= 16'd24015); epr <={pr[47:45]-3'd7, pr[44:42]-3'd7, pr[41:39]-3'd7, pr[38:36]-3'd2,
 6'd11: begin is_pr<=(ac_cnt_bits<=mis_bit)&(cnt_sym_pkt >= pkt_sym + 16'd15); epr <={pr[47:45]-3'd7, pr[44:42]-3'd7, pr[41:39]-3'd7, pr[38:36]-3'd2,
                                                    pr[35:33]-3'd6, pr[32:30]-3'd1, pr[29:27]-3'd2, pr[26:24]-3'd3,
                                                    pr[23:21]-3'd1, pr[20:18]-3'd6, pr[17:15]-3'd4, pr[14:12]-3'd3,
                                                    pr[11:9]-3'd3,  pr[8:6]-3'd3,   pr[5:3]-3'd5,   pr[2:0]-3'd2};
        end
 6'd12:       in_cnt_bits<={epr[47],epr[44],epr[41],epr[38],epr[35]};
 6'd13: begin in_cnt_bits<={epr[32],epr[29],epr[26],epr[23],epr[20]};   ac_cnt_bits<={1'b0,cnt_bits};                                                       end
 6'd14: begin in_cnt_bits<={epr[17],epr[14],epr[11],epr[8], epr[5]};    ac_cnt_bits<={1'b0,cnt_bits}+ac_cnt_bits;                                           end
 6'd15: begin in_cnt_bits<={epr[46],epr[43],epr[40],epr[37],epr[34]};   ac_cnt_bits<={1'b0,cnt_bits}+ac_cnt_bits;                                           end 
 6'd16: begin in_cnt_bits<={epr[31],epr[28],epr[25],epr[22],epr[19]};   ac_cnt_bits<={1'b0,cnt_bits};             w2_cnt<= ac_cnt_bits[4:0]+{4'd0,epr[2]};  end
 6'd17: begin in_cnt_bits<={epr[16],epr[13],epr[10],epr[7], epr[4]};    ac_cnt_bits<={1'b0,cnt_bits}+ac_cnt_bits;                                           end 
 6'd18: begin in_cnt_bits<={epr[45],epr[42],epr[39],epr[36], epr[33]};  ac_cnt_bits<={1'b0,cnt_bits}+ac_cnt_bits;                                           end 
 6'd19: begin in_cnt_bits<={epr[30],epr[27],epr[24],epr[21],epr[18]};   ac_cnt_bits<={1'b0,cnt_bits};             w1_cnt<= ac_cnt_bits[4:0]+{4'd0,epr[1]};  end
 6'd20: begin in_cnt_bits<={epr[15],epr[12],epr[9],epr[6], epr[3]};     ac_cnt_bits<={1'b0,cnt_bits}+ac_cnt_bits;                                           end 
 6'd21:       ac_cnt_bits<={1'b0,cnt_bits}+ac_cnt_bits;  
 6'd22:                                                                                                            w0_cnt<= ac_cnt_bits[4:0]+{4'd0,epr[0]}; 
 6'd23: if (is_pr) rot<={(w2_cnt>8),(w1_cnt>8), (w0_cnt>8)};
 6'd24: sym_rot<=rs-rot;
 6'd25: if (sym_rot == 3'b000) q <= 3'b001; 
 6'd26: if (sym_rot == 3'b001) q <= 3'b000; 
 6'd27: if (sym_rot == 3'b010) q <= 3'b100; 
 6'd28: if (sym_rot == 3'b011) q <= 3'b110; 
 6'd29: if (sym_rot == 3'b100) q <= 3'b010; 
 6'd30: if (sym_rot == 3'b101) q <= 3'b011; 
 6'd31: if (sym_rot == 3'b110) q <= 3'b111; 
 6'd32: if (sym_rot == 3'b111) q <= 3'b101; 
 6'd33: qena<=1;
 6'd34: begin qena<=0; is_pr<=0;   end
 
endcase
end

reg [47:0] q_48b_d, rq_48b_d;
reg [31:0] q_32b_d;
reg q_32b_stbv,q_32b_stbl,q_32b_stbs;
reg q_48b_v, q_48b_s, q_48b_l;
reg [3:0] cnt_3bits;
reg [2:0] rq;
//reg [15:0] cnt_sym_pkt;
always@(posedge clk or posedge reset) begin 	
if (reset) begin q_48b_v<=0; q_48b_s<=0; q_48b_l<=0; q_48b_d<=0; cnt_3bits<=0; rq<=0; cnt_sym_pkt<=16'd24016; q_32b_d<=0; q_32b_stbv<=0; q_32b_stbl<=0; rq_48b_d<=0; q_32b_stbs<=0; end
else if (qena) begin
 rq<=q;
if (is_pr) begin
 q_48b_d <=48'hb6ce261d6d9c;
 q_48b_v<=1;
 q_48b_s<=1;
 cnt_3bits<=0;
 cnt_sym_pkt<=16'd16;
end else begin
 q_48b_d <= {q_48b_d[44:0],rq};

 if (cnt_3bits==0) rq_48b_d<=q_48b_d;
 
 cnt_3bits<=cnt_3bits+1;
 q_48b_v<=&cnt_3bits;
 //if (cnt_sym_pkt<16'd24016) cnt_sym_pkt<=cnt_sym_pkt+1;
 //q_48b_l<=(cnt_sym_pkt==16'd23999);
 //if  (cnt_sym_pkt[4]&(cnt_3bits==1)) begin q_32b_d<=rq_48b_d[47:16];                   q_32b_stbv<=~(cnt_sym_pkt==16'd24016);  q_32b_stbs<=(cnt_sym_pkt==16'd17);      end
 //else if  (cnt_sym_pkt[4]&(cnt_3bits==8)) begin q_32b_d<={rq_48b_d[15:0],16'd0};                                                                                            end
 //else if (~cnt_sym_pkt[4]&(cnt_3bits==1)) begin q_32b_d<={q_32b_d[31:16],rq_48b_d[47:32]};  q_32b_stbv<=~(cnt_sym_pkt==16'd24016);                                          end
 //else if (~cnt_sym_pkt[4]&(cnt_3bits==8)) begin q_32b_d<=rq_48b_d[31:0];                    q_32b_stbv<=~(cnt_sym_pkt==16'd24016);  q_32b_stbl<=(cnt_sym_pkt==16'd24008);   end
 
 if (cnt_sym_pkt<(pkt_sym+16'd16)) cnt_sym_pkt<=cnt_sym_pkt+1;
 else cnt_sym_pkt<=pkt_sym+16'd16;
 
 
 
 q_48b_l<=(cnt_sym_pkt==pkt_sym-1);
      if  (cnt_sym_pkt[4]&(cnt_3bits==1)) begin q_32b_d<=rq_48b_d[47:16];                   q_32b_stbv<=~(cnt_sym_pkt==(pkt_sym+16'd16));  q_32b_stbs<=(cnt_sym_pkt==16'd17);           end
 else if  (cnt_sym_pkt[4]&(cnt_3bits==8)) begin q_32b_d<={rq_48b_d[15:0],16'd0};                                                                                                        end
 else if (~cnt_sym_pkt[4]&(cnt_3bits==1)) begin q_32b_d<={q_32b_d[31:16],rq_48b_d[47:32]};  q_32b_stbv<=~(cnt_sym_pkt==(pkt_sym+16'd16));                                               end
 else if (~cnt_sym_pkt[4]&(cnt_3bits==8)) begin q_32b_d<=rq_48b_d[31:0];                    q_32b_stbv<=~(cnt_sym_pkt==(pkt_sym+16'd16));  q_32b_stbl<=(cnt_sym_pkt==(pkt_sym+16'd8));  end
 else  begin q_32b_stbv<=0; q_32b_stbl<=0; q_32b_stbs<=0; end
 
 end end else begin
 q_48b_v<=0;
 q_48b_s<=0;
 q_48b_l<=0;
end end

/*
ila_6 pr_bits (
	.clk(clk), // input wire clk
	.probe0(sym_ena), // input wire [0:0]  probe0  
	.probe1(sym), // input wire [2:0]  probe1 
	.probe2(s), // input wire [2:0]  probe2 
	.probe3(sr), // input wire [2:0]  probe3 
	.probe4(sub_pr), // input wire [44:0]  probe4 
	.probe5(pr), // input wire [47:0]  probe5 
	.probe6(xor_sub_pr), // input wire [44:0]  probe6 
	.probe7(is_pr), // input wire [0:0]  probe7
	.probe8(epr), // input wire [47:0]  probe8 
	.probe9(w2_cnt), // input wire [4:0]  probe9 
	.probe10(w1_cnt), // input wire [4:0]  probe10 
	.probe11(w0_cnt), // input wire [4:0]  probe11 
    .probe12(rot), // input wire [2:0]  probe12 
    .probe13(q), // input wire [2:0]  probe13 
    .probe14(qena), // input wire [0:0]  probe14 
    .probe15(q_48b_v), // input wire [0:0]  probe15 
    .probe16(q_48b_s), // input wire [0:0]  probe16  
    .probe17(q_48b_l), // input wire [0:0]  probe17 
    .probe18(cnt_3bits), // input wire [3:0]  probe18 
    .probe19(q_48b_d), // input wire [47:0]  probe19 
    .probe20(cnt_sym_pkt), // input wire [15:0]  probe20 
    .probe21(q_32b_stbv), // input wire [0:0]  probe21 
    .probe22(q_32b_stbl), // input wire [0:0]  probe22 
    .probe23(q_32b_d), // input wire [31:0]  probe23 
    .probe24(q_32b_stbs) // input wire [0:0]  probe24 
);
*/

endmodule
//end module----------






//start_module------------------------------------------------------------
// Module Name     :  knk_rx_bin
// Date            :  20.10.25 
// Description     :  clk = 120MHz 
// Matlab          : 
module knk_rx_bin(clk,res,  sym,sym_ena,sym_start, sym_last,   typ_mod, w, wena, wstart, wlast);  

input clk,res;
input [2:0] sym;
input sym_ena, sym_start, sym_last;
input [1:0] typ_mod;

output  wena, wstart, wlast;
output [31:0] w;

reg s_bpsk;
reg [1:0] s_qpsk;
reg [2:0] s_8psk;
reg s_ena, s_start, s_last;

 always@(posedge clk or posedge res) begin 	
  if (res) begin  s_ena<=0;  s_start<=0;  s_last<=0; s_8psk<=0; s_qpsk<=0; s_qpsk<=0; end
  else if (sym_ena) begin
     if (typ_mod == 2'd2) case (sym)
	  3'b000:  s_8psk<= 3'b001;
	  3'b001:  s_8psk<= 3'b000;
	  3'b010:  s_8psk<= 3'b100;
	  3'b011:  s_8psk<= 3'b110;
	  3'b100:  s_8psk<= 3'b010;
	  3'b101:  s_8psk<= 3'b011;
	  3'b110:  s_8psk<= 3'b111;
	  3'b111:  s_8psk<= 3'b101;
	 endcase 
  
     if (typ_mod == 2'd1) case (sym)
	  3'b001:  s_qpsk<= 2'b00;
	  3'b011:  s_qpsk<= 2'b01;
	  3'b101:  s_qpsk<= 2'b11;
	  3'b111:  s_qpsk<= 2'b10;
	  default: s_qpsk<= 2'b00;
	 endcase 
  
     if (typ_mod == 2'd0) case (sym)
	  3'b000:  s_bpsk<= 1'b0;
	  3'b100:  s_bpsk<= 1'b1;
	  default: s_bpsk<= 1'b0;
	 endcase 
  
   s_ena<=1; s_start<=sym_start;  s_last<=sym_last;
  
  end else begin
  s_ena<=0; s_start<=0;  s_last<=0;
end end  
  
reg [31:0] sh, w;
reg wena,wlast,wstart,mstart;
reg [5:0] cnt_b;
reg m_last;

 always@(posedge clk or posedge res) begin 	
  if (res) begin  sh<=0; w<=0; wena<=0; cnt_b<=0; wlast<=0; wstart<=0; m_last<=0; mstart<=0; end
  else if (s_start) begin
  
  if (typ_mod == 2'd2) begin sh[2:0]<=s_8psk; cnt_b<=6'd3; end
  if (typ_mod == 2'd1) begin sh[1:0]<=s_qpsk; cnt_b<=6'd2; end
  if (typ_mod == 2'd0) begin sh[0]<=s_bpsk;   cnt_b<=6'd1; end
  mstart<=1;
  end 
  else if ((typ_mod == 2'd0)&s_ena) begin
     if (cnt_b + 6'd1 == 6'd32) begin 
	  cnt_b<=6'd0;
	  sh<=32'd0;
      w<={sh[30:0],s_bpsk};
	  wena<=1; wstart<=mstart; mstart<=0;
	  wlast<=s_last;
	 end
	 else begin 
	  cnt_b<=cnt_b+6'd1; 
	  sh<={sh[30:0],s_bpsk};
	  m_last<=s_last;
	 end
  end  
  
    else if ((typ_mod == 2'd1)&s_ena) begin
     if (cnt_b + 6'd2 == 6'd32) begin 
	  cnt_b<=6'd0;
	  sh<=32'd0;
      w<={sh[29:0],s_qpsk};
	  wena<=1;wstart<=mstart; mstart<=0;
	  wlast<=s_last;
	 end
	 else begin 
	  cnt_b<=cnt_b+6'd2; 
	  sh<={sh[29:0],s_qpsk};
	  m_last<=s_last;
	 end
  end  
  
      else if ((typ_mod == 2'd2)&s_ena) begin
	  
     if (cnt_b + 6'd3 >= 6'd32) begin 
	  
	  if (cnt_b + 6'd3 == 6'd32) begin
	   cnt_b<=6'd0;
	   sh<=32'd0;
       w<={sh[28:0],s_8psk};
	   wlast<=s_last; end
      else if (cnt_b + 6'd3 == 6'd33) begin 
	   cnt_b<=6'd1;
	   sh<={31'd0,s_8psk[0]};
       w<={sh[29:0],s_8psk[2:1]}; 
	   m_last<=s_last; end
      else if (cnt_b + 6'd3 == 6'd34) begin 
	   cnt_b<=6'd2;
	   sh<={30'd0,s_8psk[1:0]};
       w<={sh[30:0],s_8psk[2]}; 
	   m_last<=s_last; end
	   
	  wena<=1;wstart<=mstart; mstart<=0;
	  
	 end
	 else begin 
	  cnt_b<=cnt_b+6'd3; 
	  sh<={sh[28:0],s_8psk};
	  m_last<=s_last;
	 end
  end 
     
  
  else if (m_last) begin
       
	   if (cnt_b<6'd32) begin
	    cnt_b<=cnt_b+1; sh<={sh[30:0],1'b0};
	    wena<=0; wlast<=0; wstart<=0; 
	   end else begin  w<=sh; wena<=1; wlast<=1; m_last<=0;  end end
  
   else  begin    wena<=0; wlast<=0; wstart<=0;         end
  
  
  end
 
 
/*
 
 ila_knk_rx_bin your_instance_name (
	.clk(clk), // input wire clk


	.probe0(sym), // input wire [2:0]  probe0  
	.probe1(sym_ena), // input wire [0:0]  probe1 
	.probe2(sym_last), // input wire [0:0]  probe2 
	.probe3(sym_start), // input wire [0:0]  probe3 
	.probe4(typ_mod), // input wire [2:0]  probe4 
	.probe5(w), // input wire [31:0]  probe5 
	.probe6(wena), // input wire [0:0]  probe6 
	.probe7(wstart), // input wire [0:0]  probe7 
	.probe8(wlast), // input wire [0:0]  probe8 
	.probe9(s_8psk), // input wire [2:0]  probe9 
	.probe10(s_qpsk), // input wire [1:0]  probe10 
	.probe11(s_bpsk), // input wire [0:0]  probe11 
	.probe12(s_ena), // input wire [0:0]  probe12 
	.probe13(s_last), // input wire [0:0]  probe13 
	.probe14(s_start), // input wire [0:0]  probe14 
	.probe15(sh), // input wire [31:0]  probe15 
	.probe16(cnt_b), // input wire [5:0]  probe16 
	.probe17(m_last) // input wire [0:0]  probe17
);
 */
 
 
endmodule
//end module----------











//start_module------------------------------------------------------------
// Module Name     :  knk_word32_scramb
// Date            :  14.03.25 
// Description     :  scrambler
module knk_word32_scr(clk, res,  d, dena, dlast, dstart, sw_on , q, q_v, q_l, q_st, is_pr); 
parameter out_stb_duty = 3;
input clk,res;
input [31:0] d;
input dena, dlast, dstart;
input sw_on;

output [31:0] q;
output q_v, q_l, q_st;

output is_pr; //debug

reg is_pr, is_val, is_st, is_l;
reg [31:0] rd;
reg [15:0] cnt_d;

always @ (posedge clk or posedge res)
 begin if (res) begin is_pr<=0; rd<=0; is_val<=0;  end
 else if (dena) begin is_pr<=(cnt_d == 16'd0)&({rd,d[31:16]} != 48'hb6ce261d6d9c); rd<=d; is_val<=1; end
 else begin is_pr<=0; is_val<=0; end 
end

always @ (posedge clk or posedge res)
 begin if (res) begin is_st<=0; is_l<=0; end
 else begin is_st<=dstart; is_l<=dlast; end end


reg m_cnt;
always @(posedge clk or posedge res)
begin
 if (res) begin cnt_d<=0; m_cnt<=0; end
 else if (is_st) begin   cnt_d<=0; m_cnt<=1; end
 else if (is_l) m_cnt<=0;
 else if (m_cnt&is_val) cnt_d<=cnt_d+1; end
   
wire mrand=m_cnt; 

reg [5:0] cnt_ena;
wire ena_sh=~(cnt_ena == 32);

always @ (posedge clk or posedge res)
 begin if (res) cnt_ena<=32;
 else if (is_st) cnt_ena<=16;
 else if (is_val&mrand) cnt_ena<=0;
 else if (ena_sh) cnt_ena<=cnt_ena+1;
end

reg [1:0] en_rand;
always @ (posedge clk or posedge res)
 begin if (res) en_rand<=0;
 else if (cnt_ena==6'd15) en_rand[1]<=1;
 else if (cnt_ena==6'd31) en_rand[0]<=1;
 else en_rand<=0;
end

wire [15:0] rw;
knk_rand_16 rand_16(.clk(clk),.res(res),.ini(is_st),.ena(ena_sh),.r(rw));

wire [15:0] rev_rw;
knk_data_reverse #(.width(16)) rev(.data(rw),.q(rev_rw));

reg [31:0] rand;
always @ (posedge clk or posedge res)
 begin if (res) rand<=0;
 
 else if ((cnt_d == 0)&en_rand[0]) rand<={16'd0,rev_rw};
 else if (mrand&en_rand[1]) rand<={rev_rw,16'd0};
 else if (mrand&en_rand[0]) rand<={rand[31:16],rev_rw};
 else if(~mrand) rand<=0;
end
 
 
reg [31:0] q;
reg q_v, q_l, q_st;
reg [1:0] stb;



generate if (out_stb_duty==3) begin:gen_stb_duty_3

always @ (posedge clk or posedge res)
 begin if (res) begin q <= 0; q_v<=0; q_l<=0; stb<=2'b11; q_st<=0; end
 else if(&stb&is_val&(is_st|m_cnt)) begin q <=(sw_on)?d^rand:d;  q_v<=1; q_l<=is_l; stb<=0; q_st<=is_st;  end
 else if (~&stb) stb<=stb+1;
 else  begin q_v<=0; q_l<=0; q_st<=0; end
end

end endgenerate 

generate if (out_stb_duty==1) begin:gen_stb_duty_1

always @ (posedge clk or posedge res)
 begin if (res) begin q <= 0; q_v<=0; q_l<=0; q_st<=0; end
 else if(is_val&(is_st|m_cnt)) begin q <=(sw_on)?d^rand:d; q_v<=1; q_l<=is_l; q_st<=is_st;  end
 else  begin q_v<=0; q_l<=0; q_st<=0; end
end

end endgenerate 




/*
ila_9 rx_scramb (
	.clk(clk), // input wire clk
	.probe0(m_cnt), // input wire [0:0]  probe0  
	.probe1(is_st), // input wire [0:0]  probe1 
	.probe2(is_val), // input wire [0:0]  probe2 
	.probe3(rev_rw), // input wire [15:0]  probe3
    .probe4(cnt_d), // input wire [15:0]  probe4
	.probe5(d), // input wire [31:0]  probe5
    .probe6(q), // input wire [31:0]  probe6
    .probe7(q_v), // input wire [0:0]  probe7
    .probe8(q_l), // input wire [0:0]  probe8
	.probe9(is_pr) // input wire [0:0]  probe9
);
*/

endmodule
//end module----------









































//start_module------------------------------------------------------------
// Module Name     :  knk_word32_scramb
// Date            :  14.03.25 
// Description     :  scrambler
module knk_word32_scramb(clk, res, ena, d, d_v, d_l, sw_on, q, q_v, q_l, pkt_sym); 
input clk,res,ena;
input [31:0] d;
input d_v, d_l;
input sw_on;
output [31:0] q;
output q_v, q_l;
input [15:0]  pkt_sym;

wire [11:0] len_w;
assign len_w = (pkt_sym == 16'd576)?11'd36:11'hzzz;
assign len_w = (pkt_sym == 16'd4800)?12'd450:12'hzzz;
assign len_w = (pkt_sym == 16'd24000)?12'd2250:12'hzzz;

wire val;
knk_en env(.clk(clk),.pre(res),.step(d_v),.imp(val));

reg is_pr, is_val;
reg [31:0] rd;

always @ (posedge clk or posedge res)
 begin if (res) begin is_pr<=0; rd<=0; is_val<=0;  end
 else if (val) begin is_pr<=({rd,d[31:16]} == 48'hb6ce261d6d9c); rd<=d; is_val<=1; end
 else begin is_pr<=0; is_val<=0; end 
end

reg [11:0] cnt_d;
always @(posedge clk or posedge res)
begin
 if (res) cnt_d<=12'd2249;
 else if (is_val) begin 
   
   if (is_pr) cnt_d<=0;
   //else if (cnt_d<12'd2249) cnt_d<=cnt_d+1;
   else if (cnt_d < len_w -1 ) cnt_d<=cnt_d+1;
end end

//wire mrand=~(cnt_d==12'd2249);
wire mrand=~(cnt_d==len_w-1);

reg [5:0] cnt_ena;
wire ena_sh=~(cnt_ena == 32);

always @ (posedge clk or posedge res)
 begin if (res) cnt_ena<=32;
 else if (is_pr) cnt_ena<=16;
 else if (is_val) cnt_ena<=0;
 else if (ena_sh) cnt_ena<=cnt_ena+1;
end

reg [1:0] en_rand;
always @ (posedge clk or posedge res)
 begin if (res) en_rand<=0;
 else if (cnt_ena==6'd15) en_rand[1]<=1;
 else if (cnt_ena==6'd31) en_rand[0]<=1;
 else en_rand<=0;
end

wire [15:0] rw;
knk_rand_16 rand_16(.clk(clk),.res(res),.ini(is_pr),.ena(ena_sh),.r(rw));

wire [15:0] rev_rw;
knk_data_reverse #(.width(16)) rev(.data(rw),.q(rev_rw));

reg [31:0] rand;
always @ (posedge clk or posedge res)
 begin if (res) rand<=0;
 else if ((cnt_d == 0)&en_rand[0]) rand<={16'd0,rev_rw};
 else if (mrand&en_rand[1]) rand<={rev_rw,16'd0};
 else if (mrand&en_rand[0]) rand<={rand[31:16],rev_rw};
 else if(~mrand) rand<=0;
end
 

reg [31:0] q;
reg q_v, q_l;
always @ (posedge clk or posedge res)
 begin if (res) begin q <= 0; q_v<=0; q_l<=0;   end
 else  if (ena) begin
  if(d_v) begin q <=(sw_on)?d^rand:d;  q_v<=1; q_l<=d_l;  end
  else begin q_v<=0; q_l<=0; end
 end
end




/* ila_9 rx_scramb (
	.clk(clk), // input wire clk
	.probe0(ena), // input wire [0:0]  probe0  
	.probe1(is_pr), // input wire [0:0]  probe1 
	.probe2(is_val), // input wire [0:0]  probe2 
	.probe3(rev_rw), // input wire [15:0]  probe3
    .probe4(cnt_d), // input wire [14:0]  probe4
	.probe5(rand), // input wire [31:0]  probe5
    .probe6(q), // input wire [31:0]  probe6
    .probe7(mrand) // input wire [0:0]  probe7

); */



endmodule
//end module----------




//start_module------------------------------------------------------------
// Module Name     :  knk_rx_buff_check
// Date            :  07.03.25 
// Description     :  validate reciver data 
// Matlab          : 
module knk_rx_buff_check(clk, reset, stb_v, stb_l, data, axi_data, axi_valid, axi_last, axi_ready);
input clk, reset, stb_v, stb_l;
input [31:0] data;
output [31:0] axi_data;
output axi_valid, axi_last;
input axi_ready;

wire re_stb_v, re_stb_l;
knk_resync2r res_stb_v(.clk(clk),.in(stb_v),.out(re_stb_v));
knk_resync2r res_stb_l(.clk(clk),.in(stb_l),.out(re_stb_l));

wire es,ev,el;
knk_en env(.clk(clk),.pre(reset),.step(re_stb_v),.imp(ev));

reg axi_valid, axi_last;
reg [31:0] axi_data;
always@(posedge clk or posedge reset) begin 	
if (reset)  begin  axi_valid<=0; axi_last<=0; axi_data<=0; end
else if (ev) begin
 axi_valid<=1;
 axi_last<=re_stb_l;
 axi_data<=data;
end else if (axi_ready) begin
 axi_valid<=0;
 axi_last<=0;
end end

endmodule
//end module----------




//start_module------------------------------------------------------------
// Module Name     :  knk_rx_debug
// Date            :  29.04.25 
// Description     :  debug modem rx chanel, clk = 120MHz 
// Matlab          :  
module knk_rx_debug(clk,res,lock_pr,dena,dr,di,deb_accum_ph, par, q, stb_v, stb_l, deb_Kagc, deb_per, deb_dper, deb_cor_per, deb_cor_cnt_per,
 deb_cor_sig, del_ack,ad9361_cntrl_reg,del,ad9361_txnrx, ad9361_enable, ad9361_agc_en,
 ad9361_rx_clk, res_ad9361_rx_clk);
 
input ad9361_rx_clk, res_ad9361_rx_clk; 
 
parameter dep_sym = 12'd256;
input clk,res;
input lock_pr;
input dena;
input [15:0] dr, di;
output [31:0] q;
output stb_v, stb_l;
input [31:0] deb_accum_ph;
input [3:0] par;
input [16:0] deb_Kagc; 
input [8+5:0] deb_per, deb_dper;
input [21:0] deb_cor_per;
input [21:0] deb_cor_cnt_per;
input [19:0] deb_cor_sig;
input [31:0] del_ack;
input [7:0] ad9361_cntrl_reg;
input [9:0] del;
input ad9361_txnrx, ad9361_enable, ad9361_agc_en;
reg [11:0] cnt_sym;
wire ena=~(cnt_sym == dep_sym);

always @ (posedge clk or posedge res)
begin if (res) cnt_sym<=dep_sym;
else if (~ena&lock_pr) cnt_sym<=0;
//else if (lock_pr) cnt_sym<=0;
else if (ena&dena) cnt_sym<=cnt_sym+1; end


reg stb_v, stb_l;

reg [1:0] cnt_stb;
always @ (posedge clk or posedge res)
begin if (res)  begin cnt_stb<=3'b11;  stb_v<=0;  stb_l<=0;  end
else if (ena&dena) begin cnt_stb <=0;  stb_v<=1;  stb_l<=(cnt_sym == dep_sym - 1);   end
else if (~(cnt_stb==3'b11)) cnt_stb <=cnt_stb+1; 
else begin stb_v<=0;  stb_l<=0;  end  
end

//wire stb_v = ~(cnt_stb==3'b11);
//wire stb_l = ~(cnt_stb==3'b11)&(cnt_sym == dep_sym);



reg [15:0] timer;
always @ (posedge clk or posedge res)
begin if (res) timer<=0;
else timer<=timer+1;
end

reg [7:0] r_ad9361_cntrl_reg;
always @ (posedge ad9361_rx_clk or posedge res_ad9361_rx_clk)
begin if (res_ad9361_rx_clk) r_ad9361_cntrl_reg<=0;
else r_ad9361_cntrl_reg<=ad9361_cntrl_reg;
end

wire ch_ad9361_cntrl_reg=|(r_ad9361_cntrl_reg^ad9361_cntrl_reg);

wire ech_ad9361_cntrl_reg;
knk_en en_ch(.clk(clk),.pre(res),.step(ch_ad9361_cntrl_reg),.imp(ech_ad9361_cntrl_reg));

reg [7:0] rc_ad9361_cntrl_reg;
always @ (posedge clk or posedge res)
begin if (res) rc_ad9361_cntrl_reg<=0;
else if (ech_ad9361_cntrl_reg) rc_ad9361_cntrl_reg<=ad9361_cntrl_reg;
end


wire tag=&timer[14:0];

wire [15:0] dc={tag,3'b000,rc_ad9361_cntrl_reg, lock_pr, ad9361_txnrx, ad9361_enable, ad9361_agc_en};
reg [15:0] rdc;
always @ (posedge clk or posedge res)
begin if (res) rdc<=0;
else rdc<=dc;
end

wire is_ch = |(rdc^dc);



reg [31:0] del_cor_sig_din;
always @ (posedge clk or posedge res)
begin if (res) del_cor_sig_din <= 0;
else case (par) 
4'd5: del_cor_sig_din <= {12'd0,deb_cor_sig};
4'd6: del_cor_sig_din <= {6'd0, deb_cor_per, deb_cor_sig[3:0]};
4'd7: del_cor_sig_din <= {6'd0, deb_cor_cnt_per, deb_cor_sig[3:0]};

endcase end

reg [6:0] wad, rad;
always @ (posedge clk or posedge res)
begin if (res) begin wad<=0; rad<=0; end
else begin wad<=wad+7'd1; rad<= wad+7'd2; end end

wire [31:0] del_cor_sig_dout;
blk_mem_gen_2 del_cor_sig (
  .clka(clk),    // input wire clka
  .wea(1'b1),      // input wire [0 : 0] wea
  .addra(wad),  // input wire [6 : 0] addra
  .dina(del_cor_sig_din),    // input wire [31 : 0] dina
  .clkb(clk),    // input wire clkb
  .addrb(rad),  // input wire [6 : 0] addrb
  .doutb(del_cor_sig_dout)  // output wire [31 : 0] doutb
);

wire core_lock = deb_cor_sig[1];
reg [8:0] buf_cor_sig_wad;
wire buf_cor_sig_wen = ~buf_cor_sig_wad[8];
always @ (posedge clk or posedge res)
begin if (res) buf_cor_sig_wad <= {1'b1, 8'd0};
else if (core_lock) buf_cor_sig_wad <= 0;
else if (buf_cor_sig_wen)  buf_cor_sig_wad <= buf_cor_sig_wad +1; end
wire [7:0] buf_cor_sig_rad = cnt_sym[7:0];
wire [31:0] buf_cor_sig_dout;

reg [7:0] wad_dc;
always @ (posedge clk or posedge res)
begin if (res) wad_dc <=0;
else if (is_ch) wad_dc<=wad_dc+1; end

reg [7:0] lock_wad_dc;
always @ (posedge clk or posedge res)
begin if (res) lock_wad_dc <=0;
else if (lock_pr) lock_wad_dc<=wad_dc; end

wire buf_cor_sig_wea =         (par == 4'd9)?    is_ch                             :buf_cor_sig_wen;
wire [7:0] buf_cor_sig_addra = (par == 4'd9)?    wad_dc                            :buf_cor_sig_wad[7:0];
wire [31:0] buf_cor_sig_dina = (par == 4'd9)?    {timer,dc}                        :del_cor_sig_dout;
wire [7:0] buf_cor_sig_addrb = (par == 4'd9)?    lock_wad_dc+cnt_sym[7:0]+1        :buf_cor_sig_rad;

blk_mem_gen_3 buf_cor_sig (
  .clka(clk),    // input wire clka
  .wea(buf_cor_sig_wea),      // input wire [0 : 0] wea
  .addra(buf_cor_sig_addra),  // input wire [7 : 0] addra
  .dina(buf_cor_sig_dina),    // input wire [31 : 0] dina
  .clkb(clk),    // input wire clkb
  .addrb(buf_cor_sig_addrb),  // input wire [7 : 0] addrb
  .doutb(buf_cor_sig_dout)  // output wire [31 : 0] doutb
);




//reg [9:0] wadr, radr;
//always@(posedge clk or posedge res) begin 	
// if (res) wadr <= 0; 
// else wadr <= wadr + 1; end

//always@(posedge clk or posedge res) begin 	
//if (res) radr <= 0;
//else radr<=wadr - del; end

//wire [7:0] del_ad9361_cntrl_reg;

//blk_mem_gen_4 del_mem(
//  .clka(clk),    // input wire clka
//  .wea(1'b1),      // input wire [0 : 0] wea
//  .addra(wadr),  // input wire [9 : 0] addra
//  .dina(ad9361_cntrl_reg),    // input wire [7 : 0] dina
//  .clkb(clk),    // input wire clkb
//  .addrb(radr),  // input wire [9 : 0] addrb
//  .doutb(del_ad9361_cntrl_reg)  // output wire [7 : 0] doutb
//);



reg [31:0] q;
always @ (posedge clk or posedge res)
begin if (res) q <= 0;
else if (dena) case (par) 
4'd0:q<={dr,di};
4'd1:q<=deb_accum_ph;
4'd2:q<={7'd0,8'd0,deb_Kagc};
4'd3:q<={2'd0,deb_per, {(2){deb_dper[13]}},deb_dper};
4'd4:q<={ {(10){deb_cor_per[21]}}  ,deb_cor_per};
4'd5:q<=buf_cor_sig_dout;
4'd6:q<=buf_cor_sig_dout;
4'd7:q<=buf_cor_sig_dout;
4'd8:q<=del_ack;
4'd9:q<=buf_cor_sig_dout;
endcase end

endmodule
//end module----------


//start_module------------------------------------------------------------
// Module Name     :  knk_rx_chan
// Date            :  21.05.25 
// Description     :  modem rx chanel (12 MHz AD9361 sample), clk = 120MHz 
// Matlab          : D:\knk_pkrv_2024\QtPrj\build-com_debug-Desktop_Qt_5_12_9_MinGW_32_bit-Debug\parse_deb_data.m   -> output parsing
module knk_rx_chan(clk,reset,sclr,
//ad9361_rx_clk, res_ad9361_rx_clk, ad9361_rx_frame, ad9361_rx_data,
ad_clk, ad_rst, ad_dena, ad_di, ad_dq,
sr,si,sena,mux,sw,deb_dr,deb_di,deb_dena,dem_w_v,dem_w_l,dem_w_d,del, is_tdma, deb, deb_v, deb_l, deb_par, t_slot, pkt_rx_len, lock_pr, last_sym, 
cor_sh_ad,del_ack,ad9361_cntrl_reg, ad9361_txnrx, ad9361_enable, ad9361_agc_en,st_mod,typ_mod);

input clk,reset,sclr;


//input ad9361_rx_clk, res_ad9361_rx_clk, ad9361_rx_frame;
//input [11:0] ad9361_rx_data;

input ad_clk, ad_rst, ad_dena;
input [15:0] ad_di, ad_dq;

output [15:0] sr,si;
output sena;
input [3:0] mux;
input [3:0] sw;
output [15:0] deb_dr,deb_di;
output deb_dena;
output dem_w_v,dem_w_l;
output [31:0] dem_w_d;
input [9:0] del;
input is_tdma;

output [31:0] deb;
output deb_v, deb_l;
input [3:0] deb_par;
input [21:0] t_slot;
input [15:0] pkt_rx_len;
output lock_pr;
output last_sym;

input [9:0] cor_sh_ad;

input [31:0] del_ack;

input [7:0] ad9361_cntrl_reg;
input ad9361_txnrx, ad9361_enable, ad9361_agc_en;
input st_mod;
input [1:0] typ_mod;

reg [3:0] r_deb_par;
always@(posedge clk or posedge reset) begin
 if (reset) r_deb_par <= 0;
 else r_deb_par <= deb_par;
end

reg [21:0] r_t_slot;
always@(posedge clk or posedge reset) begin
 if (reset) r_t_slot <= 0;
 else r_t_slot <=t_slot ;
end

wire [19:0] pkt_rx_len_x3 ={3'd0,pkt_rx_len,1'b0} +  {4'd0,pkt_rx_len}; 

reg [19:0] r_pkt_rx_len;
always@(posedge clk or posedge reset) begin
 if (reset) r_pkt_rx_len <=0;
 else if (typ_mod == 2'd2) r_pkt_rx_len <={4'd0,pkt_rx_len};
 else if (typ_mod == 2'd1) r_pkt_rx_len <={1'b0,pkt_rx_len_x3[19:1]};
 else if (typ_mod == 2'd0) r_pkt_rx_len <=pkt_rx_len_x3;
end

//wire [11:0] di,dq;
wire dena;

reg [15:0]  r_ad_di, r_ad_dq;


 
reg m_ad_dena; 
always@(posedge ad_clk or posedge ad_rst) begin
if (ad_rst) m_ad_dena<=0;
else if (ad_dena) m_ad_dena<=~m_ad_dena; end


always@(posedge ad_clk or posedge ad_rst) begin
 if (ad_rst) begin r_ad_di<=0; r_ad_dq<=0; end 
 //else if (sclr) begin r_ad_di<=0; r_ad_dq<=0; end 
 else if (~m_ad_dena&ad_dena) begin r_ad_di<=ad_di; r_ad_dq<=ad_dq; end  end 




wire re_m_ad_dena;
knk_resync2r res_m_ad_dena(.clk(clk),.in(m_ad_dena),.out(re_m_ad_dena));


knk_en ena_d(.clk(clk),.pre(reset),.step(re_m_ad_dena),.imp(dena));



//assign di = r_ad_di[11:0];
//assign dq = r_ad_dq[11:0];

reg rdena;
reg [11:0] di,dq;
 
always@(posedge clk or posedge reset) begin
if (reset) rdena<=0;
else rdena<=dena; end

always@(posedge clk or posedge reset) begin
if (reset) begin di<=0; dq<=0; end
else if (sclr) begin di<=0; dq<=0; end
else if (dena) begin   di <= r_ad_di[11:0]; dq <= r_ad_dq[11:0];   end end




/*
ila_tx_out rx_in_anal (
	.clk(clk), // input wire clk
	.probe0(r_ad_di), // input wire [15:0]  probe0  
	.probe1(r_ad_dq), // input wire [15:0]  probe1 
	.probe2(ad_dena), // input wire [0:0]  probe2 
	.probe3(m_ad_dena), // input wire [0:0]  probe3 
	.probe4(re_m_ad_dena), // input wire [0:0]  probe4 
	.probe5(rdena), // input wire [0:0]  probe5 
	.probe6(di), // input wire [11:0]  probe6 
	.probe7(dq) // input wire [11:0]  probe7
);
*/


//knk_ad9361_rx_sample ad9361_rx_sample(.clk(clk),.res(reset), 
//.ad9361_rx_clk(ad9361_rx_clk), .res_ad9361_rx_clk(res_ad9361_rx_clk), .ad9361_rx_frame(ad9361_rx_frame), .ad9361_rx_data(ad9361_rx_data),
//.si(di),.sq(dq),.sena(dena)); 

wire dsh_ena;
wire [11:0] dsh_r,dsh_i;
knk_quart_freq_shift quart_freq_shift(.clk(clk),.reset(reset),.ena(rdena),.sw_on(sw[3]),.dr(di),.di(dq),.qr(dsh_r),.qi(dsh_i),.qena(dsh_ena));

wire df_ena;
wire [15:0] df_r,df_i;
knk_rcos_filt #(.vendor("xilinx")) rcos_filt(.clk(clk),.reset(reset),.ena(dsh_ena),.sw_on(sw[2]),.dr(dsh_r),.di(dsh_i),.qr(df_r),.qi(df_i),.qena(df_ena));

wire dint_ena;
wire [15:0] dint_r,dint_i;
knk_int_x2_filt #(.vendor("xilinx")) int_x2_filt(.clk(clk),.reset(reset),.ena(df_ena),.dr(df_r),.di(df_i),.qr(dint_r),.qi(dint_i),.qena(dint_ena));


wire [15:0] dcic_r, dcic_i;
//knk_cic_int #(.width_in(16),.width_out(16)) cic_int_r(.clk(clk),.reset(reset),.sclr(1'b0),.data(dint_r),.ena(dint_ena),.q(dcic_r));
//knk_cic_int #(.width_in(16),.width_out(16)) cic_int_i(.clk(clk),.reset(reset),.sclr(1'b0),.data(dint_i),.ena(dint_ena),.q(dcic_i));


cic_compiler_0 cic_int_r(
  .aclk(clk),                              // input wire aclk
  .aresetn(~reset),                        // input wire aresetn
  .s_axis_data_tdata(dint_r),    // input wire [15 : 0] s_axis_data_tdata
  .s_axis_data_tvalid(dint_ena),  // input wire s_axis_data_tvalid
//  .s_axis_data_tready(),  // output wire s_axis_data_tready
  .m_axis_data_tdata(dcic_r)    // output wire [15 : 0] m_axis_data_tdata
//  .m_axis_data_tvalid(m_axis_data_tvalid)  // output wire m_axis_data_tvalid
);


cic_compiler_0 cic_int_i(
  .aclk(clk),                              // input wire aclk
  .aresetn(~reset),                        // input wire aresetn
  .s_axis_data_tdata(dint_i),    // input wire [15 : 0] s_axis_data_tdata
  .s_axis_data_tvalid(dint_ena),  // input wire s_axis_data_tvalid
//  .s_axis_data_tready(),  // output wire s_axis_data_tready
  .m_axis_data_tdata(dcic_i)    // output wire [15 : 0] m_axis_data_tdata
//  .m_axis_data_tvalid(m_axis_data_tvalid)  // output wire m_axis_data_tvalid
);


//wire tmp_deb_pream;

//wire [7:0] cor_func_q;
//wire cor_func_q_stb;
//wire lock_pr;
//wire [21:0] per, cnt_per;
//wire [19:0] cor_func_deb_sig;

//knk_cor_func cor_func(.clk(clk),.reset(reset),.dr(dcic_r),.di(dcic_i),.q(cor_func_q),.q_stb(cor_func_q_stb),.lock_pr(lock_pr),.per(per),.cnt_per(cnt_per),.is_tdma(is_tdma),
//.t_slot(r_t_slot),.deb_sig(cor_func_deb_sig));

wire deb_is_pr;
wire nSig;

wire [31:0] lock_pream_q;
wire lock_pream;
knk_lock_pream inst_lock_pream(.clk(clk),.reset(reset),.dr(dcic_r),.di(dcic_i), .lock(lock_pream), .q(lock_pream_q));
wire [31:0] pream_pha;
wire pream_pha_set;
wire [16:0] pream_gain;
wire pream_gain_set;
wire [31:0] start_solve_ap_q;
wire start_solve_ap_q_start;

wire st_pr = lock_pream&nSig;

knk_start_solve_ap start_solve_ap(.clk(clk),.reset(reset),.dr(lock_pream_q[31:16]),.di(lock_pream_q[15:0]),.start(st_pr),
.gain(pream_gain), .pha(pream_pha), .gain_set(pream_gain_set), .pha_set(pream_pha_set),.q(start_solve_ap_q),.q_start(start_solve_ap_q_start),.deb_is_pr(deb_is_pr));




//wire [15:0] del_dcic_r, del_dcic_i;
//wire pr_set_ph;
//wire [31:0] pr_ph;
wire set_gardner;

assign lock_pr = set_gardner;


//knk_rx_del rx_del(.clk(clk),.reset(reset),.dr(dcic_r),.di(dcic_i),.del(del),.qr(del_dcic_r),.qi(del_dcic_i),.lock_pr(nSig&lock_pr),.set_ph(pr_set_ph), .ph(pr_ph),
//.set_gardner(set_gardner),.tmp_deb_pream(tmp_deb_pream),.cor_sh_ad(cor_sh_ad)); 



wire run;

wire [15:0] rot_qr, rot_qi;
wire [31:0] rot_ph;
wire rot_set;
wire [31:0] deb_accum_ph;
knk_rx_rot #(.vendor("xilinx")) rx_rot(.clk(clk),.reset(reset),.sw_on(sw[1]),.dr(start_solve_ap_q[31:16]),.di(start_solve_ap_q[15:0]),.ph(rot_ph),.set(rot_set),
.qr(rot_qr),.qi(rot_qi),.is_tdma(is_tdma),
.pr_set_ph(pream_pha_set),.pr_ph(pream_pha),.deb_accum_ph(deb_accum_ph),
.st_pkt(start_solve_ap_q_start), .st_pkt_del(set_gardner),.sclr(last_sym),.deb_is_pr(deb_is_pr)); 

// knk_rx_rot #(.vendor("xilinx")) rx_rot(.clk(clk),.reset(reset),.sw_on(sw[1]),.dr(del_dcic_r),.di(del_dcic_i),.ph(rot_ph),.set(rot_set),.qr(rot_qr),.qi(rot_qi),.is_tdma(is_tdma),
//.pr_set_ph(pr_set_ph),.pr_ph(pr_ph),.deb_accum_ph(deb_accum_ph)); 





wire [15:0] sync_r,sync_i;
wire sync_ena, sync_last, sync_start;
wire [5:0] gardner_sync_cnt_samle;

wire [16:0] deb_Kagc; 
wire [8+5:0] deb_per, deb_dper;


assign last_sym = sync_last;

//knk_gardner_sync #(.vendor("xilinx")) gardner_sync(.clk(clk),.reset(reset),.sset(lock_pr), .is_tdma(is_tdma), .dr(rot_qr),.di(rot_qi),.qr(sync_r),.qi(sync_i),.qena(sync_ena),.cnt_sample(gardner_sync_cnt_samle));
knk_gardner_sync #(.vendor("xilinx")) gardner_sync(.clk(clk),.reset(reset),.sset(set_gardner), .is_tdma(is_tdma), .dr(rot_qr),.di(rot_qi),.qr(sync_r),.qi(sync_i),.qena(sync_ena),
.cnt_sample(gardner_sync_cnt_samle),.nSig(nSig),.run(run),.deb_Kagc(deb_Kagc),.deb_per(deb_per),.deb_dper(deb_dper),.pkt_length(r_pkt_rx_len),.last_sym(sync_last),.start_sym(sync_start), 
.pream_gain(pream_gain));


wire [15:0] dem_qsr,dem_qsi;
wire dem_qena, dem_qlast, dem_qstart;
wire [31:0] dem_er_r,dem_er_i;
wire [2:0]  dem_sym;
//knk_demaper_8psk #(.vendor("xilinx")) demaper_8psk(.clk(clk),.reset(reset),.sr(sync_r),.si(sync_i),.sena(sync_ena), .sym(dem_sym), .qsr(dem_qsr),.qsi(dem_qsi),.qr(dem_er_r),.qi(dem_er_i),.qena(dem_qena));
knk_demaper_psk #(.vendor("xilinx")) demaper_8psk(.clk(clk),.reset(reset),.sr(sync_r),.si(sync_i),.sena(sync_ena),.slast(sync_last),.sstart(sync_start), .typ_mod(typ_mod), 
.sym(dem_sym), .qsr(dem_qsr),.qsi(dem_qsi),.qr(dem_er_r),.qi(dem_er_i),.qena(dem_qena), .qlast(dem_qlast), .qstart(dem_qstart));
assign rot_ph=dem_er_i;
assign rot_set=dem_qena&run;

wire w32b_v,w32b_l,w32b_s;
wire [31:0] w32b_d;
wire rx_qena;
//knk_rx_pr_bin rx_pr_bin(.clk(clk),.reset(reset),.sym(dem_sym),.sym_ena(dem_qena),.q_32b_stbv(w32b_v),.q_32b_stbl(w32b_l),.q_32b_d(w32b_d),.qena(rx_qena),.pkt_sym(r_pkt_rx_len));
 
 
knk_rx_bin rx_bin(.clk(clk),.res(reset),  .sym(dem_sym),.sym_ena(dem_qena), .sym_start(dem_qstart), .sym_last(dem_qlast), .typ_mod(typ_mod), .w(w32b_d), .wena(w32b_v), 
.wlast(w32b_l), .wstart(w32b_s));
 

//knk_word32_scramb word32_scramb(.clk(clk), .res(reset), .ena(rx_qena), .d(w32b_d), .d_v(w32b_v), .d_l(w32b_l), .sw_on(sw[0]), .q(dem_w_d), .q_v(dem_w_v), 
//.q_l(dem_w_l),.pkt_sym(r_pkt_rx_len)); 


knk_word32_scr word32_scramb(.clk(clk), .res(reset), .d(w32b_d), .dena(w32b_v), .dlast(w32b_l), .dstart(w32b_s),
 .sw_on(sw[0]) , .q(dem_w_d), .q_v(dem_w_v), .q_l(dem_w_l),.is_pr(deb_is_pr) ); 

wire [31:0] deb;
wire deb_v, deb_l;
knk_rx_debug rx_debug(.clk(clk),.res(reset),.lock_pr(set_gardner),.dena(sync_ena),.dr(sync_r),.di(sync_i), .q(deb), .stb_v(deb_v), .stb_l(deb_l),.deb_accum_ph(deb_accum_ph), 
.par(r_deb_par),.deb_Kagc(deb_Kagc),.deb_per(deb_per),.deb_dper(deb_dper), .deb_cor_per(22'd0), .deb_cor_cnt_per(22'd0), . deb_cor_sig(20'd0), .del_ack(del_ack),
.ad9361_cntrl_reg(ad9361_cntrl_reg),.del(del),.ad9361_txnrx(ad9361_txnrx), .ad9361_enable(ad9361_enable), .ad9361_agc_en(ad9361_agc_en) ,
.ad9361_rx_clk(ad_clk), .res_ad9361_rx_clk(ad_rst) );
//.ad9361_rx_clk(ad9361_rx_clk), .res_ad9361_rx_clk(res_ad9361_rx_clk) );



reg [4:0] tmp_cnt;
always@(posedge clk or posedge reset) begin
 if (reset) tmp_cnt <= 5'h10;
 else if (nSig) tmp_cnt <= 0;
 else if (~(tmp_cnt == 5'h10)&dem_qena) tmp_cnt <= tmp_cnt + 1; end

reg [47:0] tmp_dat, tmp_w;
always@(posedge clk or posedge reset) begin
 if (reset) tmp_dat <=0;
 else if (~(tmp_cnt == 5'h10)&dem_qena) tmp_dat <= {tmp_dat[44:0], dem_sym}; end

always@(posedge clk or posedge reset) begin
 if (reset) tmp_w <= 0;
 else if ((tmp_cnt == 5'h0F)&dem_qena) tmp_w <= {tmp_dat[44:0], dem_sym}; end
 
//assign tmp_deb_pream = ~(tmp_w ==48'hFFAC_533A_36EA);
 
/*
ila_10 rx_cor_pream (
	.clk(clk), // input wire clk
	.probe0(cor_func_q_stb), // input wire [0:0]  probe0  
	.probe1(cor_func_q), // input wire [7:0]  probe1 
	.probe2(dem_w_d), // input wire [31:0]  probe2 
	.probe3(dem_w_v), // input wire [0:0]  probe3
	.probe4(per), // input wire [19:0]  probe4
	.probe5(cnt_per), // input wire [19:0]  probe5
	.probe6(set_gardner), // input wire [0:0]  probe6
    .probe7(sync_ena), // input wire [0:0]  probe7
	.probe8(sync_r), // input wire [15:0]  probe8
	.probe9(sync_i), // input wire [15:0]  probe9
	.probe10(gardner_sync_cnt_samle), // input wire [5:0]  probe10
	.probe11(del_dcic_r), // input wire [15:0]  probe11
	.probe12(del_dcic_i),  // input wire [15:0]  probe12
    .probe13(dem_qena),  // input wire [0:0]  probe13
    .probe14(dem_sym),  // input wire [2:0]  probe14
	.probe15(~nSig),  // input wire [0:0]  probe15
    .probe16(tmp_dat),  // input wire [47:0]  probe16
    .probe17(tmp_w),   // input wire [47:0]  probe17
	.probe18({3'd0,set_gardner, start_solve_ap_q_start}),   // input wire [4:0]  probe18
    .probe19(deb_l),   // input wire [0:0]  probe19
	.probe20(rot_ph),   // input wire [31:0]  probe20
    .probe21(deb_v),   // input wire [0:0]  probe21
	.probe22(deb)   // input wire [31:0]  probe22
	
	
);
*/

reg [15:0] sr,si;
reg sena;
always@(posedge clk or posedge reset) begin
 if (reset) begin sr<=0; si<=0; sena<=0;   end
 else  begin sr<=dem_er_r[31:16]; si<=dem_er_i[31:16]; sena<=dem_qena; end
end


reg [15:0] deb_dr,deb_di;
reg deb_dena;
always@(posedge clk or posedge reset) begin
 if (reset) begin deb_dr<=0; deb_di<=0; deb_dena<=0; end
 else case (mux) 
 4'd0: begin deb_dr<={di,4'd0};       deb_di<={dq,4'd0};        deb_dena<=rdena;     end 
 4'd1: begin deb_dr<={dsh_r,4'd0};    deb_di<={dsh_i,4'd0};     deb_dena<=dsh_ena;  end 
 4'd2: begin deb_dr<=df_r;            deb_di<=df_i;             deb_dena<=df_ena;   end 
 4'd3: begin deb_dr<=dint_r;          deb_di<=dint_i;           deb_dena<=dint_ena; end
 4'd4: begin deb_dr<=dcic_r;          deb_di<=dcic_i;           deb_dena<=1'b1;     end
 4'd5: begin deb_dr<=sync_r;          deb_di<=sync_i;           deb_dena<=sync_ena; end
 4'd6: begin deb_dr<=dem_qsr;         deb_di<=dem_qsi;          deb_dena<=dem_qena;  end
 4'd7: begin deb_dr<=dem_er_r[31:16]; deb_di<=dem_er_i[31:16];  deb_dena<=dem_qena;  end
 default:begin deb_dr<=0;             deb_di<=0;                deb_dena<=0;        end
 endcase end

endmodule
//end module----------







//start_module------------------------------------------------------------
// Module Name     :  knk_rx_chan
// Date            :  12.11.25 
// Description     :  modem control rx chanel (24 MHz AD9361 sample), clk = 120MHz 
// Matlab          : 
module knk_rx_control(clk,reset, sclr,
ad_clk, ad_rst, ad_dena, ad_di, ad_dq,
sw,
dem_w_v,dem_w_l, dem_w_st, dem_w_d, is_tdma, pkt_rx_len, lock_pr, last_sym, typ_mod);

input clk,reset,sclr;
input ad_clk, ad_rst, ad_dena;
input [15:0] ad_di, ad_dq;
input [3:0] sw;
output dem_w_v,dem_w_l,dem_w_st;
output [31:0] dem_w_d;
input is_tdma;
input [15:0] pkt_rx_len;
output lock_pr;
output last_sym;
input [1:0] typ_mod;


wire [19:0] pkt_rx_len_x3 ={3'd0,pkt_rx_len,1'b0} +  {4'd0,pkt_rx_len}; 

reg [19:0] r_pkt_rx_len;
always@(posedge clk or posedge reset) begin
 if (reset) r_pkt_rx_len <=0;
 else if (typ_mod == 2'd2) r_pkt_rx_len <={4'd0,pkt_rx_len};
 else if (typ_mod == 2'd1) r_pkt_rx_len <={1'b0,pkt_rx_len_x3[19:1]};
 else if (typ_mod == 2'd0) r_pkt_rx_len <=pkt_rx_len_x3;
end


wire dena;
reg [15:0]  r_ad_di, r_ad_dq;


 
reg m_ad_dena; 
always@(posedge ad_clk or posedge ad_rst) begin
if (ad_rst) m_ad_dena<=0;
else if (ad_dena) m_ad_dena<=~m_ad_dena; end


always@(posedge ad_clk or posedge ad_rst) begin
 if (ad_rst) begin r_ad_di<=0; r_ad_dq<=0; end 
 //else if (sclr) begin r_ad_di<=0; r_ad_dq<=0; end 
 else if (~m_ad_dena&ad_dena) begin r_ad_di<=ad_di; r_ad_dq<=ad_dq; end  end 


wire re_m_ad_dena;
knk_resync2r res_m_ad_dena(.clk(clk),.in(m_ad_dena),.out(re_m_ad_dena));
knk_en ena_d(.clk(clk),.pre(reset),.step(re_m_ad_dena),.imp(dena));

//assign di = r_ad_di[11:0];
//assign dq = r_ad_dq[11:0];

reg rdena;
reg [11:0] di,dq;
 
always@(posedge clk or posedge reset) begin
if (reset) rdena<=0;
else rdena<=dena; end

always@(posedge clk or posedge reset) begin
if (reset) begin di<=0; dq<=0; end
else if (sclr) begin di<=0; dq<=0; end
else if (dena) begin   di <= r_ad_di[11:0]; dq <= r_ad_dq[11:0];   end end






wire dsh_ena;
wire [11:0] dsh_r,dsh_i;
knk_quart_freq_shift quart_freq_shift(.clk(clk),.reset(reset),.ena(dena),.sw_on(sw[3]),.dr(di),.di(dq),.qr(dsh_r),.qi(dsh_i),.qena(dsh_ena));

wire df_ena;
wire [15:0] df_r,df_i;
knk_rcos_filt #(.vendor("xilinx")) rcos_filt(.clk(clk),.reset(reset),.ena(dsh_ena),.sw_on(sw[2]),.dr(dsh_r),.di(dsh_i),.qr(df_r),.qi(df_i),.qena(df_ena));

wire dint_ena;
wire [15:0] dint_r,dint_i;
knk_int_x2_filt #(.vendor("xilinx")) int_x2_filt(.clk(clk),.reset(reset),.ena(df_ena),.dr(df_r),.di(df_i),.qr(dint_r),.qi(dint_i),.qena(dint_ena));


wire [15:0] dcic_r, dcic_i;


cic_compiler_0 cic_int_r(
  .aclk(clk),                              // input wire aclk
  .aresetn(~reset),                        // input wire aresetn
  .s_axis_data_tdata(dint_r),    // input wire [15 : 0] s_axis_data_tdata
  .s_axis_data_tvalid(dint_ena),  // input wire s_axis_data_tvalid
//  .s_axis_data_tready(),  // output wire s_axis_data_tready
  .m_axis_data_tdata(dcic_r)    // output wire [15 : 0] m_axis_data_tdata
//  .m_axis_data_tvalid(m_axis_data_tvalid)  // output wire m_axis_data_tvalid
);


cic_compiler_0 cic_int_i(
  .aclk(clk),                              // input wire aclk
  .aresetn(~reset),                        // input wire aresetn
  .s_axis_data_tdata(dint_i),    // input wire [15 : 0] s_axis_data_tdata
  .s_axis_data_tvalid(dint_ena),  // input wire s_axis_data_tvalid
//  .s_axis_data_tready(),  // output wire s_axis_data_tready
  .m_axis_data_tdata(dcic_i)    // output wire [15 : 0] m_axis_data_tdata
//  .m_axis_data_tvalid(m_axis_data_tvalid)  // output wire m_axis_data_tvalid
);


wire deb_is_pr;
wire nSig;

wire [31:0] lock_pream_q;
wire lock_pream;
knk_lock_pream inst_lock_pream(.clk(clk),.reset(reset),.dr(dcic_r),.di(dcic_i), .lock(lock_pream), .q(lock_pream_q));
wire [31:0] pream_pha;
wire pream_pha_set;
wire [16:0] pream_gain;
wire pream_gain_set;
wire [31:0] start_solve_ap_q;
wire start_solve_ap_q_start;

wire st_pr = lock_pream&nSig;

knk_start_solve_ap start_solve_ap(.clk(clk),.reset(reset),.dr(lock_pream_q[31:16]),.di(lock_pream_q[15:0]),.start(st_pr),
.gain(pream_gain), .pha(pream_pha), .gain_set(pream_gain_set), .pha_set(pream_pha_set),.q(start_solve_ap_q),.q_start(start_solve_ap_q_start),.deb_is_pr(deb_is_pr));


wire set_gardner;
assign lock_pr = set_gardner;


wire run;

wire [15:0] rot_qr, rot_qi;
wire [31:0] rot_ph;
wire rot_set;
wire [31:0] deb_accum_ph;
knk_rx_rot #(.vendor("xilinx")) rx_rot(.clk(clk),.reset(reset),.sw_on(sw[1]),.dr(start_solve_ap_q[31:16]),.di(start_solve_ap_q[15:0]),.ph(rot_ph),.set(rot_set),
.qr(rot_qr),.qi(rot_qi),.is_tdma(is_tdma),
.pr_set_ph(pream_pha_set),.pr_ph(pream_pha),.deb_accum_ph(deb_accum_ph),
.st_pkt(start_solve_ap_q_start), .st_pkt_del(set_gardner),.sclr(last_sym),.deb_is_pr(deb_is_pr)); 


wire [15:0] sync_r,sync_i;
wire sync_ena, sync_last, sync_start;
wire [5:0] gardner_sync_cnt_samle;

wire [16:0] deb_Kagc; 
wire [8+5:0] deb_per, deb_dper;


assign last_sym = sync_last;

knk_gardner_sync #(.vendor("xilinx")) gardner_sync(.clk(clk),.reset(reset),.sset(set_gardner), .is_tdma(is_tdma), .dr(rot_qr),.di(rot_qi),.qr(sync_r),.qi(sync_i),.qena(sync_ena),
.cnt_sample(gardner_sync_cnt_samle),.nSig(nSig),.run(run),.deb_Kagc(deb_Kagc),.deb_per(deb_per),.deb_dper(deb_dper),.pkt_length(r_pkt_rx_len),.last_sym(sync_last),.start_sym(sync_start), 
.pream_gain(pream_gain));


wire [15:0] dem_qsr,dem_qsi;
wire dem_qena, dem_qlast, dem_qstart;
wire [31:0] dem_er_r,dem_er_i;
wire [2:0]  dem_sym;
knk_demaper_psk #(.vendor("xilinx")) demaper_8psk(.clk(clk),.reset(reset),.sr(sync_r),.si(sync_i),.sena(sync_ena),.slast(sync_last),.sstart(sync_start), .typ_mod(typ_mod), 
.sym(dem_sym), .qsr(dem_qsr),.qsi(dem_qsi),.qr(dem_er_r),.qi(dem_er_i),.qena(dem_qena), .qlast(dem_qlast), .qstart(dem_qstart));
assign rot_ph=dem_er_i;
assign rot_set=dem_qena&run;

wire w32b_v,w32b_l,w32b_s;
wire [31:0] w32b_d;
wire rx_qena;

knk_rx_bin rx_bin(.clk(clk),.res(reset),  .sym(dem_sym),.sym_ena(dem_qena), .sym_start(dem_qstart), .sym_last(dem_qlast), .typ_mod(typ_mod), .w(w32b_d), .wena(w32b_v), 
.wlast(w32b_l), .wstart(w32b_s));
 
knk_word32_scr #(.out_stb_duty(1)) word32_scramb(.clk(clk), .res(reset), .d(w32b_d), .dena(w32b_v), .dlast(w32b_l), .dstart(w32b_s),
 .sw_on(sw[0]) , .q(dem_w_d), .q_v(dem_w_v), .q_l(dem_w_l),.q_st(dem_w_st),.is_pr(deb_is_pr) ); 
 
 
endmodule
//end module----------








//start_module------------------------------------------------------------
// Module Name     :  knk_data_reverse
// Date            :  29.11.13 
// Description     :  reverse data  
module knk_data_reverse(data,q);
parameter width=24;
input [width-1:0] data;
output [width-1:0] q;
genvar count;
generate for (count=0;count<width;count=count+1) begin:reverse_data 
assign q[count]=data[width-count-1];
end 
endgenerate
endmodule
//end module----------


//start_module------------------------------------------------------------
// Module Name     :  knk_sym_scramb
// Date            :  14.03.25 
// Description     :  scrambler
module knk_sym_scramb(clk, res, ena, sym, sw_on, q); 
input clk,res,ena;
input [2:0] sym;
input sw_on;
output [2:0] q;

reg [47:0] pr;
reg is_pr;
reg [2:0] rsym;

 always @ (posedge clk or posedge res)
 begin
  if (res) begin pr<=0; is_pr<=0; rsym<=0; end
  else if (ena) begin pr <= {pr[44:0],sym}; is_pr<=({pr[44:0],sym} == 48'hb6ce261d6d9c); rsym<=sym; end
 end

wire rand_ini = is_pr&ena;
reg [14:0] cnt_sym;
always @(posedge clk or posedge res)
begin
 if (res) cnt_sym<=15'd23984;
 else if (rand_ini) cnt_sym<=0;
 else if (ena&(cnt_sym<15'd23984)) cnt_sym<=cnt_sym+1;
end

wire mrand=~(cnt_sym==15'd23984);

reg [1:0] cnt_ena;
wire ena_sh=~(cnt_ena == 3);

 always @ (posedge clk or posedge res)
 begin if (res) cnt_ena<=3;
 else if (ena) cnt_ena<=0;
 else if (ena_sh) cnt_ena<=cnt_ena+1;
end

wire [15:0] rw;
knk_rand_16 rand(.clk(clk),.res(res),.ini(rand_ini),.ena(ena_sh),.r(rw));

wire [15:0] rev_rw;
knk_data_reverse #(.width(16)) rev(.data(rw),.q(rev_rw));

reg [2:0] q;
always @ (posedge clk or posedge res)
 begin if (res) q <= 0;
 else if (ena) q <= (mrand&sw_on)?rsym^rev_rw[2:0]:rsym;
end

/*
ila_8 tx_scramb (
	.clk(clk), // input wire clk
	.probe0(ena), // input wire [0:0]  probe0  
	.probe1(rand_ini), // input wire [0:0]  probe1 
	.probe2(ena_sh), // input wire [0:0]  probe2 
	.probe3(rev_rw), // input wire [15:0]  probe3
    .probe4(cnt_sym) // input wire [14:0]  probe4
);

*/

endmodule
//end module----------





//start_module------------------------------------------------------------
// Module Name     :  knk_rand_16
// Date            :  17.02.25 
// Description     :  Scrambler DVB-C (1+X^14+X^15).
module knk_rand_16 (clk,res,ini,ena,q,r);
parameter par_init=16'b1001010100000000;
input clk,res,ini,ena;
output q;
output [15:0] r;
reg [15:0] r;
wire w = r[1]^r[0];
always @(posedge clk or posedge res) begin
 if (res) r<=par_init;
 else if (ini) r<=par_init;
 else if (ena) r <= {w,r[15:1]};
end 
assign q=w;
endmodule
//end module----------


//start_module------------------------------------------------------------
// Module Name     :  knk_test_8psk
// Date            :  17.02.25 
// Description     :  8-psk test signal, 3 MBod, Fs=24MHz, ena - 12 MHz
module  knk_test_8psk(clk,res,ena,q);
parameter pream = 48'hb6ce261d6d9c;
input clk,res,ena;
output [23:0] q;

reg [1:0] cnt;
always @(posedge clk or posedge res) begin
 if (res) cnt<=0;
 else if (ena) cnt<=cnt+1;
end

reg [15:0] cnt_bit;
wire st = (cnt_bit == 23999);
always @(posedge clk or posedge res) begin
 if (res) cnt_bit <= 0;
 else if (&cnt&ena) begin
 if(st) cnt_bit	 <= 0;
 else cnt_bit <= cnt_bit + 1;
end end


reg [47:0] rpream;
wire r;
wire sh_ena = ~&cnt&ena;
always @(posedge clk or posedge res) begin
 if (res) rpream <= 0;
 else if (&cnt&st&ena) rpream <= pream;
 else if (sh_ena) rpream <= {rpream[46:0],r};
end

knk_rand_16 rand(.clk(clk),.res(res),.ini(&cnt&ena&(cnt_bit == 15)),.ena(sh_ena),.q(r));

reg  [2:0] sym;
always @(posedge clk or posedge res) begin
 if (res) sym <= 0;
 else if ((cnt == 0)&ena) sym <= rpream[47:45];
end

wire mod_ena=&cnt&ena;
wire [11:0] sr,si;
knk_mod_8_psk  mod_8_psk(.clk(clk),.res(res),.sym(sym),.ena(mod_ena),.sr(sr),.si(si));

reg [23:0] rq;
always @(posedge clk or posedge res) begin
 if (res) rq <=0;
 else if (&cnt) rq <= {sr,si};
 else rq <=0; 
end

assign q= rq;

endmodule
//end module----------




//start_module------------------------------------------------------------
// Module Name     :  knk_test_8psk_stimulus
// Date            :  17.02.25 
// Description     :  
// Matlab          :  
module knk_test_8psk_stimulus();

reg clk,reset;  
initial clk = 1'b1;
initial begin
reset=1;
#100 reset=0; 
end

always #8 clk = ~clk; 


reg ena;
always @(posedge clk or posedge reset) begin
 if (reset) ena <=0;
else ena<=~ena;
end

wire [11:0] qr,qi;
knk_test_8psk tmp(.clk(clk),.res(reset),.ena(ena),.q({qr,qi}));







endmodule
//end module----------




//start_module------------------------------------------------------------
// Module Name     :  knk_stb
// Date            :  01.08.25 
// Description     :  clk=120M
// Matlab          :  
module knk_stb(clk,reset,sclr,ena,stb);
parameter duration=3;//clks 
parameter log2duration=2;
input clk,reset,sclr,ena;
output stb;

reg [log2duration-1:0] cnt_dur_par;
always@(posedge clk or posedge reset)
begin 
 if (reset) cnt_dur_par<=duration;
 else if (sclr) cnt_dur_par<=duration;
 else if (ena) cnt_dur_par<=0;
 else if (~(cnt_dur_par==duration)) cnt_dur_par<=cnt_dur_par+1;
end

reg stb;
always@(posedge clk or posedge reset)
begin 
 if (reset) stb<=0;
 else stb<=~(cnt_dur_par==duration);
end


endmodule
//end module----------





//start_module------------------------------------------------------------
// Module Name     :  knk_interupt_ps
// Date            :  21.01.25 
// Description     :  clk=120M
// Matlab          :  
module knk_interupt_ps(clk,reset,sclr,int_1ms,int_par,par);
parameter duration=3;//clks 
parameter log2duration=2;
input clk,reset,sclr;
output int_1ms,int_par;
input [1:0] par; // 0- 8 ms, 1- 10 ms, 2 - 2ms, 3 - 1s

reg [17:0] cnt_1kHz;
wire  ena_1ms = (cnt_1kHz==119999);
always@(posedge clk or posedge reset)
begin
 if (reset) cnt_1kHz<=0;
 else if (sclr) cnt_1kHz<=0;
 else cnt_1kHz<=(ena_1ms)?0:cnt_1kHz+1;
end

reg [9:0] div_cnt_1kHz;
always@(posedge clk or posedge reset)
begin
 if (reset) div_cnt_1kHz<=0;
 else if (sclr) div_cnt_1kHz<=0;
 else if (ena_1ms) begin 
   //if (par) div_cnt_1kHz<=(div_cnt_1kHz == 4'd9)?0:div_cnt_1kHz+1;
   //else div_cnt_1kHz<=(div_cnt_1kHz == 4'd7)?0:div_cnt_1kHz+1;
  case (par)
    2'd0:  div_cnt_1kHz<=(div_cnt_1kHz == 10'd7)?  0:div_cnt_1kHz+1;
    2'd1:  div_cnt_1kHz<=(div_cnt_1kHz == 10'd9)?  0:div_cnt_1kHz+1;
    2'd2:  div_cnt_1kHz<=(div_cnt_1kHz == 10'd1)? 0:div_cnt_1kHz+1;
    2'd3:  div_cnt_1kHz<=(div_cnt_1kHz == 10'd999)?0:div_cnt_1kHz+1;
  endcase
end end

wire ena_par = (div_cnt_1kHz == 0)&ena_1ms;

reg [log2duration-1:0] cnt_dur_1ms, cnt_dur_par;
always@(posedge clk or posedge reset)
begin 
 if (reset) cnt_dur_1ms<=duration;
 else if (sclr) cnt_dur_1ms<=duration;
 else if (~ena_par&ena_1ms) cnt_dur_1ms<=0;
 else if (~(cnt_dur_1ms==duration)) cnt_dur_1ms<=cnt_dur_1ms+1;
end

always@(posedge clk or posedge reset)
begin 
 if (reset) cnt_dur_par<=duration;
 else if (sclr) cnt_dur_par<=duration;
 else if (ena_par) cnt_dur_par<=0;
 else if (~(cnt_dur_par==duration)) cnt_dur_par<=cnt_dur_par+1;
end

reg int_1ms, int_par;
always@(posedge clk or posedge reset)
begin 
 if (reset) int_1ms<=0;
 else int_1ms<=(~(cnt_dur_1ms==duration));
end

always@(posedge clk or posedge reset)
begin 
 if (reset) int_par<=0;
 else int_par<=(~(cnt_dur_par==duration));
end


endmodule
//end module----------