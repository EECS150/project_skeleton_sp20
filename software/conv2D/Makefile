# Master Makefile dependencies
TARGET := conv2D
INCLUDE_LIB := true
GCC_OPTS += -O2

include ../Makefile.gcc.in

run: conv2D.elf
	../../scripts/hex_to_serial conv2D.mif 30000000

