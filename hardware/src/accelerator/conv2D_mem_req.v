
module conv2D_mem_req #(
    parameter WT_DIM  = 3,
    parameter DWIDTH  = 32
) (
    input clk,
    input rst,

    input start,
    output idle,

    input  [31:0] fm_dim,
    input  [31:0] wt_offset,
    input  [31:0] ifm_offset,
    input  [31:0] ofm_offset,

    output [31:0] x,
    output [31:0] y,

    output [31:0]       mem_req_addr,
    output              mem_req_valid,
    input               mem_req_ready,
    output [DWIDTH-1:0] mem_req_data,
    output              mem_req_write, // 1 for Write Request, 0 for Read Request

    input [DWIDTH-1:0]  wdata,
    input               wdata_valid
);

    localparam WT_SIZE     = WT_DIM  * WT_DIM;
    localparam HALF_WT_DIM = WT_DIM >> 1;

    localparam STATE_IDLE      = 2'b00;
    localparam STATE_READ_WT   = 2'b01;
    localparam STATE_READ_IFM  = 2'b10;
    localparam STATE_WRITE_OFM = 2'b11;

    wire [1:0] state_q;
    reg  [1:0] state_d;

    REGISTER_R #(.N(2), .INIT(STATE_IDLE)) state_reg (
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

    wire mem_req_fire = mem_req_valid  & mem_req_ready;

    wire signed [31:0] idx = x_cnt_q - HALF_WT_DIM + n_cnt_q;
    wire signed [31:0] idy = y_cnt_q - HALF_WT_DIM + m_cnt_q;
    wire halo = idx < 0 | idx >= fm_dim | idy < 0 | idy >= fm_dim;

    wire [31:0] wt_idx  = m_cnt_q * WT_DIM + n_cnt_q;
    wire [31:0] ifm_idx = idy * fm_dim + idx;
    wire [31:0] ofm_idx = y_cnt_q * fm_dim + x_cnt_q;

    wire read_mem  = (state_q == STATE_READ_WT  & mem_req_fire) |
                     (state_q == STATE_READ_IFM & (mem_req_fire | halo));
    wire write_mem = (state_q == STATE_WRITE_OFM) & mem_req_fire & wdata_valid;

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

    assign idle = (state_q == STATE_IDLE);

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
                    state_d = STATE_IDLE;
                else if (write_mem)
                    state_d = STATE_READ_IFM;
            end
        endcase
    end

    assign x = x_cnt_q;
    assign y = y_cnt_q;

    assign mem_req_addr  = (state_q == STATE_READ_WT)   ? wt_offset  + wt_idx  :
                           (state_q == STATE_READ_IFM)  ? ifm_offset + ifm_idx :
                           (state_q == STATE_WRITE_OFM) ? ofm_offset + ofm_idx : 0;

    assign mem_req_valid = (state_q == STATE_READ_WT) |
                           (state_q == STATE_READ_IFM & ~halo) |
                           (state_q == STATE_WRITE_OFM & wdata_valid);

    assign mem_req_data  = wdata;
    assign mem_req_write = state_q == STATE_WRITE_OFM & wdata_valid;

endmodule
