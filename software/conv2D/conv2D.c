#include "types.h"
#include "benchmark.h"
#include "ascii.h"
#include "uart.h"
#include "memory_map.h"

#define LOG2_FM_DIM  3
#define FM_DIM      (1 << LOG2_FM_DIM)
#define FM_SIZE     (1 << (LOG2_FM_DIM << 1)) // FM_DIM x FM_DIM
#define WT_DIM       3 
#define WT_SIZE      9 // WT_DIM x WT_DIM

// input/output feature map matrices
static int32_t ifm[FM_SIZE]    = {0};
static int32_t ofm_sw[FM_SIZE] = {0};
static int32_t ofm_hw[FM_SIZE] = {0};

// weight matrix
static int32_t wt[WT_SIZE] = {1, 2, 1, 4, 5, 4, 1, 2, 1};

int32_t times(int32_t a, int32_t b) {
    int32_t a_neg = a < 0;
    int32_t b_neg = b < 0;
    int32_t result = 0;
    if (a_neg) a = -a;
    if (b_neg) b = -b;
    while (b) {
        if (b & 1) {
            result += a;
        }
        a <<= 1;
        b >>= 1;
    }
    if ((a_neg && !b_neg) || (!a_neg && b_neg)) {
        result = -result;
    }
    return result;
}

void conv2D_sw() {
    int32_t fm_idx, wt_idx;
    int32_t x, y, m, n, idx, idy;

    x = 0; y = 0;;
    for (fm_idx = 0; fm_idx < FM_SIZE; fm_idx++) {
        int32_t *o = (ofm_sw + fm_idx);
        m = 0; n = 0;
        for (wt_idx = 0; wt_idx < WT_SIZE; wt_idx++) {
            idx = x - (WT_DIM >> 1) + n;
            idy = y - (WT_DIM >> 1) + m;

            int32_t d = 0;
            if (!(idx < 0 || idx >= FM_DIM || idy < 0 || idy >= FM_DIM))
                d = *(ifm + (idy << LOG2_FM_DIM) + idx);

            int32_t w  = *(wt + wt_idx);
            *o = *o + times(d, w);

            // index update
            n = n + 1;
            if (n == WT_DIM) {
                n = 0;
                m = m + 1;
            }
        }
        // index update
        x = x + 1;
        if (x == FM_DIM) {
            x = 0;
            y = y + 1;
        }
    }
}

void conv2D_hw() {
    int32_t fm_idx;

    // set feature map dimension
    CONV2D_FM_DIM     = FM_DIM;
    // set addresses for weight, ifm, and ofm
    CONV2D_WT_OFFSET  = (uint32_t)wt >> 2;
    CONV2D_IFM_OFFSET = (uint32_t)ifm >> 2;
    CONV2D_OFM_OFFSET = (uint32_t)ofm_hw >> 2;

    // start the accelerator computation
    CONV2D_START = 1;

    // loop until it is done
    while (!CONV2D_DONE);
}

uint32_t checksum(uint32_t *array) {
    int8_t buffer[BUF_LEN];
    int checksum = 0;

    for (int i = 0; i < FM_SIZE; i++) {
        checksum += array[i];
    }

    uwrite_int8s("\r\nChecksum: ");
    uwrite_int8s(uint32_to_ascii_hex(checksum, buffer, BUF_LEN));
}

void check_result() {
    int32_t fm_idx;
    int32_t num_mismatches = 0;

    for (fm_idx = 0; fm_idx < FM_SIZE; fm_idx++) {
        if (ofm_sw[fm_idx] != ofm_hw[fm_idx])
            num_mismatches += 1;
    }

    uwrite_int8s("\r\nNum mismatches: ");
    uwrite_int8s(uint32_to_ascii_hex(num_mismatches, buffer, BUF_LEN));
    if (num_mismatches == 0)
        uwrite_int8s("\r\nPASSED!");
    else
        uwrite_int8s("\r\nFAILED!");
}

void generate_matrices() {
    int32_t i, j;
    for (i = 0; i < FM_DIM; i++) {
        for (j = 0; j < FM_DIM; j++) {
            *(ifm    + (i << LOG2_FM_DIM) + j) = j;
            *(ofm_sw + (i << LOG2_FM_DIM) + j) = 0;
            *(ofm_hw + (i << LOG2_FM_DIM) + j) = 0;

        }
    }
}


typedef void (*entry_t)(void);

int main(int argc, char**argv) {
    generate_matrices();

    // Software execution
    uwrite_int8s("\r\n=====conv2D SW=====");
    run_and_time(&conv2D_sw);
    checksum(ofm_sw);

    // Hardware execution
    uwrite_int8s("\r\n=====conv2D HW=====");
    run_and_time(&conv2D_hw);
    checksum(ofm_hw);

    uwrite_int8s("\r\n===================");
    check_result();

    // go back to the bios - using this function causes a jr to the addr,
    // the compiler "jals" otherwise and then cannot set PC[31:28]
    uint32_t bios = ascii_hex_to_uint32("40000000");
    entry_t start = (entry_t) (bios);
    start();
    return 0;
}
