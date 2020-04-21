
module conv2D_opt #(
    parameter AWIDTH  = 32,
    parameter DWIDTH  = 32,
    parameter WT_DIM  = 3
) (
    input clk,
    input rst,

    // Control/Status signals
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

    // TODO: Your code to implement an optimized conv2D hardware generator

endmodule
