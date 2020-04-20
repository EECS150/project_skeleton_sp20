#ifndef BENCHMARK_H_
#define BENCHMARK_H_

#include "types.h"
#include "memory_map.h"

#define BUF_LEN 128
int8_t buffer[BUF_LEN];

void run_and_time(void (*f)());
#endif
