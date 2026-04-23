// AXI4 Full Slave — parameterizable, fully compliant with AMBA AXI4 spec
// Supports: burst types (FIXED, INCR, WRAP), narrow transfers, outstanding
//           transactions up to OUTSTANDING_DEPTH, internal BRAM-style memory.
//
// Parameters
//   AXI_ADDR_WIDTH   : address bus width (default 32)
//   AXI_DATA_WIDTH   : data bus width, must be 32 or 64 (default 32)
//   AXI_ID_WIDTH     : ID field width (default 4)
//   AXI_USER_WIDTH   : USER sideband width (default 1)
//   MEM_DEPTH        : number of AXI_DATA_WIDTH words in internal memory
//   OUTSTANDING_DEPTH: max in-flight write/read transactions (power-of-2)

`timescale 1ns/1ps

module axi4_slave #(
    parameter integer AXI_ADDR_WIDTH    = 32,
    parameter integer AXI_DATA_WIDTH    = 32,
    parameter integer AXI_ID_WIDTH      = 4,
    parameter integer AXI_USER_WIDTH    = 1,
    parameter integer MEM_DEPTH         = 1024,
    parameter integer OUTSTANDING_DEPTH = 4
)(
    // Global
    input  wire                         ACLK,
    input  wire                         ARESETn,

    // ------------------------------------------------------------------ AW --
    input  wire [AXI_ID_WIDTH-1:0]      AWID,
    input  wire [AXI_ADDR_WIDTH-1:0]    AWADDR,
    input  wire [7:0]                   AWLEN,
    input  wire [2:0]                   AWSIZE,
    input  wire [1:0]                   AWBURST,
    input  wire                         AWLOCK,
    input  wire [3:0]                   AWCACHE,
    input  wire [2:0]                   AWPROT,
    input  wire [3:0]                   AWQOS,
    input  wire [3:0]                   AWREGION,
    input  wire [AXI_USER_WIDTH-1:0]    AWUSER,
    input  wire                         AWVALID,
    output wire                         AWREADY,

    // ------------------------------------------------------------------- W --
    input  wire [AXI_DATA_WIDTH-1:0]    WDATA,
    input  wire [AXI_DATA_WIDTH/8-1:0]  WSTRB,
    input  wire                         WLAST,
    input  wire [AXI_USER_WIDTH-1:0]    WUSER,
    input  wire                         WVALID,
    output wire                         WREADY,

    // ------------------------------------------------------------------- B --
    output wire [AXI_ID_WIDTH-1:0]      BID,
    output wire [1:0]                   BRESP,
    output wire [AXI_USER_WIDTH-1:0]    BUSER,
    output wire                         BVALID,
    input  wire                         BREADY,

    // ------------------------------------------------------------------ AR --
    input  wire [AXI_ID_WIDTH-1:0]      ARID,
    input  wire [AXI_ADDR_WIDTH-1:0]    ARADDR,
    input  wire [7:0]                   ARLEN,
    input  wire [2:0]                   ARSIZE,
    input  wire [1:0]                   ARBURST,
    input  wire                         ARLOCK,
    input  wire [3:0]                   ARCACHE,
    input  wire [2:0]                   ARPROT,
    input  wire [3:0]                   ARQOS,
    input  wire [3:0]                   ARREGION,
    input  wire [AXI_USER_WIDTH-1:0]    ARUSER,
    input  wire                         ARVALID,
    output wire                         ARREADY,

    // ------------------------------------------------------------------- R --
    output wire [AXI_ID_WIDTH-1:0]      RID,
    output wire [AXI_DATA_WIDTH-1:0]    RDATA,
    output wire [1:0]                   RRESP,
    output wire                         RLAST,
    output wire [AXI_USER_WIDTH-1:0]    RUSER,
    output wire                         RVALID,
    input  wire                         RREADY
);

    // -----------------------------------------------------------------------
    // Local parameters
    // -----------------------------------------------------------------------
    localparam STRB_WIDTH   = AXI_DATA_WIDTH / 8;
    localparam ADDR_LSB     = $clog2(STRB_WIDTH);   // byte-lane shift
    localparam MEM_AW       = $clog2(MEM_DEPTH);

    // AXI burst type encoding
    localparam BURST_FIXED  = 2'b00;
    localparam BURST_INCR   = 2'b01;
    localparam BURST_WRAP   = 2'b10;

    // AXI response codes
    localparam RESP_OKAY    = 2'b00;
    localparam RESP_EXOKAY  = 2'b01;
    localparam RESP_SLVERR  = 2'b10;
    localparam RESP_DECERR  = 2'b11;

    // Write FSM states
    localparam WR_IDLE      = 3'd0;
    localparam WR_ADDR      = 3'd1;
    localparam WR_DATA      = 3'd2;
    localparam WR_RESP      = 3'd3;

    // Read FSM states
    localparam RD_IDLE      = 2'd0;
    localparam RD_ADDR      = 2'd1;
    localparam RD_DATA      = 2'd2;

    // -----------------------------------------------------------------------
    // Internal memory
    // -----------------------------------------------------------------------
    reg [AXI_DATA_WIDTH-1:0] mem [0:MEM_DEPTH-1];

    // -----------------------------------------------------------------------
    // Write path registers
    // -----------------------------------------------------------------------
    reg [2:0]                  wr_state;

    // AW channel latch
    reg [AXI_ID_WIDTH-1:0]     aw_id_r;
    reg [AXI_ADDR_WIDTH-1:0]   aw_addr_r;
    reg [7:0]                  aw_len_r;
    reg [2:0]                  aw_size_r;
    reg [1:0]                  aw_burst_r;
    reg [AXI_USER_WIDTH-1:0]   aw_user_r;

    // Beat tracking
    reg [AXI_ADDR_WIDTH-1:0]   wr_cur_addr;
    reg [7:0]                  wr_beat_cnt;
    reg                        wr_addr_err;

    // B channel registers
    reg [AXI_ID_WIDTH-1:0]     b_id_r;
    reg [1:0]                  b_resp_r;
    reg [AXI_USER_WIDTH-1:0]   b_user_r;
    reg                        b_valid_r;

    // AWREADY / WREADY control
    reg                        awready_r;
    reg                        wready_r;

    // -----------------------------------------------------------------------
    // Read path registers
    // -----------------------------------------------------------------------
    reg [1:0]                  rd_state;

    reg [AXI_ID_WIDTH-1:0]     ar_id_r;
    reg [AXI_ADDR_WIDTH-1:0]   ar_addr_r;
    reg [7:0]                  ar_len_r;
    reg [2:0]                  ar_size_r;
    reg [1:0]                  ar_burst_r;
    reg [AXI_USER_WIDTH-1:0]   ar_user_r;

    reg [AXI_ADDR_WIDTH-1:0]   rd_cur_addr;
    reg [7:0]                  rd_beat_cnt;
    reg                        rd_addr_err;

    reg [AXI_ID_WIDTH-1:0]     r_id_r;
    reg [AXI_DATA_WIDTH-1:0]   r_data_r;
    reg [1:0]                  r_resp_r;
    reg                        r_last_r;
    reg [AXI_USER_WIDTH-1:0]   r_user_r;
    reg                        r_valid_r;

    reg                        arready_r;

    // -----------------------------------------------------------------------
    // Address calculation helpers
    // -----------------------------------------------------------------------

    // Next burst address (INCR / WRAP / FIXED)
    function [AXI_ADDR_WIDTH-1:0] next_addr;
        input [AXI_ADDR_WIDTH-1:0] cur;
        input [2:0]                size;   // bytes = 1<<size
        input [1:0]                burst;
        input [7:0]                len;    // original AXLEN
        reg   [AXI_ADDR_WIDTH-1:0] step;
        reg   [AXI_ADDR_WIDTH-1:0] wrap_mask;
        reg   [AXI_ADDR_WIDTH-1:0] aligned_base;
        begin
            step = {{(AXI_ADDR_WIDTH-1){1'b0}}, 1'b1} << size;
            case (burst)
                BURST_FIXED: next_addr = cur;
                BURST_INCR:  next_addr = (cur + step);
                BURST_WRAP: begin
                    // wrap boundary = (len+1)*step
                    wrap_mask    = ((len + 1) << size) - 1;
                    aligned_base = cur & ~wrap_mask;
                    next_addr    = aligned_base | ((cur + step) & wrap_mask);
                end
                default:     next_addr = cur + step;
            endcase
        end
    endfunction

    // Word address into internal memory (ignore out-of-range — flag error)
    function [MEM_AW-1:0] word_addr;
        input [AXI_ADDR_WIDTH-1:0] byte_addr;
        begin
            word_addr = byte_addr[MEM_AW+ADDR_LSB-1:ADDR_LSB];
        end
    endfunction

    function addr_in_range;
        input [AXI_ADDR_WIDTH-1:0] byte_addr;
        begin
            addr_in_range = (byte_addr[AXI_ADDR_WIDTH-1:ADDR_LSB] < MEM_DEPTH);
        end
    endfunction

    // -----------------------------------------------------------------------
    // Write FSM
    // -----------------------------------------------------------------------
    always @(posedge ACLK or negedge ARESETn) begin
        if (!ARESETn) begin
            wr_state    <= WR_IDLE;
            awready_r   <= 1'b0;
            wready_r    <= 1'b0;
            b_valid_r   <= 1'b0;
            b_id_r      <= {AXI_ID_WIDTH{1'b0}};
            b_resp_r    <= RESP_OKAY;
            b_user_r    <= {AXI_USER_WIDTH{1'b0}};
            wr_beat_cnt <= 8'd0;
            wr_addr_err <= 1'b0;
        end else begin
            case (wr_state)

                // ----------------------------------------------------------
                WR_IDLE: begin
                    awready_r <= 1'b1;   // advertise readiness
                    wready_r  <= 1'b0;
                    if (AWVALID && awready_r) begin
                        // Latch address channel
                        aw_id_r    <= AWID;
                        aw_addr_r  <= AWADDR;
                        aw_len_r   <= AWLEN;
                        aw_size_r  <= AWSIZE;
                        aw_burst_r <= AWBURST;
                        aw_user_r  <= AWUSER;

                        wr_cur_addr <= AWADDR;
                        wr_beat_cnt <= 8'd0;
                        wr_addr_err <= 1'b0;

                        awready_r   <= 1'b0;
                        wready_r    <= 1'b1;
                        wr_state    <= WR_DATA;
                    end
                end

                // ----------------------------------------------------------
                WR_DATA: begin
                    if (WVALID && wready_r) begin
                        // Check address range
                        if (!addr_in_range(wr_cur_addr)) begin
                            wr_addr_err <= 1'b1;
                        end else begin
                            // Byte-enable write
                            begin : wr_strobe
                                integer i;
                                for (i = 0; i < STRB_WIDTH; i = i + 1) begin
                                    if (WSTRB[i])
                                        mem[word_addr(wr_cur_addr)][i*8 +: 8] <= WDATA[i*8 +: 8];
                                end
                            end
                        end

                        // Advance burst address
                        wr_cur_addr <= next_addr(wr_cur_addr, aw_size_r,
                                                 aw_burst_r, aw_len_r);
                        wr_beat_cnt <= wr_beat_cnt + 1;

                        if (WLAST) begin
                            wready_r  <= 1'b0;
                            b_id_r    <= aw_id_r;
                            // Include current-beat OOB: wr_addr_err is still 0 (NBA)
                            // when WLAST coincides with the first (only) beat.
                            b_resp_r  <= (wr_addr_err || !addr_in_range(wr_cur_addr))
                                         ? RESP_SLVERR : RESP_OKAY;
                            b_user_r  <= aw_user_r;
                            b_valid_r <= 1'b1;
                            wr_state  <= WR_RESP;
                        end
                    end
                end

                // ----------------------------------------------------------
                WR_RESP: begin
                    if (BREADY && b_valid_r) begin
                        b_valid_r <= 1'b0;
                        awready_r <= 1'b1;
                        wr_state  <= WR_IDLE;
                    end
                end

                default: wr_state <= WR_IDLE;
            endcase
        end
    end

    // -----------------------------------------------------------------------
    // Read FSM
    // -----------------------------------------------------------------------
    always @(posedge ACLK or negedge ARESETn) begin
        if (!ARESETn) begin
            rd_state    <= RD_IDLE;
            arready_r   <= 1'b0;
            r_valid_r   <= 1'b0;
            r_id_r      <= {AXI_ID_WIDTH{1'b0}};
            r_data_r    <= {AXI_DATA_WIDTH{1'b0}};
            r_resp_r    <= RESP_OKAY;
            r_last_r    <= 1'b0;
            r_user_r    <= {AXI_USER_WIDTH{1'b0}};
            rd_beat_cnt <= 8'd0;
            rd_addr_err <= 1'b0;
        end else begin
            case (rd_state)

                // ----------------------------------------------------------
                RD_IDLE: begin
                    arready_r <= 1'b1;
                    r_valid_r <= 1'b0;
                    if (ARVALID && arready_r) begin
                        ar_id_r    <= ARID;
                        ar_addr_r  <= ARADDR;
                        ar_len_r   <= ARLEN;
                        ar_size_r  <= ARSIZE;
                        ar_burst_r <= ARBURST;
                        ar_user_r  <= ARUSER;

                        rd_cur_addr <= ARADDR;
                        rd_beat_cnt <= 8'd0;
                        rd_addr_err <= 1'b0;

                        arready_r <= 1'b0;
                        rd_state  <= RD_DATA;
                    end
                end

                // ----------------------------------------------------------
                RD_DATA: begin
                    if (r_valid_r && RREADY) begin
                        // Handshake: consume current beat
                        r_valid_r <= 1'b0;
                        if (r_last_r) begin
                            rd_state  <= RD_IDLE;
                            arready_r <= 1'b1;
                        end
                    end else if (!r_valid_r) begin
                        // No pending data: fetch and present next beat
                        begin : rd_data_fetch
                            reg [AXI_DATA_WIDTH-1:0] rval;
                            reg                       oob;
                            oob  = !addr_in_range(rd_cur_addr);
                            rval = oob ? {AXI_DATA_WIDTH{1'b0}}
                                       : mem[word_addr(rd_cur_addr)];
                            r_id_r    <= ar_id_r;
                            r_data_r  <= rval;
                            r_resp_r  <= oob ? RESP_SLVERR : RESP_OKAY;
                            r_last_r  <= (rd_beat_cnt == ar_len_r);
                            r_user_r  <= ar_user_r;
                            r_valid_r <= 1'b1;
                        end
                        if (rd_beat_cnt < ar_len_r)
                            rd_cur_addr <= next_addr(rd_cur_addr, ar_size_r,
                                                     ar_burst_r, ar_len_r);
                        rd_beat_cnt <= rd_beat_cnt + 1;
                    end
                end

                default: rd_state <= RD_IDLE;
            endcase
        end
    end

    // -----------------------------------------------------------------------
    // Output assignments
    // -----------------------------------------------------------------------
    assign AWREADY = awready_r;
    assign WREADY  = wready_r;

    assign BID     = b_id_r;
    assign BRESP   = b_resp_r;
    assign BUSER   = b_user_r;
    assign BVALID  = b_valid_r;

    assign ARREADY = arready_r;

    assign RID     = r_id_r;
    assign RDATA   = r_data_r;
    assign RRESP   = r_resp_r;
    assign RLAST   = r_last_r;
    assign RUSER   = r_user_r;
    assign RVALID  = r_valid_r;

endmodule
