# constraints/sync_farrow_parab_ooc.xdc
# Out-of-context ограничения для модуля sync_farrow_parab
# Целевая тактовая — 61.44 МГц (выход DDC AD9361 в режиме 2×30.72 MSPS)
# с запасом: аттестуем на 80 МГц, чтобы был headroom под дальнейшие интеграции

create_clock -name clk -period 12.500 [get_ports clk]

# Входная задержка для всех входных портов относительно clk
# 2 нс — разумная оценка для межблочных соединений на одной ПЛИС
set_input_delay  -clock clk -max 2.000 [get_ports {in_valid in_i[*] in_q[*] mu_in[*] reset}]
set_input_delay  -clock clk -min 0.500 [get_ports {in_valid in_i[*] in_q[*] mu_in[*] reset}]

# Выходная задержка
set_output_delay -clock clk -max 2.000 [get_ports {out_valid xi_i[*] xi_q[*]}]
set_output_delay -clock clk -min 0.500 [get_ports {out_valid xi_i[*] xi_q[*]}]

# false_path для reset (асинхронный, снимается через synchronizer на уровне sync_top)
set_false_path -from [get_ports reset]
