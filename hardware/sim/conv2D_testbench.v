`timescale 1ns/1ns

// conv2D standalone testbench (no Riscv151 core integration)
module conv2D_testbench();
    reg clk, rst;
    parameter CPU_CLOCK_PERIOD = 20;
    parameter CPU_CLOCK_FREQ   = 1_000_000_000 / CPU_CLOCK_PERIOD;

    localparam FM_DIM  = 8;
    localparam WT_DIM  = 3;
    localparam DWIDTH  = 32;

    localparam WT_OFFSET  = 0;
    localparam IN_OFFSET  = WT_OFFSET + WT_DIM * WT_DIM;
    localparam OUT_OFFSET = IN_OFFSET + FM_DIM * FM_DIM;

    initial clk = 0;
    always #(CPU_CLOCK_PERIOD/2) clk = ~clk;

    reg [31:0] timeout_cycle = 50000;

    reg start;
    wire idle;
    wire done;
    reg  [31:0]       fm_dim;
    reg  [31:0]       wt_offset, ifm_offset, ofm_offset;
    wire [31:0]       mem_req_addr;
    wire              mem_req_valid;
    wire              mem_req_ready;
    wire [DWIDTH-1:0] mem_req_data;
    wire              mem_req_write;
    wire [31:0]       mem_resp_data;
    wire              mem_resp_valid;
    wire              mem_resp_ready;

    // conv2D_naive <---> io_dmem_controller <---> DMem

    conv2D_naive #(
        .WT_DIM(WT_DIM),
        .DWIDTH(DWIDTH)
    ) conv2D_naive (
        .clk(clk),
        .rst(rst),

        .start(start),                   // input
        .idle(idle),                     // output
        .done(done),                     // output

        .fm_dim(fm_dim),                 // input
        .wt_offset(wt_offset),           // input
        .ifm_offset(ifm_offset),         // input
        .ofm_offset(ofm_offset),         // input

        .mem_req_addr(mem_req_addr),     // output
        .mem_req_valid(mem_req_valid),   // output
        .mem_req_ready(mem_req_ready),   // input
        .mem_req_data(mem_req_data),     // output
        .mem_req_write(mem_req_write),   // output

        .mem_resp_data(mem_resp_data),   // input
        .mem_resp_valid(mem_resp_valid), // input
        .mem_resp_ready(mem_resp_ready)  // output
    );

    // Simple memory model for testing
    wire [13:0] dmem_addr;
    wire [3:0]  dmem_wbe;
    wire [DWIDTH-1:0] dmem_din, dmem_dout;
    SYNC_RAM_WBE #(
        .AWIDTH(14),
        .DWIDTH(DWIDTH),
        .DEPTH(16384)
    ) dmem (
        .q(dmem_dout),    // output
        .d(dmem_din),     // input
        .addr(dmem_addr), // input
        .wbe(dmem_wbe),   // input
        .clk(clk), .rst(rst));

    io_dmem_controller #(
        .AWIDTH(14),
        .DWIDTH(DWIDTH),
        .IO_DMEM_LATENCY(1)
    ) io_dmem_controller (
        .clk(clk),
        .rst(rst),

        .mem_req_addr(mem_req_addr),     // input
        .mem_req_valid(mem_req_valid),   // input
        .mem_req_ready(mem_req_ready),   // output
        .mem_req_data(mem_req_data),     // input
        .mem_req_write(mem_req_write),   // input

        .mem_resp_data(mem_resp_data),   // output
        .mem_resp_valid(mem_resp_valid), // output
        .mem_resp_ready(mem_resp_ready), // input

        .dmem_dout(dmem_dout),           // input
        .dmem_din(dmem_din),             // output
        .dmem_addr(dmem_addr),           // output
        .dmem_wbe(dmem_wbe)              // output
    );

    reg [DWIDTH-1:0] fm_in_data     [FM_DIM*FM_DIM-1:0];
    reg [DWIDTH-1:0] sw_fm_out_data [FM_DIM*FM_DIM-1:0];
    reg [DWIDTH-1:0] weight_data     [WT_DIM*WT_DIM-1:0];
    reg [DWIDTH-1:0] d;
    integer x, y, m, n, i, j;
    integer idx, idy;

    initial begin
        // init fm_in and weight data
        #0;
        for (y = 0; y < FM_DIM; y = y + 1) begin
            for (x = 0; x < FM_DIM; x = x + 1) begin
                fm_in_data[y * FM_DIM + x]     = x;
                sw_fm_out_data[y * FM_DIM + x] = 0;
            end
        end

        weight_data[0] = 1; weight_data[1] = 2; weight_data[2] = 1;
        weight_data[3] = 4; weight_data[4] = 5; weight_data[5] = 4;
        weight_data[6] = 1; weight_data[7] = 2; weight_data[8] = 1;
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
                            d = fm_in_data[idy * FM_DIM + idx];

                        sw_fm_out_data[y * FM_DIM + x] = sw_fm_out_data[y * FM_DIM + x] +
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
                dmem.mem[IN_OFFSET  + i] = fm_in_data[i];
                dmem.mem[OUT_OFFSET + i] = 0;
            end
        end
    endtask

    task check_result;
        begin
            for (i = 0; i < FM_DIM * FM_DIM; i = i + 1) begin
                if (dmem.mem[OUT_OFFSET + i] !== sw_fm_out_data[i]) begin
                    num_mismatches = num_mismatches + 1;
                    $display("Mismatches at %d: expected=%d, got=%d",
                        i, sw_fm_out_data[i], dmem.mem[OUT_OFFSET + i]);
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

        #100;

        check_result();
        $finish();
    end

    always @(posedge clk) begin
        $display("[Cycle %d] conv2D_naive.start=%b, conv2D_naive.idle=%b, conv2D_naive.done=%b, mem_req_addr=%h, mem_req_valid=%b, mem_req_ready=%b, mem_req_data=%h, mem_req_write=%b, mem_resp_data=%h, mem_resp_valid=%b, mem_resp_ready=%b, dmem_addr=%h, dmem_din=%h, dmem_dout=%h, dmem_wbe=%h, state=%d, acc_q=%d, m=%d, n=%d, x=%d, y=%d, wdata_valid=%b, wdata=%d, halo=%b, d=%d, wt0=%d, wt1=%d, wt2=%d, wt3=%d, wt4=%d, wt5=%d, wt6=%d, wt7=%d, wt8=%d",
            cycle, start, idle, done,

            mem_req_addr, mem_req_valid, mem_req_ready, mem_req_data, mem_req_write,
            mem_resp_data, mem_resp_valid, mem_resp_ready,

            dmem_addr, dmem_din, dmem_dout, dmem_wbe,

            conv2D_naive.compute_unit.state_q, conv2D_naive.compute_unit.acc_q,
            conv2D_naive.compute_unit.m_cnt_q, conv2D_naive.compute_unit.n_cnt_q,
            conv2D_naive.compute_unit.x, conv2D_naive.compute_unit.y,
            conv2D_naive.compute_unit.wdata_valid, conv2D_naive.compute_unit.wdata,
            conv2D_naive.compute_unit.halo, conv2D_naive.compute_unit.d,
            conv2D_naive.compute_unit.wt_regs_q[0], 
            conv2D_naive.compute_unit.wt_regs_q[1], 
            conv2D_naive.compute_unit.wt_regs_q[2], 
            conv2D_naive.compute_unit.wt_regs_q[3], 
            conv2D_naive.compute_unit.wt_regs_q[4], 
            conv2D_naive.compute_unit.wt_regs_q[5], 
            conv2D_naive.compute_unit.wt_regs_q[6], 
            conv2D_naive.compute_unit.wt_regs_q[7], 
            conv2D_naive.compute_unit.wt_regs_q[8]
        );
    end

    initial begin
        while (cycle < timeout_cycle) begin
            @(posedge clk);
        end

        $display("[FAILED] Timing out");
        $finish();
    end

endmodule
