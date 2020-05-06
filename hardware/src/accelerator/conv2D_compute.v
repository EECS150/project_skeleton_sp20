
// conv2D compute unit
module conv2D_compute #(
    parameter AWIDTH = 32,
    parameter DWIDTH = 32,
    parameter WT_DIM = 3
) (
    input clk,
    input rst,

    // Control/status signals
    input start,
    output idle,

    // Current OFM(y, x)
    input [31:0] x,
    input [31:0] y,

    // Feature map dimension
    input [31:0] fm_dim,

    // Read data from DMem
    input  [DWIDTH-1:0] rdata,
    input               rdata_valid,
    output              rdata_ready,

    // Write data to mem_if
    output [DWIDTH-1:0] wdata,
    output              wdata_valid
);

    localparam WT_SIZE     = WT_DIM  * WT_DIM;
    localparam HALF_WT_DIM = WT_DIM >> 1;

    localparam STATE_IDLE       = 3'b000;
    localparam STATE_READ_WT    = 3'b001;
    localparam STATE_COMPUTE    = 3'b010;
    localparam STATE_DONE_DELAY = 3'b011;
    localparam STATE_DONE       = 3'b100;

    // state register
    wire [2:0] state_q;
    reg  [2:0] state_d;

    REGISTER_R #(.N(3), .INIT(STATE_IDLE)) state_reg (
        .q(state_q),
        .d(state_d),
        .rst(rst),
        .clk(clk)
    );

    // m and n index registers are used to iterate through the weight elements (WT_SIZE)

    // m index register: 0 --> WT_DIM - 1
    wire [31:0] m_cnt_d, m_cnt_q;
    wire m_cnt_ce, m_cnt_rst;

    REGISTER_R_CE #(.N(32), .INIT(0)) m_cnt_reg (
        .q(m_cnt_q),
        .d(m_cnt_d),
        .ce(m_cnt_ce),
        .rst(m_cnt_rst),
        .clk(clk)
    );

    // n index register: 0 --> WT_DIM - 1
    wire [31:0] n_cnt_d, n_cnt_q;
    wire n_cnt_ce, n_cnt_rst;

    REGISTER_R_CE #(.N(32), .INIT(0)) n_cnt_reg (
        .q(n_cnt_q),
        .d(n_cnt_d),
        .ce(n_cnt_ce),
        .rst(n_cnt_rst),
        .clk(clk)
    );

    // shift registers for WT_SIZE elements of weight matrix
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

    // accumulator to store the result
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

    // idx and idy are used to check for halo cells -- see the software implementation in conv2D_testbench for reference
    wire signed [31:0] idx = x - HALF_WT_DIM + n_cnt_q;
    wire signed [31:0] idy = y - HALF_WT_DIM + m_cnt_q;
    wire halo              = idx < 0 | idx >= fm_dim | idy < 0 | idy >= fm_dim;
    wire [31:0] d          = (halo) ? 0 : rdata;

    // read logic
    // We need to be careful of when to read/scan halo cells, when to read/scan real (data) IFM cells
    wire read_wt   = (state_q == STATE_READ_WT) & rdata_fire;
    wire read_halo = (state_q == STATE_COMPUTE) & halo;
    wire read_fm   = (state_q == STATE_COMPUTE) & rdata_fire;
    wire read_data = read_wt | read_halo | read_fm;

    // (m, n) forms a nested loop. Be mindful of when to update each counter
    // for (m = 0; m < WT_DIM; m = m + 1)
    //  for (n = 0; n < WT_DIM; n = n + 1)

    // n index update
    assign n_cnt_d   = n_cnt_q + 1;
    assign n_cnt_ce  = read_data;
    assign n_cnt_rst = (n_cnt_q == WT_DIM - 1 & read_data) | rst;

    // m index update
    assign m_cnt_d   = m_cnt_q + 1;
    assign m_cnt_ce  = read_data & n_cnt_q == WT_DIM - 1;
    assign m_cnt_rst = (n_cnt_q == WT_DIM - 1 & m_cnt_q == WT_DIM - 1 & read_data) | rst;

    // We fill the weight shift register with the weight data from DMem initially.
    // When the computation phase begins, the shift register logic is enable to
    // move the weights towards wts[0] each clock cycle. A register is used to
    // accumulate the result of multiplying wts[0] with incoming IFM/halo cells.
    // This structure uses only one MAC (multiplier-accumulation) unit, but consumes
    // WT_SIZE cycles to compute the result
    //
    //
    //    wts[0] <-- wts[1] <-- wts[2] <-- ... <-- wts[8]
    //      |                                        ^
    //      |________________________________________|
    //      |
    //      * ifm/halo
    //      |
    // acc += 
 
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


    wire [31:0] d_pipe_q;
    REGISTER #(.N(32)) d_pipe_reg (
        .q(d_pipe_q),
        .d(d),
        .clk(clk));

    wire [31:0] wt0_pipe_q;
    REGISTER #(.N(32)) wt0_pipe_reg (
        .q(wt0_pipe_q),
        .d(wt_regs_q[0]),
        .clk(clk));

    wire read_d_pipe_q;
    REGISTER #(.N(1)) read_d_pipe_reg (
        .q(read_d_pipe_q),
        .d(read_halo | read_fm),
        .clk(clk));

    assign acc_d   = acc_q + wt0_pipe_q * d_pipe_q;
    assign acc_ce  = read_d_pipe_q;
    assign acc_rst = (state_q == STATE_DONE) | idle | rst;

    assign idle = (state_q == STATE_IDLE);

    always @(*) begin
        state_d = state_q;
        case (state_q)
            STATE_IDLE: begin
                if (start)
                    state_d = STATE_READ_WT;
            end
            // Load WT_DIM x WT_DIM weight elements from DMem
            STATE_READ_WT: begin
                if (n_cnt_q == WT_DIM - 1 & m_cnt_q == WT_DIM - 1 & rdata_fire)
                    state_d = STATE_COMPUTE;
            end
            // One sliding window computation
            STATE_COMPUTE: begin
                if (n_cnt_q == WT_DIM - 1 & m_cnt_q == WT_DIM - 1 & (halo | rdata_fire))
                    state_d = STATE_DONE_DELAY;

            end
            STATE_DONE_DELAY: begin
                state_d = STATE_DONE;
            end
            // Produce OFM(y, x)
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
