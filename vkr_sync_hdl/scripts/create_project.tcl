# scripts/create_project.tcl
set proj_name "sync_farrow_parab"
set proj_dir  "./vivado_prj"
set part      "xc7z020clg484-1"

# Снести старый проект (если был)
if {[file exists $proj_dir]} {
    file delete -force $proj_dir
}

create_project $proj_name $proj_dir -part $part -force

# Добавить RTL
add_files -norecurse [glob ./rtl/*.v]
set_property file_type SystemVerilog [get_files ./rtl/sync_farrow_parab.v]
# На самом деле это чистый Verilog-2001, но set_property пригодится,
# если позже будем добавлять SV-модули

# Добавить симуляционные исходники
add_files -fileset sim_1 -norecurse ./sim/tb_sync_farrow_parab.v
# Стимулы — в рабочую папку симулятора
# Создаем цепочку папок, если их нет
set xsim_path "$proj_dir/${proj_name}.sim/sim_1/behav/xsim"
file mkdir $xsim_path
file copy -force ./sim/stim_i.hex  $proj_dir/sync_farrow_parab.sim/sim_1/behav/xsim/
file copy -force ./sim/stim_q.hex  $proj_dir/sync_farrow_parab.sim/sim_1/behav/xsim/
file copy -force ./sim/stim_mu.hex $proj_dir/sync_farrow_parab.sim/sim_1/behav/xsim/

# Добавить constraints
add_files -fileset constrs_1 -norecurse ./constraints/sync_farrow_parab_ooc.xdc
set_property used_in_synthesis true  [get_files sync_farrow_parab_ooc.xdc]
set_property used_in_implementation false [get_files sync_farrow_parab_ooc.xdc]

# Указать top-модуль
set_property top sync_farrow_parab [current_fileset]
set_property top tb_sync_farrow_parab [get_filesets sim_1]

# Настройки синтеза: out-of-context режим для отдельного модуля
# (без верхнего обрамления с I/O-буферами и AXI-обвязки)
create_run -name synth_ooc -flow {Vivado Synthesis 2023} \
    -part $part -constrset constrs_1 -parent_run synth_1 2>&1
set_property -name {STEPS.SYNTH_DESIGN.ARGS.MORE OPTIONS} \
    -value {-mode out_of_context} -objects [get_runs synth_1]

puts "Project created at $proj_dir"

****** Vivado v2023.2 (64-bit)
  **** SW Build 4029153 on Fri Oct 13 20:13:54 MDT 2023
  **** IP Build 4028589 on Sat Oct 14 00:45:43 MDT 2023
  **** SharedData Build 4025554 on Tue Oct 10 17:18:54 MDT 2023
    ** Copyright 1986-2022 Xilinx, Inc. All Rights Reserved.
    ** Copyright 2022-2023 Advanced Micro Devices, Inc. All Rights Reserved.

source scripts/create_project.tcl
# set proj_name "sync_farrow_parab"
# set proj_dir  "./vivado_prj"
# set part      "xc7z020clg484-1"
# if {[file exists $proj_dir]} {
#     file delete -force $proj_dir
# }
# create_project $proj_name $proj_dir -part $part -force
# add_files -norecurse [glob ./rtl/*.v]
# set_property file_type SystemVerilog [get_files ./rtl/sync_farrow_parab.v]
# add_files -fileset sim_1 -norecurse ./sim/tb_sync_farrow_parab.v
# set xsim_path "$proj_dir/${proj_name}.sim/sim_1/behav/xsim"
# file mkdir $xsim_path
# file copy -force ./sim/stim_i.hex  $proj_dir/sync_farrow_parab.sim/sim_1/behav/xsim/
# file copy -force ./sim/stim_q.hex  $proj_dir/sync_farrow_parab.sim/sim_1/behav/xsim/
# file copy -force ./sim/stim_mu.hex $proj_dir/sync_farrow_parab.sim/sim_1/behav/xsim/
# add_files -fileset constrs_1 -norecurse ./constraints/sync_farrow_parab_ooc.xdc
# set_property used_in_synthesis true  [get_files sync_farrow_parab_ooc.xdc]
# set_property used_in_implementation false [get_files sync_farrow_parab_ooc.xdc]
# set_property top sync_farrow_parab [current_fileset]
# set_property top tb_sync_farrow_parab [get_filesets sim_1]
# create_run -name synth_ooc -flow {Vivado Synthesis 2023} \
#     -part $part -constrset constrs_1 -parent_run synth_1 2>&1
ERROR: [Common 17-158] 'name' can only be specified once.
INFO: [Common 17-206] Exiting Vivado at Thu Apr 16 17:37:55 2026...