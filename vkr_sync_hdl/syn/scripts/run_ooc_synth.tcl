# syn/scripts/run_ooc_synth.tcl
# Out-of-context синтез одного модуля для xc7z020clg484-1.
#
# Запуск:
#   vivado -mode batch -source syn/scripts/run_ooc_synth.tcl \
#          -tclargs <top_module> <output_name> [<xdc_file>]
#
# Пример:
#   vivado -mode batch -source syn/scripts/run_ooc_synth.tcl \
#          -tclargs sync_top sync_top_100mhz \
#          syn/constraints/sync_top_ooc.xdc
#
# Аргументы:
#   top_module  — имя Verilog-модуля (sync_agc, sync_farrow_parab, ...)
#   output_name — префикс файлов отчётов
#   xdc_file    — путь к xdc-файлу (по умолчанию syn/constraints/sync_top_ooc.xdc)
#
# Отчёты складываются в syn/reports/<output_name>_*.rpt

if {[llength $argv] < 2} {
    puts "ERROR: usage: vivado -mode batch -source run_ooc_synth.tcl -tclargs <top> <out_name> \[<xdc>\]"
    exit 1
}

set top_module  [lindex $argv 0]
set output_name [lindex $argv 1]
if {[llength $argv] >= 3} {
    set xdc_file [lindex $argv 2]
} else {
    set xdc_file "syn/constraints/sync_top_ooc.xdc"
}

set part      "xc7z020clg484-1"
set rpt_dir   "syn/reports"
file mkdir $rpt_dir

puts "=========================================================="
puts "OOC synthesis: top=$top_module, out=$output_name"
puts "Part=$part, XDC=$xdc_file"
puts "=========================================================="

# In-memory проект, чтобы не плодить .xpr-директории
create_project -in_memory -part $part

# Читаем все RTL-файлы; Vivado сам выберет нужный по top_module
foreach f [glob -nocomplain rtl/*.v] {
    read_verilog $f
}

# XDC применяется к OOC-синтезу
read_xdc $xdc_file

# Синтез в out-of-context: не вставлять IBUF/OBUF, не привязывать пины
synth_design -top $top_module -part $part -mode out_of_context

# Оптимизация / разводка для получения post-route timing
opt_design
place_design
route_design

# --------- Отчёты ---------
report_utilization              -file $rpt_dir/${output_name}_util.rpt
report_utilization -hierarchical -file $rpt_dir/${output_name}_util_hier.rpt
report_timing_summary           -file $rpt_dir/${output_name}_timing.rpt
report_timing -delay_type max -max_paths 10 -nworst 10 -path_type full \
                                -file $rpt_dir/${output_name}_timing_paths.rpt
report_clocks                   -file $rpt_dir/${output_name}_clocks.rpt
report_drc -ruledecks {default} -file $rpt_dir/${output_name}_drc.rpt
report_methodology              -file $rpt_dir/${output_name}_method.rpt

puts "OOC done: $output_name"
exit 0
