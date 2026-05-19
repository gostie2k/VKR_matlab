# syn/constraints/sync_top_ooc.xdc
# Out-of-context ограничения для OOC-синтеза sync_top.
# Целевая тактовая — 100 МГц (период 10.000 нс), что соответствует
# штатной частоте PL-домена в reference-проекте Xilinx Zynq-7020 +
# AD9361 (AD-FMCOMMS3-EBZ / ZedBoard).

create_clock -period 10.000 -name clk [get_ports clk]

# Входные и выходные задержки относительно clk
set_input_delay  -clock clk -max 2.000 [all_inputs]
set_input_delay  -clock clk -min 0.000 [all_inputs]
set_output_delay -clock clk -max 2.000 [all_outputs]
set_output_delay -clock clk -min 0.000 [all_outputs]

# Сброс асинхронный — не учитывается в timing closure
set_false_path -from [get_ports reset]

# =========================================================================
# Конфигурационные порты от AXI-Lite shim — статические регистры
# в той же clock-области. В реальной интеграции (Block Design + AXI-Lite
# wrapper) обновляются процессорной системой раз в сеанс и не являются
# потоковыми сигналами. Объявляются как false_path для устранения
# OOC-артефакта временнóй критичности.
# =========================================================================
set_false_path -from [get_ports {
    ctrl_soft_reset
    ctrl_enable
    ctrl_agc_bypass
    reg_k1[*]
    reg_k2[*]
    reg_w_nom[*]
    reg_clamp[*]
    reg_agc_target[*]
}]
