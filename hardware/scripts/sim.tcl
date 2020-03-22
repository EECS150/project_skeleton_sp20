
set project_name [lindex $argv 0]
set testbench_name [lindex $argv 1]

set sources_file scripts/${project_name}.tcl

if {![file exists $sources_file]} {
    puts "Invalid project name!"
    exit
}

open_project ${project_name}_proj/${project_name}_proj.xpr

set sources_file scripts/${project_name}.tcl
update_compile_order -fileset sources_1

# Add simulation file
add_files -fileset sim_1 -norecurse sim/${testbench_name}.v

set_property top ${testbench_name} [get_filesets sim_1]
update_compile_order -fileset sim_1

## Run Simulation
launch_simulation
run all
