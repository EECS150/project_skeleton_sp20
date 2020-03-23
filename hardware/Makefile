
VERILOG_SRCS := $(wildcard src/*.v)
VERILOG_SRCS += $(wildcard src/io_circuits/*.v)
VERILOG_SRCS += $(wildcard src/riscv_core/*.v)

vivado_proj_file = $(proj)_proj/$(proj)_proj.xpr

sw = assembly_tests

$(vivado_proj_file): $(VERILOG_SRCS)
		vivado -mode batch -source scripts/build_project.tcl -tclargs $(proj)

.PHONY: build-project
build-project: $(vivado_proj_file)

.PHONY: sim
sim:
		cd ../software/$(sw) && make
		vivado -mode batch -source scripts/sim.tcl -tclargs $(proj) $(tb) $(sw)

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
