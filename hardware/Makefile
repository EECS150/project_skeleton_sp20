
VERILOG_SRCS := $(wildcard src/*.v)
VERILOG_SRCS += $(wildcard src/io_circuits/*.v)
VERILOG_SRCS += $(wildcard src/riscv_core/*.v)

Z1TOP_XPR = z1top_proj/z1top_proj.xpr
sw = assembly_tests

$(Z1TOP_XPR): $(VERILOG_SRCS)
		vivado -mode batch -source scripts/build_project.tcl

.PHONY: build-project
build-project: $(Z1TOP_XPR)

.PHONY: sim
sim:
		cd ../software/$(sw) && make
		vivado -mode batch -source scripts/sim.tcl -tclargs $(tb) $(sw)

.PHONY: write-bitstream
write-bitstream: $(Z1TOP_XPR)
		vivado -mode batch -source scripts/write_bitstream.tcl

.PHONY: program-fpga
program-fpga:
		vivado -mode batch -source scripts/program_fpga.tcl -tclargs $(bs)

.PHONY: clean
# "make clean" won't remove your project folders
clean:
		rm -rf *.log *.jou *.str
