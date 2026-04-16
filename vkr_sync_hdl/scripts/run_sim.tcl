# scripts/run_sim.tcl
open_project ./vivado_prj/sync_farrow_parab.xpr

# Обновить стимулы из ./sim (на случай, если MATLAB перегенерировал)
set sim_dir "./vivado_prj/sync_farrow_parab.sim/sim_1/behav/xsim"
file mkdir $sim_dir
foreach f {stim_i.hex stim_q.hex stim_mu.hex} {
    if {[file exists ./sim/$f]} {
        file copy -force ./sim/$f $sim_dir/$f
    }
}

launch_simulation
run all

# Скопировать результат обратно в ./sim
if {[file exists $sim_dir/out_hdl.txt]} {
    file copy -force $sim_dir/out_hdl.txt ./sim/out_hdl.txt
    puts "Output copied to ./sim/out_hdl.txt"
}

close_sim
