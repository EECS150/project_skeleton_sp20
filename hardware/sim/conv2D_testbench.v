`timescale 1ns/1ns

// conv2D standalone testbench (no Riscv151 core integration)
module conv2D_testbench();
    reg clk, rst;
    parameter CPU_CLOCK_PERIOD = 20;
    parameter CPU_CLOCK_FREQ   = 1_000_000_000 / CPU_CLOCK_PERIOD;

    localparam FM_DIM    = 8;
    localparam WT_DIM    = 3;
    localparam AWIDTH    = 14;
    localparam DWIDTH    = 32;
    localparam MEM_DEPTH = 16384;

    localparam WT_OFFSET  = 0;
    localparam IN_OFFSET  = WT_OFFSET + WT_DIM * WT_DIM;
    localparam OUT_OFFSET = IN_OFFSET + FM_DIM * FM_DIM;

    initial clk = 0;
    always #(CPU_CLOCK_PERIOD/2) clk = ~clk;

    reg [31:0] timeout_cycle = 500000;

    reg  start;
    wire idle;
    wire done;
    reg  [31:0] fm_dim;
    reg  [31:0] wt_offset, ifm_offset, ofm_offset;

    wire [AWIDTH-1:0] req_read_addr;
    wire req_read_addr_valid;
    wire req_read_addr_ready;
    wire [31:0] req_read_len;

    wire [DWIDTH-1:0] resp_read_data;
    wire resp_read_data_valid;
    wire resp_read_data_ready;

    wire [AWIDTH-1:0] req_write_addr;
    wire req_write_addr_valid;
    wire req_write_addr_ready;
    wire [31:0] req_write_len;

    wire [DWIDTH-1:0] req_write_data;
    wire req_write_data_valid;
    wire req_write_data_ready;

    wire [DWIDTH-1:0] resp_write_status;
    wire resp_write_status_valid;
    wire resp_write_status_ready;

    wire [AWIDTH-1:0] dmem_addra, dmem_addrb;
    wire [3:0]        dmem_wea, dmem_web;
    wire [DWIDTH-1:0] dmem_dina, dmem_douta, dmem_dinb, dmem_doutb;

    // conv2D_naive <---> io_dmem_controller <---> DMem

    conv2D_naive #(
        .AWIDTH(AWIDTH),
        .DWIDTH(DWIDTH),
        .WT_DIM(WT_DIM)
    ) conv2D_naive (
        .clk(clk),
        .rst(rst),

        .start(start),                                     // input
        .idle(idle),                                       // output
        .done(done),                                       // output

        .fm_dim(fm_dim),                                   // input
        .wt_offset(wt_offset),                             // input
        .ifm_offset(ifm_offset),                           // input
        .ofm_offset(ofm_offset),                           // input

        // Read Request Address channel
        .req_read_addr(req_read_addr),                     // output
        .req_read_addr_valid(req_read_addr_valid),         // output
        .req_read_addr_ready(req_read_addr_ready),         // input
        .req_read_len(req_read_len),                       // output

        // Read Response channel
        .resp_read_data(resp_read_data),                   // input
        .resp_read_data_valid(resp_read_data_valid),       // input
        .resp_read_data_ready(resp_read_data_ready),       // output

        // Write Request Address channel
        .req_write_addr(req_write_addr),                   // output
        .req_write_addr_valid(req_write_addr_valid),       // output
        .req_write_addr_ready(req_write_addr_ready),       // input
        .req_write_len(req_write_len),                     // output

        // Write Request Data channel
        .req_write_data(req_write_data),                   // output
        .req_write_data_valid(req_write_data_valid),       // output
        .req_write_data_ready(req_write_data_ready),       // input

        // Write Response channel
        .resp_write_status(resp_write_status),             // output
        .resp_write_status_valid(resp_write_status_valid), // output
        .resp_write_status_ready(resp_write_status_ready)  // input
    );

    io_dmem_controller #(
        .AWIDTH(AWIDTH),
        .DWIDTH(DWIDTH),
        .IO_LATENCY(10)
    ) io_dmem_controller (
        .clk(clk),
        .rst(rst),

        // Read Request Address channel
        .req_read_addr(req_read_addr),                     // input
        .req_read_addr_valid(req_read_addr_valid),         // input
        .req_read_addr_ready(req_read_addr_ready),         // output
        .req_read_len(req_read_len),                       // input

        // Read Response channel
        .resp_read_data(resp_read_data),                   // output
        .resp_read_data_valid(resp_read_data_valid),       // output
        .resp_read_data_ready(resp_read_data_ready),       // input

        // Write Request Address channel
        .req_write_addr(req_write_addr),                   // input
        .req_write_addr_valid(req_write_addr_valid),       // input
        .req_write_addr_ready(req_write_addr_ready),       // output
        .req_write_len(req_write_len),                     // input

        // Write Request Data channel
        .req_write_data(req_write_data),                   // input
        .req_write_data_valid(req_write_data_valid),       // input
        .req_write_data_ready(req_write_data_ready),       // output

        // Write Response channel
        .resp_write_status(resp_write_status),             // input
        .resp_write_status_valid(resp_write_status_valid), // input
        .resp_write_status_ready(resp_write_status_ready), // output

        // DMem PortA <---> IO Read
        .dmem_douta(dmem_douta), // input
        .dmem_dina(dmem_dina),   // output
        .dmem_addra(dmem_addra), // output
        .dmem_wea(dmem_wea),     // output

        // DMem PortB <---> IO Write
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


    reg [DWIDTH-1:0] ifm_data    [FM_DIM*FM_DIM-1:0];
    reg [DWIDTH-1:0] ofm_sw_data [FM_DIM*FM_DIM-1:0];
    reg [DWIDTH-1:0] weight_data [WT_DIM*WT_DIM-1:0];
    reg [DWIDTH-1:0] d;
    integer x, y, m, n, i, j;
    integer idx, idy;

    initial begin
        // init ifm and weight data
        #0;
        for (y = 0; y < FM_DIM; y = y + 1) begin
            for (x = 0; x < FM_DIM; x = x + 1) begin
                ifm_data[y * FM_DIM + x]     = x;
                ofm_sw_data[y * FM_DIM + x] = 0;
            end
        end

        for (m = 0; m < WT_DIM; m = m + 1) begin
            for (n = 0; n < WT_DIM; n = n + 1) begin
                weight_data[m * WT_DIM + n] = n;
            end
        end
    end

    initial begin
        // Software implementation of conv2D
        #1;
        for (y = 0; y < FM_DIM; y = y + 1) begin
            for (x = 0; x < FM_DIM; x = x + 1) begin
                for (m = 0; m < WT_DIM; m = m + 1) begin
                    for (n = 0; n < WT_DIM; n = n + 1) begin
                        idx = x - WT_DIM / 2 + n;
                        idy = y - WT_DIM / 2 + m;
                        // Check for halo cells
                        if (idx < 0 || idx >= FM_DIM || idy < 0 || idy >= FM_DIM)
                            d = 0;
                        else
                            d = ifm_data[idy * FM_DIM + idx];

                        ofm_sw_data[y * FM_DIM + x] = ofm_sw_data[y * FM_DIM + x] +
                                                      d * weight_data[m * WT_DIM + n];
                    end
                end
            end
        end
    end

    integer num_mismatches = 0;

    task init_data;
        begin
            for (i = 0; i < WT_DIM * WT_DIM; i = i + 1) begin
                dmem.mem[WT_OFFSET + i] = weight_data[i];
            end

            for (i = 0; i < FM_DIM * FM_DIM; i = i + 1) begin
                dmem.mem[IN_OFFSET  + i] = ifm_data[i];
                dmem.mem[OUT_OFFSET + i] = 0;
            end
        end
    endtask

    task check_result;
        begin
            for (i = 0; i < FM_DIM * FM_DIM; i = i + 1) begin
                if (dmem.mem[OUT_OFFSET + i] !== ofm_sw_data[i]) begin
                    num_mismatches = num_mismatches + 1;
                    $display("Mismatches at %d: expected=%d, got=%d",
                        i, ofm_sw_data[i], dmem.mem[OUT_OFFSET + i]);
                end
            end
            if (num_mismatches == 0)
                $display("Test passed!");
            else
                $display("Test failed! Num mismatches: %d", num_mismatches);
        end
    endtask

    reg [31:0] cycle = 0;

    initial begin
        #0;

        rst   = 1'b1;
        start = 1'b0;

        fm_dim     = FM_DIM;
        wt_offset  = WT_OFFSET;
        ifm_offset = IN_OFFSET;
        ofm_offset = OUT_OFFSET;

         // Hold reset for a while
        repeat (10) @(posedge clk);

        rst = 1'b0;
        init_data();

        repeat (10) @(posedge clk);

        @(negedge clk);
        start = 1'b1;
        $display("Start conv2D ...");

        @(negedge clk);
        start = 1'b0;

        while (done === 1'b0) begin
            @(posedge clk);
            cycle = cycle + 1;
        end

        $display("Simulation cycles. %d", cycle);
        check_result();
        $finish();
    end

    initial begin
        while (cycle < timeout_cycle) begin
            @(posedge clk);
        end

        $display("[FAILED] Timing out");
        $finish();
    end

endmodule
