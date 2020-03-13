module Riscv151 #(
    parameter CPU_CLOCK_FREQ = 50_000_000,
    parameter RESET_PC = 32'h4000_0000,
    parameter BAUD_RATE = 115200,
    parameter BIOS_MEM_HEX_FILE = ""
)(
    input clk,
    input rst,
    input FPGA_SERIAL_RX,
    output FPGA_SERIAL_TX
);
    // Memories
    localparam BIOS_AWIDTH = 12;
    localparam BIOS_DWITH = 32;
    localparam BIOS_DEPTH = 4096;

    wire [BIOS_AWIDTH-1:0] bios_addr0, bios_addr1;
    wire [BIOS_DWIDTH-1:0] bios_rdata0, bios_rdata1;

    // BIOS Memory
    XILINX_SYNC_RAM_DP #(
        .AWIDTH(BIOS_AWIDTH),
        .DWIDTH(BIOS_DWIDTH)
        .DEPTH(BIOS_DEPTH),
        .MEM_INIT_HEX_FILE(BIOS_MEM_HEX_FILE)
    ) bios_mem(
        .q0(bios_rdata0),
        .d0(),
        .addr0(bios_addr0),
        .we0(1'b0),
        .q1(bios_rdata1),
        .d1(),
        .addr1(bios_addr1),
        .we1(1'b0),
        .clk(clk), .rst(rst));

    localparam DMEM_AWIDTH = 14;
    localparam DMEM_DWIDTH = 32;
    localparam DMEM_DEPTH = 16384;

    wire [DMEM_AWIDTH-1:0] dmem_addr;
    wire [DMEM_DWIDTH-1:0] dmem_rdata, dmem_wdata;
    wire [3:0] dmem_we;

    // Data Memory
    SYNC_RAM_BYTEADDR #(
        .AWIDTH(DMEM_AWIDTH),
        .DWIDTH(DMEM_DWIDTH)
        .DEPTH(DMEM_DEPTH)
    ) dmem (
        .q(dmem_rdata),
        .d(dmem_wdata),
        .addr(dmem_addr),
        .wbe(dmem_we),
        .clk(clk), .rst(rst));

    localparam IMEM_AWIDTH = 14;
    localparam IMEM_DWIDTH = 32;
    localparam IMEM_DEPTH = 16384;

    wire [IMEM_AWIDTH-1:0] imem_addr0, imem_addr1;
    wire [IMEM_DWIDTH-1:0] imem_rdata0, imem_rdata1;
    wire [IMEM_DWIDTH-1:0] imem_wdata0, imem_wdata1;
    wire [3:0] imem_we0, imem_we1;

    // Instruction Memory
    XILINX_SYNC_RAM_DP_BYTEADDR #(
        .AWIDTH(IMEM_AWIDTH),
        .DWIDTH(IMEM_DWIDTH)
        .DEPTH(IMEM_DEPTH)
    ) imem (
        .q0(imem_rdata0),
        .d0(imem_wdata0),
        .addr0(imem_addr0),
        .wbe0(imem_we0),
        .q1(imem_rdata1),
        .d1(imem_wdata1),
        .addr1(imem_addr1),
        .wbe1(imem_we1),
        .clk(clk), .rst(rst));

    wire rf_we;
    wire [4:0] rf_raddr1, rf_raddr2, rf_waddr;
    wire [31:0] rf_wdata;
    wire [31:0] rf_rdata1, rf_rdata2;

    REGFILE_1R2W # (
        .AWIDTH(5),
        .DWIDTH(32),
        .DEPTH(32)
    ) rf (
        .d0(rf_wdata),
        .addr0(rf_waddr),
        .we0(rf_we),
        .q1(rf_rdata1),
        .addr1(rf_raddr1),
        .q2(rf_rdata2),
        .addr2(rf_raddr2),
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
