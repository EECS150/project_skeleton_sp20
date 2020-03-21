module Riscv151 #(
    parameter CPU_CLOCK_FREQ    = 50_000_000,
    parameter RESET_PC          = 32'h4000_0000,
    parameter BAUD_RATE         = 115200,
    parameter BIOS_MEM_HEX_FILE = ""
) (
    input  clk,
    input  rst,
    input  FPGA_SERIAL_RX,
    output FPGA_SERIAL_TX
);
    // Memories
    localparam BIOS_AWIDTH = 12;
    localparam BIOS_DWITH  = 32;
    localparam BIOS_DEPTH  = 4096;

    wire [BIOS_AWIDTH-1:0] bios_addra, bios_addrb;
    wire [BIOS_DWIDTH-1:0] bios_douta, bios_doutb;

    // BIOS Memory
    // Synchronous read: read takes one cycle
    // Synchronous write: write takes one cycle
    XILINX_SYNC_RAM_DP #(
        .AWIDTH(BIOS_AWIDTH),
        .DWIDTH(BIOS_DWIDTH)
        .DEPTH(BIOS_DEPTH),
        .MEM_INIT_HEX_FILE(BIOS_MEM_HEX_FILE)
    ) bios_mem(
        .q0(bios_douta),    // output
        .d0(),              // intput
        .addr0(bios_addra), // input
        .we0(1'b0),         // input
        .q1(bios_doutb),    // output
        .d1(),              // input
        .addr1(bios_addrb), // input
        .we1(1'b0),         // input
        .clk(clk), .rst(rst));

    localparam DMEM_AWIDTH = 14;
    localparam DMEM_DWIDTH = 32;
    localparam DMEM_DEPTH = 16384;

    wire [DMEM_AWIDTH-1:0] dmem_addra;
    wire [DMEM_DWIDTH-1:0] dmem_dina, dmem_douta;
    wire [3:0] dmem_wea;

    // Data Memory
    // Synchronous read: read takes one cycle
    // Synchronous write: write takes one cycle
    // Byte addressable: select which of the four bytes to write
    SYNC_RAM_BYTEADDR #(
        .AWIDTH(DMEM_AWIDTH),
        .DWIDTH(DMEM_DWIDTH)
        .DEPTH(DMEM_DEPTH)
    ) dmem (
        .q(dmem_douta),    // output
        .d(dmem_dina),     // input
        .addr(dmem_addra), // input
        .wbe(dmem_wea),    // input
        .clk(clk), .rst(rst));

    localparam IMEM_AWIDTH = 14;
    localparam IMEM_DWIDTH = 32;
    localparam IMEM_DEPTH = 16384;

    wire [IMEM_AWIDTH-1:0] imem_addra, imem_addrb;
    wire [IMEM_DWIDTH-1:0] imem_douta, imem_doutb;
    wire [IMEM_DWIDTH-1:0] imem_dina, imem_dinb;
    wire [3:0] imem_wea, imem_web;

    // Instruction Memory
    // Synchronous read: read takes one cycle
    // Synchronous write: write takes one cycle
    // Byte addressable: select which of the four bytes to write
    XILINX_SYNC_RAM_DP_BYTEADDR #(
        .AWIDTH(IMEM_AWIDTH),
        .DWIDTH(IMEM_DWIDTH)
        .DEPTH(IMEM_DEPTH)
    ) imem (
        .q0(imem_douta),    // output
        .d0(imem_dina),     // input
        .addr0(imem_addra), // input
        .wbe0(imem_wea),    // input
        .q1(imem_doutb),    // output
        .d1(imem_dinb),     // input
        .addr1(imem_addrb), // input
        .wbe1(imem_web),    // input
        .clk(clk), .rst(rst));

    wire rf_we;
    wire [4:0]  rf_ra1, rf_ra2, rf_wa;
    wire [31:0] rf_wd;
    wire [31:0] rf_rd1, rf_rd2;

    // Asynchronous read: read data is available in the same cycle
    // Synchronous write: write takes one cycle
    REGFILE_1W2R # (
        .AWIDTH(5),
        .DWIDTH(32),
        .DEPTH(32)
    ) rf (
        .d0(rf_wd),     // input
        .addr0(rf_ra1), // input
        .we0(rf_we),    // input
        .q1(rf_rd1),    // output
        .addr1(rf_ra1), // input
        .q2(rf_rd2),    // output
        .addr2(rf_ra2), // input
        .clk(clk));

    // UART Receiver
    wire [7:0] uart_rx_data_out;
    wire uart_rx_data_out_valid;
    wire uart_rx_data_out_ready;

    uart_receiver #(
        .CLOCK_FREQ(CPU_CLOCK_FREQ),
        .BAUD_RATE(BAUD_RATE)) uart_rx (
        .clk(clk),
        .rst(rst),
        .data_out(uart_rx_data_out),             // output
        .data_out_valid(uart_rx_data_out_valid), // output
        .data_out_ready(uart_rx_data_out_ready), // input
        .serial_in(FPGA_SERIAL_RX)               // input
    );

    // UART Transmitter
    wire [7:0] uart_tx_data_in;
    wire uart_tx_data_in_valid;
    wire uart_tx_data_in_ready;

    uart_transmitter #(
        .CLOCK_FREQ(CPU_CLOCK_FREQ),
        .BAUD_RATE(BAUD_RATE)) uart_tx (
        .clk(clk),
        .rst(reset),
        .data_in(uart_tx_data_in),             // input
        .data_in_valid(uart_tx_data_in_valid), // input
        .data_in_ready(uart_tx_data_in_ready), // output
        .serial_out(FPGA_SERIAL_TX)            // output
    );


    // Construct your datapath, add as many modules as you want

endmodule
