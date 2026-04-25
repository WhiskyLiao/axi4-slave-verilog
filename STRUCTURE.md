# Repository File Structure

```
axi4-slave-verilog/
├── README.md                  # Project overview, parameters, ports, and simulation guide
├── STRUCTURE.md               # This file — directory and file reference
├── .gitignore                 # Excludes simulation build artefacts from version control
├── rtl/
│   └── axi4_slave.v           # Synthesizable AXI4 slave RTL module
├── tb/
│   └── tb_axi4_slave.v        # Self-checking testbench (8 tests)
└── sim/
    └── Makefile               # Icarus Verilog compile-and-run flow
```

---

## Root

| File | Description |
|------|-------------|
| `README.md` | Top-level documentation: feature list, parameter table, full port list, simulation instructions, and test coverage summary. Start here. |
| `STRUCTURE.md` | Describes every directory and file in the repository. |
| `.gitignore` | Prevents simulation artefacts (`*.vvp`, `*.vcd`, `sim.log`) from being committed. |

---

## `rtl/`

Contains all synthesizable RTL source files.

| File | Description |
|------|-------------|
| `axi4_slave.v` | Parameterizable AXI4 Full slave with an internal BRAM-style memory. Implements all five AXI4 channels (AW, W, B, AR, R), a 4-state write FSM, a 3-state read FSM, and support for FIXED / INCR / WRAP bursts, byte-enable writes (`WSTRB`), and `SLVERR` responses for out-of-range addresses. |

Add new RTL source files (e.g. additional peripherals, wrappers) to this directory.

---

## `tb/`

Contains simulation-only testbench files. Nothing in this directory is intended for synthesis.

| File | Description |
|------|-------------|
| `tb_axi4_slave.v` | Top-level testbench for `axi4_slave`. Instantiates the DUT with reduced memory depth (256 words), drives all AXI channels via helper tasks (`axi_write`, `axi_read`, `do_aw`, `do_w_beat`, `do_b`, `do_ar`, `do_r_beat`), and runs 8 self-checking tests covering single transfers, burst types, byte enables, error responses, back-pressure, and multiple IDs. Writes a VCD waveform to `sim/tb_axi4_slave.vcd`. |

Add additional testbench files or include files for other modules to this directory.

---

## `sim/`

Contains simulation infrastructure and build scripts. Also the working directory for simulation runs.

| File / Artefact | Description |
|-----------------|-------------|
| `Makefile` | Drives Icarus Verilog (`iverilog -g2012 -Wall`) compilation and `vvp` execution. Targets: `all` / `sim` (compile + run, log to `sim.log`), `clean` (remove build artefacts). |
| `sim.log` *(generated)* | Console output from the last simulation run. Not committed. |
| `tb_axi4_slave.vcd` *(generated)* | VCD waveform dump. Open with GTKWave to inspect signal activity. Not committed. |
| `tb_axi4_slave.vvp` *(generated)* | Compiled simulation binary produced by `iverilog`. Not committed. |

Generated artefacts are excluded by `.gitignore` and will appear only after running `make` inside this directory.
