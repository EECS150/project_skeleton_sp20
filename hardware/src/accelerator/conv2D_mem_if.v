
module conv2D_mem_if #(
    parameter AWIDTH = 32,
    parameter DWIDTH = 32,
    parameter WT_DIM = 3
) (
    input clk,
    input rst,

    input start,
    output idle,

    input  [31:0] fm_dim,
    input  [31:0] wt_offset,
    input  [31:0] ifm_offset,
    input  [31:0] ofm_offset,

    // Read Request Address channel
    output [AWIDTH-1:0]  req_read_addr,
    output               req_read_addr_valid,
    input                req_read_addr_ready,
    output [31:0]        req_read_len, // burst length

    // Write Request Address channel
    output [AWIDTH-1:0]  req_write_addr,
    output               req_write_addr_valid,
    input                req_write_addr_ready,
    output [31:0]        req_write_len, // burst length

    // Write Request Data channel
    output [DWIDTH-1:0]  req_write_data,
    output               req_write_data_valid,
    input                req_write_data_ready,

    // Write Response channel
    input                resp_write_status,
    input                resp_write_status_valid,
    output               resp_write_status_ready,

    output [31:0] x,
    output [31:0] y,

    input [DWIDTH-1:0]   wdata,
    input                wdata_valid
);

    assign req_read_len  = 32'd1; // no burst mode
    assign req_write_len = 32'd1; // no burst mode

    // Buffering write_addr and write_data requests
    // Set the buffer large enough so that we don't have to handle back-pressure
    wire [AWIDTH-1:0] fifo_enq_write_addr;
    wire fifo_enq_write_addr_valid, fifo_enq_write_addr_ready;
    fifo #(.WIDTH(AWIDTH), .LOGDEPTH(4)) fifo_write_addr (
        .clk(clk),
        .rst(rst),

        .enq_valid(fifo_enq_write_addr_valid),
        .enq_data(fifo_enq_write_addr),
        .enq_ready(fifo_enq_write_addr_ready),

        .deq_valid(req_write_addr_valid),
        .deq_data(req_write_addr),
        .deq_ready(req_write_addr_ready)
    );

    wire [DWIDTH-1:0] fifo_enq_write_data;
    wire fifo_enq_write_data_valid, fifo_enq_write_data_ready;
    fifo #(.WIDTH(DWIDTH), .LOGDEPTH(4)) fifo_write_data (
        .clk(clk),
        .rst(rst),

        .enq_valid(fifo_enq_write_data_valid),
        .enq_data(fifo_enq_write_data),
        .enq_ready(fifo_enq_write_data_ready),

        .deq_valid(req_write_data_valid),
        .deq_data(req_write_data),
        .deq_ready(req_write_data_ready)
    );

    wire req_read_addr_fire       = req_read_addr_valid       & req_read_addr_ready;
    wire req_write_addr_fire      = req_write_addr_valid      & req_write_addr_ready;
    wire req_write_data_fire      = req_write_data_valid      & req_write_data_ready;
    wire resp_write_status_fire   = resp_write_status_valid   & resp_write_status_ready;

    wire fifo_enq_write_addr_fire = fifo_enq_write_addr_valid & fifo_enq_write_addr_ready;

    localparam WT_SIZE     = WT_DIM  * WT_DIM;
    localparam HALF_WT_DIM = WT_DIM >> 1;

    localparam STATE_IDLE       = 3'b000;
    localparam STATE_READ_WT    = 3'b001;
    localparam STATE_READ_IFM   = 3'b010;
    localparam STATE_WRITE_OFM  = 3'b011;
    localparam STATE_LAST_WRITE = 3'b100;

    wire [2:0] state_q;
    reg  [2:0] state_d;

    REGISTER_R #(.N(3), .INIT(STATE_IDLE)) state_reg (
        .q(state_q),
        .d(state_d),
        .rst(rst),
        .clk(clk)
    );

    wire [31:0] m_cnt_d, m_cnt_q;
    wire m_cnt_ce, m_cnt_rst;

    REGISTER_R_CE #(.N(32), .INIT(0)) m_cnt_reg (
        .q(m_cnt_q),
        .d(m_cnt_d),
        .ce(m_cnt_ce),
        .rst(m_cnt_rst),
        .clk(clk)
    );

    wire [31:0] n_cnt_d, n_cnt_q;
    wire n_cnt_ce, n_cnt_rst;

    REGISTER_R_CE #(.N(32), .INIT(0)) n_cnt_reg (
        .q(n_cnt_q),
        .d(n_cnt_d),
        .ce(n_cnt_ce),
        .rst(n_cnt_rst),
        .clk(clk)
    );

    wire [31:0] x_cnt_d, x_cnt_q;
    wire x_cnt_ce, x_cnt_rst;

    REGISTER_R_CE #(.N(32), .INIT(0)) x_cnt_reg (
        .q(x_cnt_q),
        .d(x_cnt_d),
        .ce(x_cnt_ce),
        .rst(x_cnt_rst),
        .clk(clk)
    );

    wire [31:0] y_cnt_d, y_cnt_q;
    wire y_cnt_ce, y_cnt_rst;

    REGISTER_R_CE #(.N(32), .INIT(0)) y_cnt_reg (
        .q(y_cnt_q),
        .d(y_cnt_d),
        .ce(y_cnt_ce),
        .rst(y_cnt_rst),
        .clk(clk)
    );

    wire signed [31:0] idx = x_cnt_q - HALF_WT_DIM + n_cnt_q;
    wire signed [31:0] idy = y_cnt_q - HALF_WT_DIM + m_cnt_q;
    wire halo              = idx < 0 | idx >= fm_dim | idy < 0 | idy >= fm_dim;

    wire [31:0] wt_idx  = m_cnt_q * WT_DIM + n_cnt_q;
    wire [31:0] ifm_idx = idy * fm_dim + idx;
    wire [31:0] ofm_idx = y_cnt_q * fm_dim + x_cnt_q;

    wire read_mem  = (state_q == STATE_READ_WT   & req_read_addr_fire) |
                     (state_q == STATE_READ_IFM  & (req_read_addr_fire | halo));
    wire write_mem = fifo_enq_write_addr_fire & wdata_valid;

    assign n_cnt_d   = n_cnt_q + 1;
    assign n_cnt_ce  = read_mem;
    assign n_cnt_rst = (n_cnt_q == WT_DIM - 1 & read_mem) | rst;

    assign m_cnt_d   = m_cnt_q + 1;
    assign m_cnt_ce  = read_mem & n_cnt_q == WT_DIM - 1;
    assign m_cnt_rst = (n_cnt_q == WT_DIM - 1 & m_cnt_q == WT_DIM - 1 & read_mem) | rst;

    assign x_cnt_d   = x_cnt_q + 1;
    assign x_cnt_ce  = write_mem;
    assign x_cnt_rst = (x_cnt_q == fm_dim - 1 & write_mem) | rst;

    assign y_cnt_d   = y_cnt_q + 1;
    assign y_cnt_ce  = write_mem & x_cnt_q == fm_dim - 1;
    assign y_cnt_rst = (x_cnt_q == fm_dim - 1 & y_cnt_q == fm_dim - 1 & write_mem) | rst;

    assign idle = state_q == STATE_IDLE;

    always @(*) begin
        state_d = state_q;
        case (state_q)
            STATE_IDLE: begin
                if (start)
                    state_d = STATE_READ_WT;
            end
            STATE_READ_WT: begin
                if (n_cnt_q == WT_DIM - 1 & m_cnt_q == WT_DIM - 1 & read_mem)
                    state_d = STATE_READ_IFM;
            end
            STATE_READ_IFM: begin
                if (n_cnt_q == WT_DIM - 1 & m_cnt_q == WT_DIM - 1 & read_mem)
                    state_d = STATE_WRITE_OFM;
            end
            STATE_WRITE_OFM: begin
                if (x_cnt_q == fm_dim - 1 & y_cnt_q == fm_dim - 1 & write_mem)
                    state_d = STATE_LAST_WRITE;
                else if (write_mem)
                    state_d = STATE_READ_IFM;
            end
            // Only check write status on the the last write.
            // It is safe to do this since the output region
            // does not overlap with the input region
            STATE_LAST_WRITE: begin
                if (resp_write_status & resp_write_status_fire)
                    state_d = STATE_IDLE;
            end
        endcase
    end

    assign x = x_cnt_q;
    assign y = y_cnt_q;

    assign req_read_addr       = (state_q == STATE_READ_WT)   ? wt_offset  + wt_idx  :
                                 (state_q == STATE_READ_IFM)  ? ifm_offset + ifm_idx : 0;
    assign req_read_addr_valid = (state_q == STATE_READ_WT) |
                                 (state_q == STATE_READ_IFM & ~halo);

    assign fifo_enq_write_addr       = ofm_offset + ofm_idx;
    assign fifo_enq_write_addr_valid = (state_q == STATE_WRITE_OFM & wdata_valid);
    assign fifo_enq_write_data       = wdata;
    assign fifo_enq_write_data_valid = (state_q == STATE_WRITE_OFM & wdata_valid);

    assign resp_write_status_ready = 1'b1; // keep it simple
endmodule
