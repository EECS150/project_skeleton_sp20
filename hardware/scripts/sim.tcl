
set project_name   "z1top"
set testbench_name [lindex $argv 0]

set sources_file scripts/${project_name}.tcl

if {![file exists $sources_file]} {
    puts "Invalid project name!"
    exit
}

if {![file exists ${project_name}_proj/${project_name}_proj.xpr]} {
    source scripts/build_project.tcl
} else {
    open_project ${project_name}_proj/${project_name}_proj.xpr
}

update_compile_order -fileset sources_1

# Add simulation file
add_files -fileset sim_1 -norecurse sim/${testbench_name}.v
# Add memory initialization file
add_files -norecurse ../software/assembly_tests/assembly_tests.mif

set_property top ${testbench_name} [get_filesets sim_1]
update_compile_order -fileset sim_1

## Run Simulation
launch_simulation -step compile
launch_simulation -step elaborate

cd ${project_name}_proj/${project_name}_proj.sim/sim_1/behav/xsim
xsim ${testbench_name}_behav -R
