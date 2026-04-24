# AXI4 Slave — Verilog

A parameterizable, fully compliant AMBA AXI4 Full slave with an internal BRAM-style memory. Supports all three burst types, byte-enable writes, and proper SLVERR responses for out-of-range addresses.

## Features

- **Burst types**: FIXED, INCR, WRAP
- **Narrow transfers**: configurable data width (32 or 64 bit)
- **Byte-enable writes**: per-byte `WSTRB` masking
- **Error response**: `SLVERR` on out-of-range address access
- **Back-pressure**: full handshake support on all five AXI channels
- **Internal memory**: BRAM-style array, depth and width configurable via parameters

## Parameters

| Parameter          | Default | Description                                      |
|--------------------|---------|--------------------------------------------------|
| `AXI_ADDR_WIDTH`   | 32      | Address bus width in bits                        |
| `AXI_DATA_WIDTH`   | 32      | Data bus width; must be 32 or 64                 |
| `AXI_ID_WIDTH`     | 4       | Width of AXI ID fields                           |
| `AXI_USER_WIDTH`   | 1       | Width of USER sideband signals                   |
| `MEM_DEPTH`        | 1024    | Number of `AXI_DATA_WIDTH`-wide words in memory  |
| `OUTSTANDING_DEPTH`| 4       | Maximum in-flight write/read transactions (power of 2) |

## Port List

### Global

| Signal    | Dir | Description          |
|-----------|-----|----------------------|
| `ACLK`    | in  | Clock                |
| `ARESETn` | in  | Active-low reset     |

### Write Address Channel (AW)

`AWID`, `AWADDR`, `AWLEN`, `AWSIZE`, `AWBURST`, `AWLOCK`, `AWCACHE`, `AWPROT`, `AWQOS`, `AWREGION`, `AWUSER`, `AWVALID` → slave; `AWREADY` ← slave.

### Write Data Channel (W)

`WDATA`, `WSTRB`, `WLAST`, `WUSER`, `WVALID` → slave; `WREADY` ← slave.

### Write Response Channel (B)

`BREADY` → slave; `BID`, `BRESP`, `BUSER`, `BVALID` ← slave.

### Read Address Channel (AR)

`ARID`, `ARADDR`, `ARLEN`, `ARSIZE`, `ARBURST`, `ARLOCK`, `ARCACHE`, `ARPROT`, `ARQOS`, `ARREGION`, `ARUSER`, `ARVALID` → slave; `ARREADY` ← slave.

### Read Data Channel (R)

`RREADY` → slave; `RID`, `RDATA`, `RRESP`, `RLAST`, `RUSER`, `RVALID` ← slave.

## Directory Structure

```
.
├── rtl/
│   └── axi4_slave.v       # Synthesizable RTL
├── tb/
│   └── tb_axi4_slave.v    # Self-checking testbench
└── sim/
    └── Makefile           # Icarus Verilog simulation flow
```

## Simulation

Requires [Icarus Verilog](http://iverilog.icarus.com/) (`iverilog` / `vvp`).

```bash
cd sim
make        # compile and run; output logged to sim.log
make clean  # remove build artifacts
```

A VCD waveform (`tb_axi4_slave.vcd`) is written to the `sim/` directory and can be viewed with GTKWave.

## Test Coverage

The testbench (`tb/tb_axi4_slave.v`) includes eight self-checking tests:

| Test | Description |
|------|-------------|
| 1 | Single write then read-back |
| 2 | Byte-enable (`WSTRB`) masking |
| 3 | 8-beat INCR burst write + read |
| 4 | 8-beat WRAP burst write + read |
| 5 | Out-of-range address → `SLVERR` |
| 6 | Back-pressure on `BREADY` |
| 7 | Back-pressure on `RREADY` |
| 8 | Multiple IDs in sequence |

Pass/fail counts are printed at the end of simulation:

```
=== RESULTS ===
PASS: N   FAIL: 0
*** ALL TESTS PASSED ***
```
