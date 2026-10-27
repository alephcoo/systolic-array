N        ?= 4
DATA_W   ?= 8
ACCUM_W  ?= 32
SIM_DIR  := sim
WAVES    := $(SIM_DIR)/waves.fst
TB_DIR   := tb
RTL_DIR  := rtl

VERILATOR := verilator
PYTHON    := python3
COCOTB_SHARE := $(shell cocotb-config --share 2>/dev/null)

SV_SOURCES := \
    $(RTL_DIR)/pe.sv \
    $(RTL_DIR)/systolic_array.sv

VFLAGS := \
    --cc \
    --exe \
    --build \
    --sv \
    --top-module systolic_array \
    --trace-fst \
    --Wno-WIDTHEXPAND \
    -GDATA_W=$(DATA_W) \
    -GACCUM_W=$(ACCUM_W) \
    -GN=$(N) \
    -I$(RTL_DIR)

.PHONY: all sim lint clean waves help

all: sim

$(SIM_DIR):
	mkdir -p $(SIM_DIR)

lint: $(SV_SOURCES)
	$(VERILATOR) --lint-only --sv --top-module systolic_array \
	    -GDATA_W=$(DATA_W) -GACCUM_W=$(ACCUM_W) -GN=$(N) \
	    $(SV_SOURCES)
	@echo "Lint passed"

sim: $(SIM_DIR)
	@echo "Running N=$(N) DATA_W=$(DATA_W) ACCUM_W=$(ACCUM_W)"
	SIM=verilator \
	COCOTB_RESOLVE_X=ZEROS \
	TOPLEVEL=systolic_array \
	MODULE=test_systolic_array \
	VERILOG_SOURCES="$(realpath $(SV_SOURCES))" \
	COMPILE_ARGS="-GN=$(N) -GDATA_W=$(DATA_W) -GACCUM_W=$(ACCUM_W)" \
	EXTRA_ARGS="+N=$(N) --trace-fst" \
	SIM_BUILD=$(SIM_DIR)/build_N$(N) \
	WAVES=1 \
	$(PYTHON) -m pytest $(TB_DIR)/test_systolic_array.py -v \
	    --tb=short 2>&1 | tee $(SIM_DIR)/sim_N$(N).log
	@echo "Waveform: $(SIM_DIR)/build_N$(N)/waves.fst"

sim2: N=2
sim2: sim

sim4: N=4
sim4: sim

waves:
	gtkwave $(SIM_DIR)/build_N$(N)/waves.fst &

throughput:
	@echo "Systolic array throughput report"
	@echo "Array size    : $(N)x$(N)"
	@echo "DATA_W        : $(DATA_W) bits"
	@echo "ACCUM_W       : $(ACCUM_W) bits"
	@echo "Ops per cycle : $(N) MACs  (one diagonal wavefront)"
	@echo "MACs per mul  : $$(( $(N) * $(N) * $(N) ))"
	@echo "Latency (cyc) : $$(( $(N) + $(N) - 1 )) feed + $(N) drain"
	@echo "Throughput    : 1 matrix/mul per $$(( $(N) + $(N) + $(N) - 1 )) cycles at peak"

clean:
	rm -rf $(SIM_DIR) __pycache__ .pytest_cache $(TB_DIR)/__pycache__

help:
	@echo "Targets:"
	@echo "  make sim       Run cocotb simulation for NxN (default N=4)"
	@echo "  make sim2      Run 2x2"
	@echo "  make sim4      Run 4x4"
	@echo "  make lint      Verilator lint only"
	@echo "  make waves     Open waveform in GTKWave"
	@echo "  make throughput Print throughput numbers"
	@echo "  make clean     Remove build artifacts"
	@echo ""
	@echo "Override: make sim N=8 DATA_W=8 ACCUM_W=32"
