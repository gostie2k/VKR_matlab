# syn/constraints/sync_agc_ooc.xdc
# OOC-ограничения для подмодуля sync_agc.
# agc_bypass и p_target — статические конфигурационные входы
# от AXI-Lite shim, объявляются как false_path.

create_clock -period 10.000 -name clk [get_ports clk]

set_input_delay  -clock clk -max 2.000 [all_inputs]
set_input_delay  -clock clk -min 0.000 [all_inputs]
set_output_delay -clock clk -max 2.000 [all_outputs]
set_output_delay -clock clk -min 0.000 [all_outputs]

set_false_path -from [get_ports reset]

set_false_path -from [get_ports {
    agc_bypass
    p_target[*]
}]
