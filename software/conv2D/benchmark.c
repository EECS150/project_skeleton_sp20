#include "benchmark.h"
#include "ascii.h"
#include "uart.h"

void run_and_time(void (*f)()) {
    uint32_t time, instructions;
    COUNTER_RST = 0;
    (*f)();
    time = CYCLE_COUNTER;
    instructions = INSTRUCTION_COUNTER;
    uwrite_int8s("\r\nCycle Count: ");
    uwrite_int8s(uint32_to_ascii_hex(time, buffer, BUF_LEN));
    uwrite_int8s("\r\nInstruction Count: ");
    uwrite_int8s(uint32_to_ascii_hex(instructions, buffer, BUF_LEN));
}
