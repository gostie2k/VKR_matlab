# scripts/create_project.tcl
set proj_name "sync_farrow_parab"
set proj_dir  "./vivado_prj"
set part      "xc7z020clg484-1"

if {[file exists $proj_dir]} {
    file delete -force $proj_dir
}

create_project $proj_name $proj_dir -part $part -force

# RTL
add_files -norecurse [glob ./rtl/*.v]

# Simulation
add_files -fileset sim_1 -norecurse ./sim/tb_sync_farrow_parab.v

# Stimuli — создать директорию XSim и скопировать hex
set sim_dir "$proj_dir/$proj_name.sim/sim_1/behav/xsim"
file mkdir $sim_dir
foreach f {stim_i.hex stim_q.hex stim_mu.hex} {
    if {[file exists ./sim/$f]} {
        file copy -force ./sim/$f $sim_dir/$f
    } else {
        puts "WARNING: ./sim/$f not found, skipping"
    }
}

# Constraints
if {[file exists ./constraints/sync_farrow_parab_ooc.xdc]} {
    add_files -fileset constrs_1 -norecurse ./constraints/sync_farrow_parab_ooc.xdc
    set_property used_in_synthesis true  [get_files sync_farrow_parab_ooc.xdc]
    set_property used_in_implementation true [get_files sync_farrow_parab_ooc.xdc]
}

# Top modules
set_property top sync_farrow_parab [current_fileset]
set_property top tb_sync_farrow_parab [get_filesets sim_1]

# OOC-режим на стандартном synth_1 (без I/O буферов)
set_property -name {STEPS.SYNTH_DESIGN.ARGS.MORE OPTIONS} \
    -value {-mode out_of_context} -objects [get_runs synth_1]

puts "Project created at $proj_dir"
