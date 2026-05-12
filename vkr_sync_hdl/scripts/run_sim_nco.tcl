# scripts/run_sim_nco.tcl
# Запуск симуляции tb_sync_mod1_nco в проекте sync_mod1_nco_test

open_project ./vivado_prj_nco/sync_mod1_nco_test.xpr

set sim_dir "./vivado_prj_nco/sync_mod1_nco_test.sim/sim_1/behav/xsim"
file mkdir $sim_dir

launch_simulation
run all

if {[file exists $sim_dir/nco_out.txt]} {
    file copy -force $sim_dir/nco_out.txt ./sim/nco_out.txt
    puts "============================================================"
    puts "Simulation finished. Output: ./sim/nco_out.txt"
    puts "Expected:"
    puts "  Test 1 (W=0x8000 = 0.5):  ~50 strobes in 100 clocks"
    puts "  Test 2 (W=0x6666 = 0.4):  ~40 strobes in 100 clocks"
    puts "  Test 3 (W=0x999A = 0.6):  ~60 strobes in 100 clocks"
    puts "============================================================"
} else {
    puts "ERROR: nco_out.txt not found at $sim_dir/"
}

close_sim
