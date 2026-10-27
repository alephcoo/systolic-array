# Systolic Array Matrix Multiplier

Parameterized 8-bit systolic array for quantized neural network inference. Supports NxN configurations (2x2, 4x4, 8x8) synthesized for SkyWater sky130A.

## Architecture

```
A matrix fed row-wise (left edge, one row per cycle, skewed by column index)
B matrix fed column-wise (top edge, one column per cycle, skewed by row index)

        b[0][0]  b[1][0]  b[2][0]  b[3][0]
           |        |        |        |
a[0] --> [PE]-->[PE]-->[PE]-->[PE]
           |        |        |        |
a[1] --> [PE]-->[PE]-->[PE]-->[PE]
           |        |        |        |
a[2] --> [PE]-->[PE]-->[PE]-->[PE]
           |        |        |        |
a[3] --> [PE]-->[PE]-->[PE]-->[PE]
```

Each PE:
- Receives `a_in` from the left, passes `a_out` to the right
- Receives `b_in` from above, passes `b_out` downward
- Accumulates `a_in * b_in` each cycle into a 32-bit register
- Exposes `valid`/`ready` handshake for backpressure

### Valid/Ready Handshake

```
valid_in  _____|---|---|---|------|_____
ready_out _____|-----------|______|_____
          (stall when downstream not ready)
valid_out ___________________________|--|
```

Data is accepted only when `valid_in & ready_out`. The array asserts `valid_out` once all PE accumulations for one matrix multiplication are complete.

## File Structure

```
.
|-- rtl/
|   |-- pe.sv               Processing element
|   `-- systolic_array.sv   Top-level NxN array
|-- tb/
|   `-- test_systolic_array.py  cocotb + pytest testbench
|-- openlane/
|   `-- config.json         SkyWater sky130A synthesis config
|-- Makefile
|-- Dockerfile
|-- setup.sh
`-- README.md
```

## Parameters

| Parameter | Default | Description |
|-----------|---------|-------------|
| N | 4 | Array dimension (NxN PEs) |
| DATA_W | 8 | Input data width (bits) |
| ACCUM_W | 32 | Accumulator width (bits) |

## Latency and Throughput

The systolic array uses a diagonal wavefront schedule. For an NxN multiplication:

| Array | Feed cycles | Drain cycles | Total cycles | MACs |
|-------|-------------|--------------|--------------|------|
| 2x2   | 2           | 2            | ~6           | 8    |
| 4x4   | 4           | 4            | ~10          | 64   |
| 8x8   | 8           | 8            | ~18          | 512  |

At 100 MHz (10 ns clock period):

| Array | Throughput (GMAC/s) | Area est. (sky130A) |
|-------|--------------------|--------------------|
| 2x2   | 0.13               | ~0.01 mm2          |
| 4x4   | 0.64               | ~0.04 mm2          |
| 8x8   | 2.84               | ~0.16 mm2          |

Area estimates are from OpenLane synthesis targeting `sky130_fd_sc_hd` at 45% core utilization.

## Quick Start (Linux / WSL2 / macOS)

### Option 1: Docker

```bash
docker build -t systolic-array .
docker run -it systolic-array
make sim2
make sim4
```

### Option 2: Native install

```bash
bash setup.sh
make sim2
make sim4
```

### Run specific configuration

```bash
make sim N=4 DATA_W=8 ACCUM_W=32
```

### Open waveforms

```bash
make waves N=4
```

## Tests

The `test_systolic_array.py` testbench runs five scenarios via cocotb/Verilator:

| Test | Description |
|------|-------------|
| test_zeros | All-zero inputs produce zero outputs |
| test_identity | Identity matrix times random produces same matrix |
| test_random_small | 8 random int8 matrix pairs, seeded for reproducibility |
| test_max_values | 127 filled matrices check no accumulator overflow |
| test_consecutive_matrices | 4 back-to-back multiplications with acc_clear between |

Each test asserts cycle-for-cycle equality against `numpy.matmul()`.

## OpenLane Synthesis

```bash
cd openlane
flow.tcl -design .
```

The `config.json` targets:
- PDK: sky130A
- Standard cell library: sky130_fd_sc_hd
- Clock: 10 ns (100 MHz)
- Synthesis strategy: AREA 0
- Core utilization: 45%

Output: `openlane/runs/<timestamp>/results/final/gds/systolic_array.gds`

## Signal Reference

### systolic_array ports

| Port | Direction | Width | Description |
|------|-----------|-------|-------------|
| clk | input | 1 | Clock |
| rst_n | input | 1 | Active-low reset |
| a_row | input | N x DATA_W | Row inputs (A matrix column k) |
| b_col | input | N x DATA_W | Column inputs (B matrix row k) |
| valid_in | input | 1 | Input data valid |
| ready_out | output | 1 | Array ready to accept data |
| result | output | N x N x ACCUM_W | Accumulated output matrix |
| valid_out | output | 1 | Result valid |
| ready_in | input | 1 | Downstream ready |
| acc_clear | input | 1 | Synchronous accumulator clear |

### pe ports

| Port | Direction | Width | Description |
|------|-----------|-------|-------------|
| a_in / a_out | input/output | DATA_W | A data pass-through |
| b_in / b_out | input/output | DATA_W | B data pass-through |
| valid_in | input | 1 | Upstream valid |
| ready_out | output | 1 | PE ready |
| valid_out | output | 1 | Downstream valid |
| ready_in | input | 1 | Downstream ready |
| acc_clear | input | 1 | Clear accumulator |
| accum | output | ACCUM_W | Running sum |
