
set project_name   "z1top"
set testbench_name [lindex $argv 0]
set sw             [lindex $argv 1]
set test_name      [lindex $argv 2]

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
add_files -norecurse [glob ../software/${sw}/*.mif]

set_property top ${testbench_name} [get_filesets sim_1]
update_compile_order -fileset sim_1

## Run Simulation
launch_simulation -step compile
launch_simulation -step elaborate

# if "make sim tb=isa_testbench", we run the whole riscv-tests test suite
if {[string match "isa_testbench" ${testbench_name}] && [string match "all" $test_name]} {
  set tests [list ]
  # Full ISA test suit (except fence_i)
  lappend tests addi.mif
  lappend tests add.mif
  lappend tests andi.mif
  lappend tests and.mif
  lappend tests auipc.mif
  lappend tests beq.mif
  lappend tests bge.mif
  lappend tests bgeu.mif
  lappend tests blt.mif
  lappend tests bltu.mif
  lappend tests bne.mif
  lappend tests jal.mif
  lappend tests jalr.mif
  lappend tests lb.mif
  lappend tests lbu.mif
  lappend tests lh.mif
  lappend tests lhu.mif
  lappend tests lui.mif
  lappend tests lw.mif
  lappend tests ori.mif
  lappend tests or.mif
  lappend tests sb.mif
  lappend tests sh.mif
  lappend tests simple.mif
  lappend tests slli.mif
  lappend tests sll.mif
  lappend tests slti.mif
  lappend tests sltiu.mif
  lappend tests slt.mif
  lappend tests sltu.mif
  lappend tests srai.mif
  lappend tests sra.mif
  lappend tests srli.mif
  lappend tests srl.mif
  lappend tests sub.mif
  lappend tests sw.mif
  lappend tests xori.mif
  lappend tests xor.mif
} else {
  set tests [list ${test_name}.mif ]
}

set num_tests [llength $tests]

cd ${project_name}_proj/${project_name}_proj.sim/sim_1/behav/xsim
for {set i 0} {$i < $num_tests} {incr i} {
  xsim ${testbench_name}_behav -testplusarg MIF_FILE=[lindex $tests $i]
  run all
}

exit
