/*
    This is a wrapper module for the synchronizer -> debouncer -> edge detector signal chain for button inputs
*/
module button_parser #(
    parameter width = 1,
    parameter sample_count_max = 25000,
    parameter pulse_count_max = 150
) (
    input clk,
    input [width-1:0] in,
    output [width-1:0] out
);

    wire [width-1:0] synchronized_signals;
    wire [width-1:0] debounced_signals;

    synchronizer # (
        .width(width)
    ) button_synchronizer (
        .clk(clk),
        .async_signal(in),
        .sync_signal(synchronized_signals)
    );

    debouncer # (
        .width(width),
        .sample_count_max(sample_count_max),
        .pulse_count_max(pulse_count_max)
    ) button_debouncer (
        .clk(clk),
        .glitchy_signal(synchronized_signals),
        .debounced_signal(debounced_signals)
    );

    edge_detector # (
        .width(width)
    ) button_edge_detector (
        .clk(clk),
        .signal_in(debounced_signals),
        .edge_detect_pulse(out)
    );

endmodule
