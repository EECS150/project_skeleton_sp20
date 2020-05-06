# Master Makefile dependencies
TARGET := sobel
INCLUDE_LIB := true
conv := SW
GCC_OPTS += -O2 -D$(conv)

include ../Makefile.gcc.in

run: sobel.elf
	../../scripts/hex_to_serial sobel.mif 30000000

