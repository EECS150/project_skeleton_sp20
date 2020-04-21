
// conv2D (IO) <-----> io_dmem_controller <-----> DMem (Riscv151)
//
// This module implements a controller bridging the IO accelerator (conv2D) and
// the DMem of the processor. To make the problem more interesting, a delay parameter
// is added on the IO communication. Therefore, reading/writing to DMem from IO
// will not simply consume one cycle. To compensate for the IO delay, burst mode
// is added such that one can issue a single R/W request and expect multiple R/W data items
// from consecutive addresses in successive cycles.
// The memory interface follows a (much) simplified version of AXI4 protocol by having
// separate read and write channels, separate address and data channel.

module io_dmem_controller #(
    parameter AWIDTH        = 32,
    parameter DWIDTH        = 32,
    parameter MAX_BURST_LEN = 16384, // maximum burst length that the controller can support
    parameter IO_LATENCY    = 10     // add synthetic delay to make the memory model more realistic
) (
    input clk,
    input rst,

    // Read Request Address channel
    input [AWIDTH-1:0]  req_read_addr,
    input               req_read_addr_valid,
    output              req_read_addr_ready,
    input [31:0]        req_read_len, // burst length

    // Read Response channel
    output [DWIDTH-1:0] resp_read_data,
    output              resp_read_data_valid,
    input               resp_read_data_ready,

    // Write Request Address channel
    input [AWIDTH-1:0]  req_write_addr,
    input               req_write_addr_valid,
    output              req_write_addr_ready,
    input [31:0]        req_write_len, // burst length

    // Write Request Data channel
    input [DWIDTH-1:0]  req_write_data,
    input               req_write_data_valid,
    output              req_write_data_ready,

    // Write Response channel
    output              resp_write_status, // 1: write success, 0: write failure
    output              resp_write_status_valid,
    input               resp_write_status_ready,

    // Memory interface to CPU DMem
    // DMem PortA <---> IO Read
    input  [DWIDTH-1:0] dmem_douta,
    output [DWIDTH-1:0] dmem_dina,
    output [AWIDTH-1:0] dmem_addra,
    output [3:0]        dmem_wea,
    // DMem PortB <---> IO Write
    input  [DWIDTH-1:0] dmem_doutb,
    output [DWIDTH-1:0] dmem_dinb,
    output [AWIDTH-1:0] dmem_addrb,
    output [3:0]        dmem_web
);

    wire req_read_addr_fire     = req_read_addr_valid  & req_read_addr_ready;
    wire resp_read_data_fire    = resp_read_data_valid & resp_read_data_ready;

    wire req_write_addr_fire    = req_write_addr_valid & req_write_addr_ready;
    wire req_write_data_fire    = req_write_data_valid & req_write_data_ready;
    wire resp_write_status_fire = resp_write_status_valid & resp_write_status_ready;

    localparam STATE_READ_IDLE     = 2'b00;
    localparam STATE_READ_WAIT     = 2'b01;
    localparam STATE_READ_DMEM     = 2'b10;

    localparam STATE_WRITE_IDLE    = 2'b00;
    localparam STATE_WRITE_WAIT    = 2'b01;
    localparam STATE_WRITE_DMEM    = 2'b10;
    localparam STATE_WRITE_SUCCESS = 2'b11;

    // state register for read logic
    wire [1:0] state_read_q;
    reg  [1:0] state_read_d;
    REGISTER_R #(.N(2), .INIT(STATE_READ_IDLE)) state_read_reg (
        .q(state_read_q),
        .d(state_read_d),
        .rst(rst),
        .clk(clk));

    // state register for write logic
    wire [1:0] state_write_q;
    reg  [1:0] state_write_d;
    REGISTER_R #(.N(2), .INIT(STATE_WRITE_IDLE)) state_write_reg (
        .q(state_write_q),
        .d(state_write_d),
        .rst(rst),
        .clk(clk));

    // read request address register
    wire [AWIDTH-1:0] req_read_addr_q;
    REGISTER_R_CE #(.N(AWIDTH), .INIT(0)) req_read_addr_reg (
        .q(req_read_addr_q),
        .d(req_read_addr),
        .ce(state_read_q == STATE_READ_IDLE && req_read_addr_fire),
        .rst(rst),
        .clk(clk)
    );

    // read request length (burst) register
    wire [31:0] req_read_len_q;
    REGISTER_R_CE #(.N(32), .INIT(1)) req_read_len_reg (
        .q(req_read_len_q),
        .d(req_read_len),
        .ce(state_read_q == STATE_READ_IDLE && req_read_addr_fire),
        .rst(rst),
        .clk(clk)
    );

    // write request address register
    wire [AWIDTH-1:0] req_write_addr_q;
    REGISTER_R_CE #(.N(AWIDTH), .INIT(0)) req_write_addr_reg (
        .q(req_write_addr_q),
        .d(req_write_addr),
        .ce(state_write_q == STATE_WRITE_IDLE && req_write_addr_fire),
        .rst(rst),
        .clk(clk)
    );

    // write request length (burst) register
    wire [31:0] req_write_len_q;
    REGISTER_R_CE #(.N(32), .INIT(1)) req_write_len_reg (
        .q(req_write_len_q),
        .d(req_write_len),
        .ce(state_write_q == STATE_WRITE_IDLE && req_write_addr_fire),
        .rst(rst),
        .clk(clk)
    );

    // read wait counter: 0 --> IO_LATENCY - 1
    wire [31:0] read_wait_cnt_q, read_wait_cnt_d;
    wire read_wait_cnt_ce, read_wait_cnt_rst;
    REGISTER_R_CE #(.N(32), .INIT(0)) read_wait_cnt_reg (
        .q(read_wait_cnt_q),
        .d(read_wait_cnt_d),
        .ce(read_wait_cnt_ce),
        .rst(read_wait_cnt_rst),
        .clk(clk)
    );

    // read length counter: 0 --> req_read_len_q - 1
    wire [31:0] read_len_cnt_q, read_len_cnt_d;
    wire read_len_cnt_ce, read_len_cnt_rst;
    REGISTER_R_CE #(.N(32), .INIT(0)) read_len_cnt_reg (
        .q(read_len_cnt_q),
        .d(read_len_cnt_d),
        .ce(read_len_cnt_ce),
        .rst(read_len_cnt_rst),
        .clk(clk)
    );

    // write wait counter: 0 --> IO_LATENCY - 1
    wire [31:0] write_wait_cnt_q, write_wait_cnt_d;
    wire write_wait_cnt_ce, write_wait_cnt_rst;
    REGISTER_R_CE #(.N(32), .INIT(0)) write_wait_cnt_reg (
        .q(write_wait_cnt_q),
        .d(write_wait_cnt_d),
        .ce(write_wait_cnt_ce),
        .rst(write_wait_cnt_rst),
        .clk(clk)
    );

    // write length counter: 0 --> req_write_len_q - 1
    wire [31:0] write_len_cnt_q, write_len_cnt_d;
    wire write_len_cnt_ce, write_len_cnt_rst;
    REGISTER_R_CE #(.N(32), .INIT(0)) write_len_cnt_reg (
        .q(write_len_cnt_q),
        .d(write_len_cnt_d),
        .ce(write_len_cnt_ce),
        .rst(write_len_cnt_rst),
        .clk(clk)
    );

    // The logic to handle the case which 'resp_read_data_ready' suddenly goes LOW.
    // We backup the current read data to a register, and use that register value
    // for read reasponse data when response fires again.
    // This extra complexity is caused by one-cycle read from DMem
    wire read_delay_q;
    REGISTER_R_CE #(.N(1), .INIT(0)) read_delay_reg (
        .q(read_delay_q),
        .d(1'b1),
        .ce(read_delay_q == 0 & resp_read_data_valid == 1 & resp_read_data_ready == 0),
        .rst(resp_read_data_fire),
        .clk(clk)
    );

    wire [DWIDTH-1:0] read_data_delay_q;
    REGISTER_CE #(.N(DWIDTH)) read_data_delay_reg (
        .q(read_data_delay_q),
        .d(dmem_douta),
        .ce(~(read_delay_q == 1 & resp_read_data_fire == 0)),
        .clk(clk)
    );

    // Need to setup valid R/W burst length
    wire [31:0] read_burst_len  = (req_read_len_q  == 0) ? 1 :
                                  (req_read_len_q  <  MAX_BURST_LEN) ? req_read_len_q  : MAX_BURST_LEN;
    wire [31:0] write_burst_len = (req_write_len_q == 0) ? 1 :
                                  (req_write_len_q <  MAX_BURST_LEN) ? req_write_len_q : MAX_BURST_LEN;

    wire read_idle  = (state_read_q  == STATE_READ_IDLE);
    wire read_wait  = (state_read_q  == STATE_READ_WAIT);
    wire read_dmem  = (state_read_q  == STATE_READ_DMEM);

    wire write_idle    = (state_write_q == STATE_WRITE_IDLE);
    wire write_wait    = (state_write_q == STATE_WRITE_WAIT);
    wire write_dmem    = (state_write_q == STATE_WRITE_DMEM);
    wire write_success = (state_write_q == STATE_WRITE_SUCCESS);

    assign read_wait_cnt_d      = read_wait_cnt_q + 1;
    assign read_wait_cnt_ce     = read_wait;
    assign read_wait_cnt_rst    = read_dmem | rst;

    assign read_len_cnt_d       = read_len_cnt_q + 1;
    assign read_len_cnt_ce      = (read_wait_cnt_q == IO_LATENCY - 1) |
                                  resp_read_data_fire;
    assign read_len_cnt_rst     = read_idle | rst;

    assign write_wait_cnt_d     = write_wait_cnt_q + 1;
    assign write_wait_cnt_ce    = write_wait;
    assign write_wait_cnt_rst   = write_dmem | rst;

    assign write_len_cnt_d      = write_len_cnt_q + 1;
    assign write_len_cnt_ce     = req_write_data_fire;
    assign write_len_cnt_rst    = write_idle | rst;

    // Read from DMem
    assign req_read_addr_ready  = read_idle;
    assign resp_read_data_valid = read_dmem;
    assign resp_read_data       = read_delay_q ? read_data_delay_q : dmem_douta;

    assign dmem_addra           = req_read_addr_q + read_len_cnt_q;
    assign dmem_dina            = 0;
    assign dmem_wea             = 4'b0000; // no write to DMem PortA

    // Write to DMem
    assign req_write_addr_ready    = write_idle;
    assign req_write_data_ready    = write_dmem;
    assign resp_write_status_valid = write_success;
    assign resp_write_status       = write_success; // FIXME: in which case does a write fail?

    assign dmem_addrb              = req_write_addr_q + write_len_cnt_q;
    assign dmem_dinb               = req_write_data;
    assign dmem_web                = req_write_data_fire ? 4'b1111 : 4'b0000;

    always @(*) begin
        state_read_d = state_read_q;
        case (state_read_q)
            STATE_READ_IDLE: begin
                if (req_read_addr_fire)
                    state_read_d = STATE_READ_WAIT;
            end
            // Wait on IO ... (synthetic delay)
            STATE_READ_WAIT: begin
                if (read_wait_cnt_q == IO_LATENCY - 1)
                    state_read_d = STATE_READ_DMEM;
            end
            // Read from DMem for a consecutive of 'read_burst_len' items
            STATE_READ_DMEM: begin
                if (read_len_cnt_q == read_burst_len)
                    state_read_d = STATE_READ_IDLE;
            end
        endcase
    end

    always @(*) begin
        state_write_d = state_write_q;
        case (state_write_q)
            STATE_WRITE_IDLE: begin
                if (req_write_addr_fire)
                    state_write_d = STATE_WRITE_WAIT;
            end
            // Wait on IO ... (synthetic delay)
            STATE_WRITE_WAIT: begin
                if (write_wait_cnt_q == IO_LATENCY - 1)
                    state_write_d = STATE_WRITE_DMEM;
            end
            // Write to DMem for a consecutive of 'write_burst_len' items
            STATE_WRITE_DMEM: begin
                if (write_len_cnt_q == write_burst_len - 1 & req_write_data_fire)
                    state_write_d = STATE_WRITE_SUCCESS;
            end
            // Write success on the last item of the burst
            STATE_WRITE_SUCCESS: begin
                if (resp_write_status_fire)
                    state_write_d = STATE_WRITE_IDLE;
            end
        endcase
    end

endmodule
