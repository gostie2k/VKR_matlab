# syn/constraints/sync_top_ooc_150mhz.xdc
# Контрольный прогон на 150 МГц (период 6.667 нс) — оценка запаса
# архитектуры по частоте. Применяется только к sync_top.

create_clock -period 6.667 -name clk [get_ports clk]

set_input_delay  -clock clk -max 1.500 [all_inputs]
set_input_delay  -clock clk -min 0.000 [all_inputs]
set_output_delay -clock clk -max 1.500 [all_outputs]
set_output_delay -clock clk -min 0.000 [all_outputs]

set_false_path -from [get_ports reset]

# Конфигурационные порты от AXI-Lite shim — см. комментарий в sync_top_ooc.xdc
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
