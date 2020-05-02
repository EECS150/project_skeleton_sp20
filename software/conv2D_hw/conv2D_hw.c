#include "types.h"
#include "memory_map.h"

#define csr_tohost(csr_val) { \
    asm volatile ("csrw 0x51e,%[v]" :: [v]"r"(csr_val)); \
}

#define LOG2_FM_DIM 3
#define FM_DIM      1 << LOG2_FM_DIM
#define FM_SIZE     FM_DIM * FM_DIM
#define WT_DIM      3
#define WT_SIZE     WT_DIM * WT_DIM

// input/output feature map matrices
static int32_t ifm[FM_SIZE]    = {0};
static int32_t ofm_hw[FM_SIZE] = {0};

// weight matrix
static int32_t wt[WT_SIZE] = {1, 2, 1, 4, 5, 4, 1, 2, 1};

uint32_t checksum(uint32_t *array) {
    int checksum = 0;


    return checksum;
}

void generate_matrices() {
    int32_t i, j;
    for (i = 0; i < FM_DIM; i++) {
        for (j = 0; j < FM_DIM; j++) {
            *(ifm    + (i << LOG2_FM_DIM) + j) = j;
            *(ofm_hw + (i << LOG2_FM_DIM) + j) = 0;

        }
    }
}


typedef void (*entry_t)(void);

int main(int argc, char**argv) {
    uint32_t chksum = 0;

    generate_matrices();

    // Hardware execution
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
   
    // Calculate checksum
    for (int i = 0; i < FM_SIZE; i++)
        chksum += ofm_hw[i];

    if (chksum == 4158) {
        // Pass
        csr_tohost(1);
    } else {
        // Fail CSR code, checksum mismatched
        csr_tohost(2);
    }

    return 0;
}
