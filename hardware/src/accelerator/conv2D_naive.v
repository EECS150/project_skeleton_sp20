
module conv2D_naive #(
    parameter AWIDTH  = 32,
    parameter DWIDTH  = 32,
    parameter WT_DIM  = 3
) (
    input clk,
    input rst,

    // Control signals
    input start,
    output idle,
    output done,

    // Scalar signals
    input  [31:0]       fm_dim,
    input  [31:0]       wt_offset,
    input  [31:0]       ifm_offset,
    input  [31:0]       ofm_offset,

    // Read Request Address channel
    output [AWIDTH-1:0] req_read_addr,
    output              req_read_addr_valid,
    input               req_read_addr_ready,
    output [31:0]       req_read_len, // burst length

    // Read Response channel
    input [DWIDTH-1:0]  resp_read_data,
    input               resp_read_data_valid,
    output              resp_read_data_ready,

    // Write Request Address channel
    output [AWIDTH-1:0] req_write_addr,
    output              req_write_addr_valid,
    input               req_write_addr_ready,
    output [31:0]       req_write_len, // burst length

    // Write Request Data channel
    output [DWIDTH-1:0] req_write_data,
    output              req_write_data_valid,
    input               req_write_data_ready,

    // Write Response channel
    input                resp_write_status,
    input                resp_write_status_valid,
    output               resp_write_status_ready
);

    wire [31:0] x, y;
    wire [DWIDTH-1:0] wdata;
    wire wdata_valid;
    wire mem_if_idle, compute_idle;

    wire start_q;
    REGISTER_R_CE #(.N(1), .INIT(0)) start_reg (
        .q(start_q),
        .d(1'b1),
        .ce(start),
        .rst(rst),
        .clk(clk));

    REGISTER_R_CE #(.N(1), .INIT(0)) done_reg (
        .q(done),
        .d(1'b1),
        .ce(start_q & mem_if_idle & compute_idle),
        .rst(rst),
        .clk(clk));

    assign idle = mem_if_idle & compute_idle;

    // Memory Interface Unit
    conv2D_mem_if # (
        .AWIDTH(AWIDTH),
        .DWIDTH(DWIDTH),
        .WT_DIM(WT_DIM)
    ) mem_if_unit (
        .clk(clk),
        .rst(rst),

        .start(start),                                     // input
        .idle(mem_if_idle),                                // output

        .fm_dim(fm_dim),                                   // input
        .wt_offset(wt_offset),                             // input
        .ifm_offset(ifm_offset),                           // input
        .ofm_offset(ofm_offset),                           // input

        // Read Request Address channel
        .req_read_addr(req_read_addr),                     // input
        .req_read_addr_valid(req_read_addr_valid),         // input
        .req_read_addr_ready(req_read_addr_ready),         // output
        .req_read_len(req_read_len),                       // input

        // Write Request Address channel
        .req_write_addr(req_write_addr),                   // input
        .req_write_addr_valid(req_write_addr_valid),       // input
        .req_write_addr_ready(req_write_addr_ready),       // output
        .req_write_len(req_write_len),                     // input

        // Write Request Data channel
        .req_write_data(req_write_data),                   // input
        .req_write_data_valid(req_write_data_valid),       // input
        .req_write_data_ready(req_write_data_ready),       // output

        // Write Response channel
        .resp_write_status(resp_write_status),             // input
        .resp_write_status_valid(resp_write_status_valid), // input
        .resp_write_status_ready(resp_write_status_ready), // output

        .x(x),                                             // output
        .y(y),                                             // output

        .wdata(wdata),                                     // input
        .wdata_valid(wdata_valid)                          // input
    );

    // Compute Unit
    conv2D_compute #(
        .AWIDTH(AWIDTH),
        .DWIDTH(DWIDTH),
        .WT_DIM(WT_DIM)
    ) compute_unit (
        .clk(clk),
        .rst(rst),

        .start(start),                      // input
        .idle(compute_idle),                // output

        .x(x),                              // input
        .y(y),                              // input
        .fm_dim(fm_dim),                    // input

        .rdata(resp_read_data),             // output
        .rdata_valid(resp_read_data_valid), // output
        .rdata_ready(resp_read_data_ready), // input

        .wdata(wdata),                      // output
        .wdata_valid(wdata_valid)           // output
    );

endmodule
