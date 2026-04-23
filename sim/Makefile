TOP      = tb_axi4_slave
RTL      = ../rtl/axi4_slave.v
TB       = ../tb/tb_axi4_slave.v
VCD      = tb_axi4_slave.vcd
IVLOG    = iverilog
VVP      = vvp

.PHONY: all sim clean

all: sim

sim: $(TOP).vvp
	$(VVP) $< | tee sim.log

$(TOP).vvp: $(RTL) $(TB)
	$(IVLOG) -g2012 -Wall -o $@ $(TB) $(RTL)

clean:
	rm -f $(TOP).vvp $(VCD) sim.log
