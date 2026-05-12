# scripts/create_project_nco.tcl
# Изолированный Vivado-проект для модульной верификации sync_mod1_nco

set proj_name "sync_mod1_nco_test"
set proj_dir  "./vivado_prj_nco"
set part      "xc7z020clg484-1"

if {[file exists $proj_dir]} {
    file delete -force $proj_dir
}

create_project $proj_name $proj_dir -part $part -force

add_files -norecurse ./rtl/sync_mod1_nco.v
add_files -fileset sim_1 -norecurse ./sim/tb_sync_mod1_nco.v

set_property top sync_mod1_nco [current_fileset]
set_property top tb_sync_mod1_nco [get_filesets sim_1]

set_property -name {STEPS.SYNTH_DESIGN.ARGS.MORE OPTIONS} \
    -value {-mode out_of_context} -objects [get_runs synth_1]

puts "============================================================"
puts "Project sync_mod1_nco_test created at $proj_dir"
puts "Next: vivado -mode batch -source scripts/run_sim_nco.tcl"
puts "============================================================"
