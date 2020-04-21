
module conv2D_compute #(
    parameter AWIDTH = 32,
    parameter DWIDTH = 32,
    parameter WT_DIM = 3
) (
    input clk,
    input rst,

    input start,
    output idle,

    input [31:0] x,
    input [31:0] y,
    input [31:0] fm_dim,

    input  [DWIDTH-1:0] rdata,
    input               rdata_valid,
    output              rdata_ready,

    output [DWIDTH-1:0] wdata,
    output              wdata_valid
);

    localparam WT_SIZE     = WT_DIM  * WT_DIM;
    localparam HALF_WT_DIM = WT_DIM >> 1;

    localparam STATE_IDLE    = 2'b00;
    localparam STATE_READ_WT = 2'b01;
    localparam STATE_COMPUTE = 2'b10;
    localparam STATE_DONE    = 2'b11;

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

    wire [DWIDTH-1:0] wt_regs_q   [WT_SIZE-1:0];
    wire [DWIDTH-1:0] wt_regs_d   [WT_SIZE-1:0];
    wire              wt_regs_ce  [WT_SIZE-1:0];
    wire              wt_regs_rst [WT_SIZE-1:0];

    genvar i;
    generate
        for (i = 0; i < WT_SIZE; i = i + 1) begin
            REGISTER_R_CE #(.N(DWIDTH), .INIT(0)) wt_regs (
                .q(wt_regs_q[i]),
                .d(wt_regs_d[i]),
                .ce(wt_regs_ce[i]),
                .rst(wt_regs_rst[i]),
                .clk(clk)
            );
        end
    endgenerate

    wire [DWIDTH-1:0] acc_q, acc_d;
    wire              acc_ce, acc_rst;
    REGISTER_R_CE #(.N(DWIDTH), .INIT(0)) acc_reg (
        .q(acc_q),
        .d(acc_d),
        .ce(acc_ce),
        .rst(acc_rst),
        .clk(clk)
    );

    wire rdata_fire = rdata_valid & rdata_ready;

    wire signed [31:0] idx = x - HALF_WT_DIM + n_cnt_q;
    wire signed [31:0] idy = y - HALF_WT_DIM + m_cnt_q;
    wire halo              = idx < 0 | idx >= fm_dim | idy < 0 | idy >= fm_dim;
    wire [31:0] d          = (halo) ? 0 : rdata;

    wire read_wt   = (state_q == STATE_READ_WT) & rdata_fire;
    wire read_halo = (state_q == STATE_COMPUTE) & halo;
    wire read_fm   = (state_q == STATE_COMPUTE) & rdata_fire;
    wire read_data = read_wt | read_halo | read_fm;

    assign n_cnt_d   = n_cnt_q + 1;
    assign n_cnt_ce  = read_data;
    assign n_cnt_rst = (n_cnt_q == WT_DIM - 1 & read_data) | rst;

    assign m_cnt_d   = m_cnt_q + 1;
    assign m_cnt_ce  = read_data & n_cnt_q == WT_DIM - 1;
    assign m_cnt_rst = (n_cnt_q == WT_DIM - 1 & m_cnt_q == WT_DIM - 1 & read_data) | rst;

    generate
        for (i = 0; i < WT_SIZE; i = i + 1) begin
            if (i == WT_SIZE - 1)
                assign wt_regs_d[i] = (state_q == STATE_READ_WT) ? rdata : wt_regs_q[0];
            else
                assign wt_regs_d[i] = wt_regs_q[i + 1];

            assign wt_regs_ce[i]  = read_data;
            assign wt_regs_rst[i] = idle | rst;
        end
    endgenerate

    assign acc_d   = acc_q + wt_regs_q[0] * d;
    assign acc_ce  = read_halo | read_fm;
    assign acc_rst = (state_q == STATE_DONE) | idle | rst;

    assign idle = (state_q == STATE_IDLE);

    always @(*) begin
        state_d = state_q;
        case (state_q)
            STATE_IDLE: begin
                if (start)
                    state_d = STATE_READ_WT;
            end
            STATE_READ_WT: begin
                if (n_cnt_q == WT_DIM - 1 & m_cnt_q == WT_DIM - 1 & rdata_fire)
                    state_d = STATE_COMPUTE;
            end
            STATE_COMPUTE: begin
                if (n_cnt_q == WT_DIM - 1 & m_cnt_q == WT_DIM - 1 & (halo | rdata_fire))
                    state_d = STATE_DONE;
            end
            STATE_DONE: begin
                if (x == fm_dim - 1 & y == fm_dim - 1)
                    state_d = STATE_IDLE;
                else
                    state_d = STATE_COMPUTE;
            end
        endcase
    end

    assign rdata_ready = (state_q == STATE_READ_WT) | (state_q == STATE_COMPUTE);

    assign wdata       = acc_q;
    assign wdata_valid = (state_q == STATE_DONE);
endmodule
