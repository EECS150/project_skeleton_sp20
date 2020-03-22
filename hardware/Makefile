
VERILOG_SRCS = src/*.v
vivado_proj_file = $(proj)_proj/$(proj)_proj.xpr

.PHONY: build-project
$(vivado_proj_file) build-project: $(VERILOG_SRCS)
		vivado -mode batch -source scripts/build_project.tcl -tclargs $(proj)

.PHONY: sim
sim: $(vivado_proj_file)
		vivado -mode batch -source scripts/sim.tcl -tclargs $(proj) $(tb)

.PHONY: impl
impl: $(vivado_proj_file)
		vivado -mode batch -source scripts/impl.tcl -tclargs $(proj)

.PHONY: write-bitstream
write-bitstream: $(vivado_proj_file)
		vivado -mode batch -source scripts/write_bitstream.tcl -tclargs $(proj)

.PHONY: program-fpga
program-fpga:
		vivado -mode batch -source scripts/program_fpga.tcl -tclargs $(bs)

.PHONY: clean
# "make clean" won't remove your project folders
clean:
		rm -rf *.log *.jou *.str
