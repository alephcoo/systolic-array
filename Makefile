N       ?= 4
DATA_W  ?= 8
ACCUM_W ?= 32

SIM           ?= verilator
TOPLEVEL_LANG ?= verilog

VERILOG_SOURCES  = $(abspath rtl/pe.sv)
VERILOG_SOURCES += $(abspath rtl/systolic_array.sv)

TOPLEVEL = systolic_array
MODULE   = test_systolic_array

COCOTB_HDL_TIMEUNIT      = 1ns
COCOTB_HDL_TIMEPRECISION = 1ps

COMPILE_ARGS += -GN=$(N) -GDATA_W=$(DATA_W) -GACCUM_W=$(ACCUM_W)
COMPILE_ARGS += -Wno-WIDTHEXPAND
COMPILE_ARGS += --sv

EXTRA_ARGS += --trace-fst

SIM_CMD_PREFIX = PYTHONPATH=$(abspath tb)

PLUSARGS += +N=$(N)

SIM_BUILD = sim/build_N$(N)

PYTHONPATH := $(abspath tb):$(PYTHONPATH)

include $(shell cocotb-config --makefiles)/Makefile.sim

.PHONY: sim2 sim4 lint waves throughput clean_all

sim2:
	$(MAKE) N=2

sim4:
	$(MAKE) N=4

lint:
	verilator --lint-only --sv --top-module systolic_array \
	    -GN=$(N) -GDATA_W=$(DATA_W) -GACCUM_W=$(ACCUM_W) \
	    -Wno-WIDTHEXPAND \
	    rtl/pe.sv rtl/systolic_array.sv
	@echo "lint passed"

waves:
	gtkwave $(SIM_BUILD)/dump.fst &

throughput:
	@echo "N=$(N)  MACs=$$(( $(N)*$(N)*$(N) ))  latency=$$(( 3*$(N)-2 )) cycles"

clean_all:
	rm -rf sim __pycache__ .pytest_cache tb/__pycache__
