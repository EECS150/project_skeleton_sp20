`timescale 1ns/1ns

module io_dmem_testbench();
    reg clk, rst;
    parameter CPU_CLOCK_PERIOD = 20;
    parameter CPU_CLOCK_FREQ   = 1_000_000_000 / CPU_CLOCK_PERIOD;

    localparam AWIDTH    = 14;
    localparam DWIDTH    = 32;
    localparam MEM_DEPTH = 16384;

    initial clk = 0;
    always #(CPU_CLOCK_PERIOD/2) clk = ~clk;

    reg [31:0] timeout_cycle = 50000;

    reg [AWIDTH-1:0] req_read_addr;
    reg req_read_addr_valid;
    wire req_read_addr_ready;
    reg [31:0] req_read_len;

    wire [DWIDTH-1:0] resp_read_data;
    wire resp_read_data_valid;
    reg resp_read_data_ready;

    reg [AWIDTH-1:0] req_write_addr;
    reg req_write_addr_valid;
    wire req_write_addr_ready;
    reg [31:0] req_write_len;

    reg [DWIDTH-1:0] req_write_data;
    reg req_write_data_valid;
    wire req_write_data_ready;

    wire [AWIDTH-1:0] dmem_addra, dmem_addrb;
    wire [3:0]        dmem_wea, dmem_web;
    wire [DWIDTH-1:0] dmem_dina, dmem_douta, dmem_dinb, dmem_doutb;

    io_dmem_controller #(
        .AWIDTH(AWIDTH),
        .DWIDTH(DWIDTH),
        .MAX_BURST_LEN(8),
        .IO_LATENCY(10)
    ) io_dmem_controller (
        .clk(clk),
        .rst(rst),

        // Read Request Address channel
        .req_read_addr(req_read_addr),               // input
        .req_read_addr_valid(req_read_addr_valid),   // input
        .req_read_addr_ready(req_read_addr_ready),   // output
        .req_read_len(req_read_len),                 // input

        // Read Response channel
        .resp_read_data(resp_read_data),             // output
        .resp_read_data_valid(resp_read_data_valid), // output
        .resp_read_data_ready(resp_read_data_ready), // input

        // Write Request Address channel
        .req_write_addr(req_write_addr),             // input
        .req_write_addr_valid(req_write_addr_valid), // input
        .req_write_addr_ready(req_write_addr_ready), // output
        .req_write_len(req_write_len),               // input

        // Write Request Data channel
        .req_write_data(req_write_data),             // input
        .req_write_data_valid(req_write_data_valid), // input
        .req_write_data_ready(req_write_data_ready), // output

        // DMem PortA <---> IO Write
        .dmem_douta(dmem_douta), // input
        .dmem_dina(dmem_dina),   // output
        .dmem_addra(dmem_addra), // output
        .dmem_wea(dmem_wea),     // output

        // DMem PortB <---> IO Read
        .dmem_doutb(dmem_doutb), // input
        .dmem_dinb(dmem_dinb),   // output
        .dmem_addrb(dmem_addrb), // output
        .dmem_web(dmem_web)      // output
    );

    // DMem
    XILINX_SYNC_RAM_DP_WBE #(
        .AWIDTH(AWIDTH),
        .DWIDTH(DWIDTH),
        .DEPTH(MEM_DEPTH)
    ) dmem (
        .q0(dmem_douta),
        .d0(dmem_dina),
        .addr0(dmem_addra),
        .wbe0(dmem_wea),
        .q1(dmem_doutb),
        .d1(dmem_dinb),
        .addr1(dmem_addrb),
        .wbe1(dmem_web),
        .clk(clk), .rst(rst));

    reg [31:0] cycle = 0;
    integer i;

    wire req_read_addr_fire  = req_read_addr_valid  & req_read_addr_ready;
    wire resp_read_data_fire = resp_read_data_valid & resp_read_data_ready;
    wire req_write_addr_fire = req_write_addr_valid & req_write_addr_ready;
    wire req_wrie_data_fire  = req_write_data_valid & req_write_data_ready;

    initial begin
        #1;
        for (i = 0; i < MEM_DEPTH; i = i + 1) begin
            dmem.mem[i] = i * 100;
        end

        rst = 1'b1;

        req_read_addr        = 0;
        req_read_addr_valid  = 1'b0;
        req_read_len         = 32'd1;

        resp_read_data_ready = 1'b0;

        req_write_addr       = 0;
        req_write_addr_valid = 1'b0;
        req_write_len        = 32'd1;

        req_write_data       = 0;
        req_write_data_valid = 1'b0;

        // Hold reset for a while
        repeat (10) @(posedge clk);

        @(negedge clk);
        rst = 1'b0;

        repeat (10) @(posedge clk);

        // Read request with burst of 8
        @(negedge clk);
        req_read_addr = 32'd10;
        req_read_addr_valid = 1'b1;
        req_read_len  = 32'd8;
        resp_read_data_ready = 1'b1;
        @(negedge clk);
        req_read_addr_valid = 1'b0;

        repeat (20) @(posedge clk);


        // Write request with burst of 8
        @(negedge clk);
        req_write_addr       = 32'd20;
        req_write_addr_valid = 1'b1;
        req_write_len        = 32'd8;
        @(negedge clk);
        req_write_addr_valid = 1'b0;

        repeat (5) @(posedge clk);

        for (i = 0; i < req_write_len; i = i + 1) begin
            @(negedge clk);
            req_write_data       = 32'd5 + 2 * i;
            req_write_data_valid = 1'b1;
            while (req_write_data_ready == 0) begin
                @(posedge clk);
            end
        end

        repeat (100) @(posedge clk);
        $finish();
    end

    initial begin
        while (cycle < timeout_cycle) begin
            @(posedge clk);
            cycle = cycle + 1;
        end

        $display("[FAILED] Timing out");
        $finish();
    end
endmodule
