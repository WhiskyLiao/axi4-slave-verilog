// Self-checking testbench for axi4_slave
// Tests: single write/read, burst INCR write/read, WRAP burst, out-of-range SLVERR,
//        byte-enable (WSTRB) masking, back-pressure on BREADY/RREADY.
`timescale 1ns/1ps

module axi4_slave_tb;

    localparam AXI_ADDR_WIDTH    = 32;
    localparam AXI_DATA_WIDTH    = 32;
    localparam AXI_ID_WIDTH      = 4;
    localparam AXI_USER_WIDTH    = 1;
    localparam MEM_DEPTH         = 256;
    localparam OUTSTANDING_DEPTH = 4;
    localparam STRB_WIDTH        = AXI_DATA_WIDTH / 8;

    // -----------------------------------------------------------------------
    // Clock / reset
    // -----------------------------------------------------------------------
    reg ACLK    = 0;
    reg ARESETn = 0;
    always #5 ACLK = ~ACLK;

    // -----------------------------------------------------------------------
    // AXI signals
    // -----------------------------------------------------------------------
    reg  [AXI_ID_WIDTH-1:0]   AWID     = 0;
    reg  [AXI_ADDR_WIDTH-1:0] AWADDR   = 0;
    reg  [7:0]                AWLEN    = 0;
    reg  [2:0]                AWSIZE   = 2;
    reg  [1:0]                AWBURST  = 2'b01;
    reg                       AWLOCK   = 0;
    reg  [3:0]                AWCACHE  = 0;
    reg  [2:0]                AWPROT   = 0;
    reg  [3:0]                AWQOS    = 0;
    reg  [3:0]                AWREGION = 0;
    reg  [AXI_USER_WIDTH-1:0] AWUSER   = 0;
    reg                       AWVALID  = 0;
    wire                      AWREADY;

    reg  [AXI_DATA_WIDTH-1:0] WDATA  = 0;
    reg  [STRB_WIDTH-1:0]     WSTRB  = {STRB_WIDTH{1'b1}};
    reg                       WLAST  = 0;
    reg  [AXI_USER_WIDTH-1:0] WUSER  = 0;
    reg                       WVALID = 0;
    wire                      WREADY;

    wire [AXI_ID_WIDTH-1:0]   BID;
    wire [1:0]                BRESP;
    wire [AXI_USER_WIDTH-1:0] BUSER;
    wire                      BVALID;
    reg                       BREADY = 1;

    reg  [AXI_ID_WIDTH-1:0]   ARID     = 0;
    reg  [AXI_ADDR_WIDTH-1:0] ARADDR   = 0;
    reg  [7:0]                ARLEN    = 0;
    reg  [2:0]                ARSIZE   = 2;
    reg  [1:0]                ARBURST  = 2'b01;
    reg                       ARLOCK   = 0;
    reg  [3:0]                ARCACHE  = 0;
    reg  [2:0]                ARPROT   = 0;
    reg  [3:0]                ARQOS    = 0;
    reg  [3:0]                ARREGION = 0;
    reg  [AXI_USER_WIDTH-1:0] ARUSER   = 0;
    reg                       ARVALID  = 0;
    wire                      ARREADY;

    wire [AXI_ID_WIDTH-1:0]   RID;
    wire [AXI_DATA_WIDTH-1:0] RDATA;
    wire [1:0]                RRESP;
    wire                      RLAST;
    wire [AXI_USER_WIDTH-1:0] RUSER;
    wire                      RVALID;
    reg                       RREADY = 1;

    // -----------------------------------------------------------------------
    // DUT
    // -----------------------------------------------------------------------
    axi4_slave #(
        .AXI_ADDR_WIDTH    (AXI_ADDR_WIDTH),
        .AXI_DATA_WIDTH    (AXI_DATA_WIDTH),
        .AXI_ID_WIDTH      (AXI_ID_WIDTH),
        .AXI_USER_WIDTH    (AXI_USER_WIDTH),
        .MEM_DEPTH         (MEM_DEPTH),
        .OUTSTANDING_DEPTH (OUTSTANDING_DEPTH)
    ) dut (
        .ACLK(ACLK), .ARESETn(ARESETn),
        .AWID(AWID), .AWADDR(AWADDR), .AWLEN(AWLEN), .AWSIZE(AWSIZE),
        .AWBURST(AWBURST), .AWLOCK(AWLOCK), .AWCACHE(AWCACHE), .AWPROT(AWPROT),
        .AWQOS(AWQOS), .AWREGION(AWREGION), .AWUSER(AWUSER),
        .AWVALID(AWVALID), .AWREADY(AWREADY),
        .WDATA(WDATA), .WSTRB(WSTRB), .WLAST(WLAST), .WUSER(WUSER),
        .WVALID(WVALID), .WREADY(WREADY),
        .BID(BID), .BRESP(BRESP), .BUSER(BUSER), .BVALID(BVALID), .BREADY(BREADY),
        .ARID(ARID), .ARADDR(ARADDR), .ARLEN(ARLEN), .ARSIZE(ARSIZE),
        .ARBURST(ARBURST), .ARLOCK(ARLOCK), .ARCACHE(ARCACHE), .ARPROT(ARPROT),
        .ARQOS(ARQOS), .ARREGION(ARREGION), .ARUSER(ARUSER),
        .ARVALID(ARVALID), .ARREADY(ARREADY),
        .RID(RID), .RDATA(RDATA), .RRESP(RRESP), .RLAST(RLAST),
        .RUSER(RUSER), .RVALID(RVALID), .RREADY(RREADY)
    );

    // -----------------------------------------------------------------------
    // Scoreboard
    // -----------------------------------------------------------------------
    integer pass_count = 0;
    integer fail_count = 0;

    task check_data;
        input [127:0]              tag;
        input [AXI_DATA_WIDTH-1:0] got;
        input [AXI_DATA_WIDTH-1:0] exp;
        begin
            if (got === exp) begin
                $display("[PASS] %0s  got=0x%08h", tag, got);
                pass_count = pass_count + 1;
            end else begin
                $display("[FAIL] %0s  got=0x%08h  exp=0x%08h", tag, got, exp);
                fail_count = fail_count + 1;
            end
        end
    endtask

    task check_resp;
        input [127:0] tag;
        input [1:0]   got;
        input [1:0]   exp;
        begin
            if (got === exp) begin
                $display("[PASS] %0s  resp=0b%02b", tag, got);
                pass_count = pass_count + 1;
            end else begin
                $display("[FAIL] %0s  resp got=0b%02b  exp=0b%02b", tag, got, exp);
                fail_count = fail_count + 1;
            end
        end
    endtask

    // -----------------------------------------------------------------------
    // Shared capture variables (avoids array task-port iverilog limitation)
    // -----------------------------------------------------------------------
    reg [AXI_DATA_WIDTH-1:0] cap_data;
    reg [1:0]                cap_resp;
    // Flat capture for burst beats (max 16 for these tests)
    reg [AXI_DATA_WIDTH-1:0] burst_cap [0:15];

    // -----------------------------------------------------------------------
    // AXI master tasks
    // -----------------------------------------------------------------------

    task do_aw;
        input [AXI_ID_WIDTH-1:0]   id;
        input [AXI_ADDR_WIDTH-1:0] addr;
        input [7:0]                len;
        input [1:0]                burst;
        begin
            @(posedge ACLK); #1;
            AWID=id; AWADDR=addr; AWLEN=len; AWSIZE=2; AWBURST=burst; AWVALID=1;
            @(posedge ACLK);
            while (!AWREADY) @(posedge ACLK);
            #1; AWVALID=0;
        end
    endtask

    task do_w_beat;
        input [AXI_DATA_WIDTH-1:0] data;
        input [STRB_WIDTH-1:0]     strb;
        input                      last;
        begin
            WDATA=data; WSTRB=strb; WLAST=last; WVALID=1;
            @(posedge ACLK);
            while (!WREADY) @(posedge ACLK);
            #1; WVALID=0; WLAST=0;
        end
    endtask

    task do_b;
        begin
            // Wait until BVALID is high at a posedge (handles back-pressure)
            while (!BVALID) @(posedge ACLK);
            cap_resp = BRESP;
            @(posedge ACLK); #1;
        end
    endtask

    task do_ar;
        input [AXI_ID_WIDTH-1:0]   id;
        input [AXI_ADDR_WIDTH-1:0] addr;
        input [7:0]                len;
        input [1:0]                burst;
        begin
            @(posedge ACLK); #1;
            ARID=id; ARADDR=addr; ARLEN=len; ARSIZE=2; ARBURST=burst; ARVALID=1;
            @(posedge ACLK);
            while (!ARREADY) @(posedge ACLK);
            #1; ARVALID=0;
        end
    endtask

    task do_r_beat;
        begin
            // Wait at posedge boundaries until RVALID is asserted
            while (!RVALID) @(posedge ACLK);
            cap_data = RDATA;
            cap_resp = RRESP;
            @(posedge ACLK); #1;
        end
    endtask

    // Convenience: single-beat write
    task axi_write;
        input [AXI_ID_WIDTH-1:0]   id;
        input [AXI_ADDR_WIDTH-1:0] addr;
        input [AXI_DATA_WIDTH-1:0] data;
        input [STRB_WIDTH-1:0]     strb;
        begin
            do_aw(id, addr, 8'd0, 2'b01);
            do_w_beat(data, strb, 1'b1);
            do_b();
        end
    endtask

    // Convenience: single-beat read
    task axi_read;
        input [AXI_ID_WIDTH-1:0]   id;
        input [AXI_ADDR_WIDTH-1:0] addr;
        begin
            do_ar(id, addr, 8'd0, 2'b01);
            do_r_beat();
            @(posedge ACLK); #1;
        end
    endtask

    integer k;

    // -----------------------------------------------------------------------
    // Stimulus
    // -----------------------------------------------------------------------
    initial begin
        $dumpfile("sim/axi4_slave_tb.vcd");
        $dumpvars(0, axi4_slave_tb);

        repeat(5) @(posedge ACLK);
        ARESETn = 1;
        repeat(3) @(posedge ACLK);

        // ==================================================================
        $display("\n=== TEST 1: Single write then read ===");
        axi_write(4'h1, 32'h0000_0000, 32'hDEAD_BEEF, 4'hF);
        check_resp("T1 write resp", cap_resp, 2'b00);
        axi_read(4'h1, 32'h0000_0000);
        check_data("T1 read data", cap_data, 32'hDEAD_BEEF);
        check_resp("T1 read resp", cap_resp, 2'b00);

        // ==================================================================
        $display("\n=== TEST 2: Byte-enable (WSTRB) masking ===");
        axi_write(4'h2, 32'h0000_0010, 32'hFFFF_FFFF, 4'hF);
        axi_write(4'h2, 32'h0000_0010, 32'hAB00_0000, 4'h8);
        axi_read(4'h2, 32'h0000_0010);
        check_data("T2 strobe mask", cap_data, 32'hABFF_FFFF);

        // ==================================================================
        $display("\n=== TEST 3: INCR burst write + burst read (8 beats) ===");
        do_aw(4'h3, 32'h0000_0100, 8'd7, 2'b01);
        for (k=0; k<=7; k=k+1)
            do_w_beat(32'hA000_0000 | k, 4'hF, (k==7));
        do_b();
        check_resp("T3 burst write resp", cap_resp, 2'b00);

        do_ar(4'h3, 32'h0000_0100, 8'd7, 2'b01);
        for (k=0; k<=7; k=k+1) begin
            do_r_beat();
            burst_cap[k] = cap_data;
        end
        @(posedge ACLK); #1;
        for (k=0; k<=7; k=k+1)
            check_data("T3 burst beat", burst_cap[k], 32'hA000_0000 | k);

        // ==================================================================
        $display("\n=== TEST 4: WRAP burst (8 beats) ===");
        do_aw(4'h4, 32'h0000_0200, 8'd7, 2'b10);
        for (k=0; k<=7; k=k+1)
            do_w_beat(32'hC000_0000 | k, 4'hF, (k==7));
        do_b();
        check_resp("T4 WRAP write resp", cap_resp, 2'b00);

        do_ar(4'h4, 32'h0000_0200, 8'd7, 2'b10);
        for (k=0; k<=7; k=k+1) begin
            do_r_beat();
            burst_cap[k] = cap_data;
        end
        @(posedge ACLK); #1;
        for (k=0; k<=7; k=k+1)
            check_data("T4 WRAP beat", burst_cap[k], 32'hC000_0000 | k);

        // ==================================================================
        $display("\n=== TEST 5: Out-of-range address -> SLVERR ===");
        axi_write(4'h5, 32'hFFFF_FF00, 32'h1234_5678, 4'hF);
        check_resp("T5 OOB write resp", cap_resp, 2'b10);
        axi_read(4'h5, 32'hFFFF_FF00);
        check_resp("T5 OOB read resp", cap_resp, 2'b10);

        // ==================================================================
        $display("\n=== TEST 6: Back-pressure on BREADY ===");
        BREADY = 0;
        // Issue AW + W, slave will assert BVALID but can't complete until BREADY
        do_aw(4'h6, 32'h0000_0004, 8'd0, 2'b01);
        do_w_beat(32'hCAFE_BABE, 4'hF, 1'b1);
        repeat(5) @(posedge ACLK);
        BREADY = 1;
        do_b();
        check_resp("T6 BP write resp", cap_resp, 2'b00);
        axi_read(4'h6, 32'h0000_0004);
        check_data("T6 BP data", cap_data, 32'hCAFE_BABE);

        // ==================================================================
        $display("\n=== TEST 7: Back-pressure on RREADY ===");
        axi_write(4'h7, 32'h0000_0008, 32'hBEEF_CAFE, 4'hF);
        RREADY = 0;
        do_ar(4'h7, 32'h0000_0008, 8'd0, 2'b01);
        repeat(5) @(posedge ACLK);
        RREADY = 1;
        do_r_beat();
        check_data("T7 RREADY BP data", cap_data, 32'hBEEF_CAFE);
        check_resp("T7 RREADY BP resp", cap_resp, 2'b00);
        @(posedge ACLK); #1;

        // ==================================================================
        $display("\n=== TEST 8: Multiple IDs in sequence ===");
        axi_write(4'hA, 32'h0000_0020, 32'h1111_1111, 4'hF);
        axi_write(4'hB, 32'h0000_0024, 32'h2222_2222, 4'hF);
        axi_read(4'hA, 32'h0000_0020);
        check_data("T8 ID-A data", cap_data, 32'h1111_1111);
        axi_read(4'hB, 32'h0000_0024);
        check_data("T8 ID-B data", cap_data, 32'h2222_2222);

        // ==================================================================
        $display("\n=== RESULTS ===");
        $display("PASS: %0d   FAIL: %0d", pass_count, fail_count);
        if (fail_count == 0)
            $display("*** ALL TESTS PASSED ***");
        else
            $display("*** SOME TESTS FAILED ***");
        $finish;
    end

    initial begin
        #500000;
        $display("[ERROR] Simulation timeout");
        $finish;
    end

endmodule
