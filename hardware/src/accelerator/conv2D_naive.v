
module conv2D_naive #(
    parameter WT_DIM  = 3,
    parameter DWIDTH  = 32
) (
    input clk,
    input rst,

    input start,
    output idle,
    output done,

    input  [31:0]       fm_dim,
    input  [31:0]       wt_offset,
    input  [31:0]       ifm_offset,
    input  [31:0]       ofm_offset,

    output [31:0]       mem_req_addr,
    output              mem_req_valid,
    input               mem_req_ready,
    output [DWIDTH-1:0] mem_req_data,
    output              mem_req_write, // 1 for Write Request, 0 for Read Request

    input [DWIDTH-1:0]  mem_resp_data,
    input               mem_resp_valid,
    output              mem_resp_ready
);

    wire [31:0] x, y;
    wire [DWIDTH-1:0] wdata;
    wire wdata_valid;
    wire mem_req_idle, compute_idle;

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
        .ce(start_q & mem_req_idle & compute_idle),
        .rst(rst),
        .clk(clk));

    assign idle = mem_req_idle & compute_idle;

    conv2D_mem_req # (
        .WT_DIM(WT_DIM),
        .DWIDTH(DWIDTH)
    ) mem_req_unit (
        .clk(clk),
        .rst(rst),

        .start(start),       // input
        .idle(mem_req_idle), // output

        .fm_dim(fm_dim),
        .wt_offset(wt_offset),   // input
        .ifm_offset(ifm_offset), // input
        .ofm_offset(ofm_offset), // input

        .mem_req_addr(mem_req_addr),   // output
        .mem_req_valid(mem_req_valid), // output
        .mem_req_ready(mem_req_ready), // input
        .mem_req_data(mem_req_data),   // output
        .mem_req_write(mem_req_write), // output

        .x(x), // output
        .y(y), // output

        .wdata(wdata),             // input
        .wdata_valid(wdata_valid)  // input
    );

    conv2D_compute #(
        .WT_DIM(WT_DIM),
        .DWIDTH(DWIDTH)
    ) compute_unit (
        .clk(clk),
        .rst(rst),

        .start(start),       // input
        .idle(compute_idle), // output

        .x(x),           // input
        .y(y),           // input
        .fm_dim(fm_dim), // input

        .rdata(mem_resp_data),        // input
        .rdata_valid(mem_resp_valid), // input
        .rdata_ready(mem_resp_ready), // output

        .wdata(wdata),            // output
        .wdata_valid(wdata_valid) // output
    );

endmodule
