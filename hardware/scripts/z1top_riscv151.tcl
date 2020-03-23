add_files -norecurse [glob src/riscv_core/*.v]
add_files -norecurse [glob src/riscv_core/*.vh]
add_files -norecurse [glob src/io_circuits/*.v]
add_files -norecurse src/EECS151.v
add_files -norecurse src/clk_wiz.v
add_files -norecurse src/z1top_riscv151.v
# Add memory initialization file
add_files -norecurse ../software/bios151v3/bios151v3.mif

set_property top z1top_riscv151 [get_filesets sources_1]
