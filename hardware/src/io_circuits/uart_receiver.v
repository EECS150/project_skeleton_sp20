module uart_receiver #(
    parameter CLOCK_FREQ = 125_000_000,
    parameter BAUD_RATE  = 115_200
) (
    input clk,
    input rst,

    // Dequeue the received character to the Sink
    output [7:0] data_out,
    output data_out_valid,
    input data_out_ready,

    // Serial bit input
    input serial_in
);
    // TODO: Your code

endmodule
