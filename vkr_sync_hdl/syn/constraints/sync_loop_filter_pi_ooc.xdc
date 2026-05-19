# syn/constraints/sync_loop_filter_pi_ooc.xdc
# OOC-ограничения для подмодуля sync_loop_filter_pi.
# Коэффициенты k1, k2 и граница насыщения clamp_lim — статические
# конфигурационные входы от AXI-Lite shim (см. обоснование
# в sync_top_ooc.xdc), объявляются как false_path.

create_clock -period 10.000 -name clk [get_ports clk]

set_input_delay  -clock clk -max 2.000 [all_inputs]
set_input_delay  -clock clk -min 0.000 [all_inputs]
set_output_delay -clock clk -max 2.000 [all_outputs]
set_output_delay -clock clk -min 0.000 [all_outputs]

set_false_path -from [get_ports reset]

set_false_path -from [get_ports {
    k1[*]
    k2[*]
    clamp_lim[*]
}]
