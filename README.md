# AXI4 Slave — Verilog

A parameterisable, fully compliant AMBA AXI4 Full slave implemented in synthesisable Verilog, with an internal BRAM-style memory. Supports all three burst types, byte-enable writes, and proper SLVERR responses for out-of-range addresses.

## Features

- Full AXI4 compliance — five-channel handshake with back-pressure on every channel
- Burst types: FIXED, INCR, WRAP
- Narrow transfers: configurable data width (32 or 64 bit)
- Byte-enable writes: per-byte `WSTRB` masking
- Error response: `SLVERR` on out-of-range address access
- Internal memory: BRAM-style array, depth and width configurable via parameters
- Outstanding transactions up to `OUTSTANDING_DEPTH`

## Repository Layout

```
.
├── rtl/
│   └── axi4_slave.v       # Synthesisable AXI4 slave
├── tb/
│   └── axi4_slave_tb.v    # Self-checking testbench
├── sim/                   # Simulation artefacts (git-ignored)
├── Makefile               # Icarus Verilog simulation flow
├── LICENSE
└── README.md
```

## Parameters

| Parameter | Default | Description |
|-----------|---------|-------------|
| `AXI_ADDR_WIDTH` | 32 | Address bus width in bits |
| `AXI_DATA_WIDTH` | 32 | Data bus width; must be 32 or 64 |
| `AXI_ID_WIDTH` | 4 | Width of AXI ID fields |
| `AXI_USER_WIDTH` | 1 | Width of USER sideband signals |
| `MEM_DEPTH` | 1024 | Number of `AXI_DATA_WIDTH`-wide words in memory |
| `OUTSTANDING_DEPTH` | 4 | Maximum in-flight write/read transactions (power of 2) |

## Ports

### Global

| Port | Direction | Description |
|------|-----------|-------------|
| `ACLK` | input | Clock |
| `ARESETn` | input | Active-low reset |

All standard AXI4 slave port names are used. Inputs are driven by the master; outputs are driven by the slave.

- **Write address channel (AW):** `AWID`, `AWADDR`, `AWLEN`, `AWSIZE`, `AWBURST`, `AWLOCK`, `AWCACHE`, `AWPROT`, `AWQOS`, `AWREGION`, `AWUSER`, `AWVALID` (in); `AWREADY` (out)
- **Write data channel (W):** `WDATA`, `WSTRB`, `WLAST`, `WUSER`, `WVALID` (in); `WREADY` (out)
- **Write response channel (B):** `BREADY` (in); `BID`, `BRESP`, `BUSER`, `BVALID` (out)
- **Read address channel (AR):** `ARID`, `ARADDR`, `ARLEN`, `ARSIZE`, `ARBURST`, `ARLOCK`, `ARCACHE`, `ARPROT`, `ARQOS`, `ARREGION`, `ARUSER`, `ARVALID` (in); `ARREADY` (out)
- **Read data channel (R):** `RREADY` (in); `RID`, `RDATA`, `RRESP`, `RLAST`, `RUSER`, `RVALID` (out)

## Operation

- **Burst handling:** the slave decodes `AxBURST` and steps the beat address for FIXED, INCR, and WRAP bursts, honouring `AxLEN`/`AxSIZE` (including narrow transfers).
- **Byte-enable writes:** each `WSTRB` bit gates one byte lane of `WDATA`; unasserted lanes leave memory unchanged.
- **Error response:** accesses beyond `MEM_DEPTH` return `BRESP`/`RRESP = SLVERR` (`2'b10`); in-range accesses return `OKAY`.
- **Back-pressure:** the slave fully supports VALID/READY back-pressure on all five channels, including stalls on `BREADY` and `RREADY`.

The write datapath uses a four-state FSM (`WR_IDLE → WR_ADDR → WR_DATA → WR_RESP`); the read datapath mirrors it for the AR/R channels.

## Address Map

The internal memory is word-addressed with `MEM_DEPTH` words of `AXI_DATA_WIDTH` bits:

| Word Index | Byte Address (32-bit data) | Description |
|------------|----------------------------|-------------|
| 0 | `0x0000` | First memory word |
| 1 | `0x0004` | Second memory word |
| … | … | … |
| `MEM_DEPTH-1` | `(MEM_DEPTH-1)*4` | Last memory word |

Accesses to addresses at or beyond `MEM_DEPTH` words return `SLVERR`.

## Instantiation

```verilog
axi4_slave #(
    .AXI_ADDR_WIDTH   (32),
    .AXI_DATA_WIDTH   (32),
    .AXI_ID_WIDTH     (4),
    .AXI_USER_WIDTH   (1),
    .MEM_DEPTH        (1024),
    .OUTSTANDING_DEPTH(4)
) u_axi4_slave (
    .ACLK    (clk),
    .ARESETn (rst_n),

    // Write address channel
    .AWID    (AWID),   .AWADDR  (AWADDR),  .AWLEN   (AWLEN),
    .AWSIZE  (AWSIZE), .AWBURST (AWBURST), .AWLOCK  (AWLOCK),
    .AWCACHE (AWCACHE),.AWPROT  (AWPROT),  .AWQOS   (AWQOS),
    .AWREGION(AWREGION),.AWUSER (AWUSER),  .AWVALID (AWVALID),
    .AWREADY (AWREADY),

    // Write data channel
    .WDATA   (WDATA),  .WSTRB   (WSTRB),   .WLAST   (WLAST),
    .WUSER   (WUSER),  .WVALID  (WVALID),  .WREADY  (WREADY),

    // Write response channel
    .BID     (BID),    .BRESP   (BRESP),   .BUSER   (BUSER),
    .BVALID  (BVALID), .BREADY  (BREADY),

    // Read address channel
    .ARID    (ARID),   .ARADDR  (ARADDR),  .ARLEN   (ARLEN),
    .ARSIZE  (ARSIZE), .ARBURST (ARBURST), .ARLOCK  (ARLOCK),
    .ARCACHE (ARCACHE),.ARPROT  (ARPROT),  .ARQOS   (ARQOS),
    .ARREGION(ARREGION),.ARUSER (ARUSER),  .ARVALID (ARVALID),
    .ARREADY (ARREADY),

    // Read data channel
    .RID     (RID),    .RDATA   (RDATA),   .RRESP   (RRESP),
    .RLAST   (RLAST),  .RUSER   (RUSER),   .RVALID  (RVALID),
    .RREADY  (RREADY)
);
```

## Simulation

Requires [Icarus Verilog](https://steveicarus.github.io/iverilog/) (`iverilog` / `vvp`). Optional [GTKWave](https://gtkwave.sourceforge.net/) for waveforms.

```bash
make run      # compile RTL + testbench and run the simulation
make waves    # run, then open the waveform in GTKWave
make clean    # remove the sim/ build directory
```

Build artefacts (the compiled binary, `*.vcd`, and `sim.log`) are written to the git-ignored `sim/` directory.

### Test Cases

| # | Description |
|---|-------------|
| 1 | Single write then read-back |
| 2 | Byte-enable (`WSTRB`) masking |
| 3 | 8-beat INCR burst write + read |
| 4 | 8-beat WRAP burst write + read |
| 5 | Out-of-range address → `SLVERR` |
| 6 | Back-pressure on `BREADY` |
| 7 | Back-pressure on `RREADY` |
| 8 | Multiple IDs in sequence |

Expected output:

```
=== RESULTS ===
PASS: 30   FAIL: 0
*** ALL TESTS PASSED ***
```

## Synthesis Notes

- Targets any synchronous FPGA or ASIC flow; memory infers as BRAM on most tools.
- No latches; all state is held in `always @(posedge ACLK or negedge ARESETn)`.
- `AXI_DATA_WIDTH` must be 32 or 64; `OUTSTANDING_DEPTH` must be a power of 2.

## License

Released under the MIT License — see [LICENSE](LICENSE).
