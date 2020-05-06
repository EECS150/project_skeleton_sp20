#include "types.h"
#include "ascii.h"
#include "uart.h"
#include "memory_map.h"
#include "img.h"

#define BUF_LEN 128
int8_t buffer[BUF_LEN];

#define LOG2_FM_DIM 6
#define FM_DIM      1 << LOG2_FM_DIM
#define FM_SIZE     FM_DIM * FM_DIM
#define WT_DIM      3
#define WT_SIZE     WT_DIM * WT_DIM

// weight matrices
static int32_t wt_x[WT_SIZE] = {-1,  0, 1,
                                -2,  0, 2,
                                -1,  0, 1};

static int32_t wt_y[WT_SIZE] = {1,  2,  1,
                                0,  0,  0,
                               -1, -2, -1};

static int32_t ofm_x[FM_SIZE] = {0};
static int32_t ofm_y[FM_SIZE] = {0};

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

// source: https://en.wikipedia.org/wiki/Integer_square_root
int32_t int_sqrt(int32_t n) {
    int32_t result, tmp;
    int32_t shift = 2;
    int32_t n_shifted = n >> shift;

    while (n_shifted != 0 && n_shifted != n) {
        shift   = shift + 2;
        n_shifted = n >> shift;
    }
    shift = shift - 2;

    result = 0;
    while (shift >= 0) {
        result = result << 1;
        tmp = result + 1;
        if (times(tmp, tmp) <= (n >> shift))
          result = tmp;
        shift = shift - 2;
    }

    return result;
}

void conv2D_sw(int32_t *ifm, int32_t *wt, int32_t *ofm) {
    int32_t fm_idx, wt_idx;
    int32_t x, y, m, n, idx, idy;

    x = 0; y = 0;;
    for (fm_idx = 0; fm_idx < FM_SIZE; fm_idx++) {
        ofm[fm_idx] = 0;
        m = 0; n = 0;
        for (wt_idx = 0; wt_idx < WT_SIZE; wt_idx++) {
            idx = x - (WT_DIM >> 1) + n;
            idy = y - (WT_DIM >> 1) + m;

            int32_t d = 0;
            if (!(idx < 0 || idx >= FM_DIM || idy < 0 || idy >= FM_DIM))
                d = ifm[(idy << LOG2_FM_DIM) + idx];

            ofm[fm_idx] = ofm[fm_idx] + times(d, wt[wt_idx]);

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

void conv2D_hw(uint32_t *ifm, uint32_t *wt, uint32_t *ofm) {
    int32_t fm_idx;

    // set feature map dimension
    CONV2D_FM_DIM     = FM_DIM;
    // set addresses for weight, ifm, and ofm
    CONV2D_WT_OFFSET  = (uint32_t)(&wt[0])  >> 2;
    CONV2D_IFM_OFFSET = (uint32_t)(&ifm[0]) >> 2;
    CONV2D_OFM_OFFSET = (uint32_t)(&ofm[0]) >> 2;

    // start the accelerator computation
    CONV2D_START = 1;

    // loop until it is done
    while (!CONV2D_DONE);
}

uint32_t checksum(int32_t *array) {
    int8_t buffer[BUF_LEN];
    int checksum = 0;

    for (int i = 0; i < FM_SIZE; i++) {
        checksum += array[i];
    }

    uwrite_int8s("\r\nChecksum: ");
    uwrite_int8s(uint32_to_ascii_hex(checksum, buffer, BUF_LEN));
}

typedef void (*entry_t)(void);

int main(int argc, char**argv) {
    uint32_t i;

    uint32_t time, instructions;

    // Sobel Edge Detection
    // ofm_x = img_data (*) wt_x
    // ofm_y = img_data (*) wt_y
    // result = sqrt(ofm_x ^ 2 + ofm_y ^ 2) 

    // Benchmark Convolution x2 Computation ===================================
    COUNTER_RST = 0;

#ifdef HW
    conv2D_hw(img_data, wt_x, ofm_x);
    conv2D_hw(img_data, wt_y, ofm_y);
#else
    conv2D_sw(img_data, wt_x, ofm_x);
    conv2D_sw(img_data, wt_y, ofm_y);
#endif

    time = CYCLE_COUNTER;
    instructions = INSTRUCTION_COUNTER;

    uwrite_int8s("\r\n[conv2D x2] Cycle Count: ");
    uwrite_int8s(uint32_to_ascii_hex(time, buffer, BUF_LEN));
    uwrite_int8s("\r\n[conv2D x2] Instruction Count: ");
    uwrite_int8s(uint32_to_ascii_hex(instructions, buffer, BUF_LEN));

    // Benchmark Magnitude Computation ========================================
    COUNTER_RST = 0;

    for (i = 0; i < FM_SIZE; i++) {
        int32_t mag = int_sqrt(times(ofm_x[i], ofm_x[i]) + times(ofm_y[i], ofm_y[i]));
        mag = (mag > 255) ? 255 : mag;
        ofm_x[i] = mag;
    }

    time = CYCLE_COUNTER;
    instructions = INSTRUCTION_COUNTER;

    uwrite_int8s("\r\n[Mag] Cycle Count: ");
    uwrite_int8s(uint32_to_ascii_hex(time, buffer, BUF_LEN));
    uwrite_int8s("\r\n[Mag] Instruction Count: ");
    uwrite_int8s(uint32_to_ascii_hex(instructions, buffer, BUF_LEN));


    // Final checksum
    checksum(ofm_x);

    uwrite_int8s("\r\noutput_begin");

    // Send output to host
    for (i = 0; i < FM_SIZE; i++) {
        uwrite_int8s("\r\n");
        uwrite_int8s(uint32_to_ascii_hex(ofm_x[i], buffer, BUF_LEN));
    }

    uwrite_int8s("\r\noutput_end");

    // go back to the bios - using this function causes a jr to the addr,
    // the compiler "jals" otherwise and then cannot set PC[31:28]
    uint32_t bios = ascii_hex_to_uint32("40000000");
    entry_t start = (entry_t) (bios);
    start();
    return 0;
}
