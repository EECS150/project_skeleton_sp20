
module io_dmem_controller #(
    parameter AWIDTH          = 32,
    parameter DWIDTH          = 32,
    parameter IO_DMEM_LATENCY = 1
) (
    input clk,
    input rst,

    // Memory interface from IO device (e.g. conv2D accelerator)
    input [AWIDTH-1:0]  mem_req_addr,
    input               mem_req_valid,
    output              mem_req_ready,
    input [DWIDTH-1:0]  mem_req_data,
    input               mem_req_write,

    output [DWIDTH-1:0] mem_resp_data,
    output              mem_resp_valid,
    input               mem_resp_ready,

    // Memory interface to CPU DMem
    input  [DWIDTH-1:0] dmem_dout,
    output [DWIDTH-1:0] dmem_din,
    output [AWIDTH-1:0] dmem_addr,
    output [3:0]        dmem_wbe
);

    wire mem_req_fire  = mem_req_valid & mem_req_ready;
    wire mem_resp_fire = mem_resp_valid & mem_resp_ready;

    localparam STATE_IDLE       = 2'b00;
    localparam STATE_READ_DMEM  = 2'b01;
    localparam STATE_WRITE_DMEM = 2'b10;

    wire [1:0] state_q;
    reg  [1:0] state_d;
    REGISTER_R #(.N(2), .INIT(STATE_IDLE)) state_reg (
        .q(state_q),
        .d(state_d),
        .rst(rst),
        .clk(clk));

    always @(*) begin
        state_d = state_q;
        case (state_q)
        STATE_IDLE: begin
            if (mem_req_fire &  mem_req_write)
                state_d = STATE_WRITE_DMEM;
            if (mem_req_fire & ~mem_req_write)
                state_d = STATE_READ_DMEM;
        end

        STATE_READ_DMEM: begin
            if (mem_resp_fire)
                state_d = STATE_IDLE;
        end

        STATE_WRITE_DMEM: begin
            state_d = STATE_IDLE;
        end

        endcase
    end

    assign mem_req_ready  = (state_q == STATE_IDLE);
    assign mem_resp_valid = (state_q == STATE_READ_DMEM);
    assign mem_resp_data  = dmem_dout;

    assign dmem_din  = mem_req_data;
    assign dmem_addr = mem_req_addr;
    assign dmem_wbe  = (state_q == STATE_IDLE & mem_req_fire & mem_req_write) ? 4'b1111 : 4'b0; 

endmodule
