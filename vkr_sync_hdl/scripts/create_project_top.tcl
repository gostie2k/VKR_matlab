# scripts/create_project_top.tcl
# Создание Vivado-проекта для интеграционной верификации sync_top.
# Запуск (из корня vkr_sync_hdl):
#   vivado -mode batch -source scripts/create_project_top.tcl

set proj_name "sync_top"
set proj_dir  "./vivado_prj_top"
set part      "xc7z020clg484-1"

if {[file exists $proj_dir]} {
    file delete -force $proj_dir
}

create_project $proj_name $proj_dir -part $part -force

# Все шесть RTL-модулей
add_files -norecurse [glob ./rtl/*.v]

# Тестбенч
add_files -fileset sim_1 -norecurse ./sim/tb_sync_top.v

# Подготовка XSim-директории и копирование стимулов из ./sim
set sim_dir "$proj_dir/$proj_name.sim/sim_1/behav/xsim"
file mkdir $sim_dir
foreach f {sync_stim_i.hex sync_stim_q.hex} {
    if {[file exists ./sim/$f]} {
        file copy -force ./sim/$f $sim_dir/$f
        puts "Copied stimulus: ./sim/$f -> $sim_dir"
    } else {
        puts "ERROR: ./sim/$f not found."
        puts "Run first: cd sim && python3 gen_sync_top_stimulus.py && cd .."
        return -code error
    }
}

# Топ-модули
set_property top sync_top [current_fileset]
set_property top tb_sync_top [get_filesets sim_1]

# OOC-режим синтеза (без I/O буферов, оценка ресурсов чистая)
set_property -name {STEPS.SYNTH_DESIGN.ARGS.MORE OPTIONS} \
    -value {-mode out_of_context} -objects [get_runs synth_1]

puts "sync_top project created at $proj_dir"
