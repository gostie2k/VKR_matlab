# scripts/run_sim_top.tcl
# Запуск behavioral-симуляции sync_top в batch-режиме.
# Запуск (из корня vkr_sync_hdl):
#   vivado -mode batch -source scripts/run_sim_top.tcl

open_project ./vivado_prj_top/sync_top.xpr

# Актуализация стимулов (на случай повторного запуска gen_sync_top_stimulus.py)
set sim_dir "./vivado_prj_top/sync_top.sim/sim_1/behav/xsim"
file mkdir $sim_dir
foreach f {sync_stim_i.hex sync_stim_q.hex} {
    if {[file exists ./sim/$f]} {
        file copy -force ./sim/$f $sim_dir/$f
    } else {
        puts "ERROR: ./sim/$f отсутствует. Запустите gen_sync_top_stimulus.py."
        return -code error
    }
}

launch_simulation
run all

# Перенос выходных файлов в ./sim для последующего анализа
foreach f {sync_out_symbols.txt sync_out_debug.txt} {
    if {[file exists $sim_dir/$f]} {
        file copy -force $sim_dir/$f ./sim/$f
        puts "Result copied to ./sim/$f"
    } else {
        puts "WARNING: $sim_dir/$f не создан тестбенчем."
    }
}

close_sim
puts "sync_top simulation completed."
