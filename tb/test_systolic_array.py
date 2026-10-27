import numpy as np
import cocotb
from cocotb.clock import Clock
from cocotb.triggers import RisingEdge, ClockCycles


def get_n():
    raw = cocotb.plusargs.get("N", "4")
    return int(raw)


async def reset_dut(dut, n):
    dut.rst_n.value    = 0
    dut.valid_in.value = 0
    dut.ready_in.value = 1
    dut.acc_clear.value = 0
    for i in range(n):
        dut.a_row[i].value = 0
        dut.b_col[i].value = 0
    await ClockCycles(dut.clk, 5)
    dut.rst_n.value = 1
    await RisingEdge(dut.clk)


async def drive_and_collect(dut, a_mat, b_mat, n, data_w=8, accum_w=32):
    timeout_cycles = 20 * n

    dut.acc_clear.value = 1
    await RisingEdge(dut.clk)
    dut.acc_clear.value = 0

    for k in range(n):
        for r in range(n):
            dut.a_row[r].value = int(a_mat[r][k]) & 0xFF
        for c in range(n):
            dut.b_col[c].value = int(b_mat[k][c]) & 0xFF
        dut.valid_in.value = 1
        await RisingEdge(dut.clk)

    dut.valid_in.value = 0

    for i in range(timeout_cycles):
        await RisingEdge(dut.clk)
        if dut.valid_out.value == 1:
            break
    else:
        raise TimeoutError(f"valid_out never asserted after {timeout_cycles} cycles")

    result = np.zeros((n, n), dtype=np.int64)
    for r in range(n):
        for c in range(n):
            raw = int(dut.result[r][c].value)
            if raw >= (1 << (accum_w - 1)):
                raw -= 1 << accum_w
            result[r][c] = raw

    return result


@cocotb.test()
async def test_zeros(dut):
    n = get_n()
    cocotb.start_soon(Clock(dut.clk, 10, units="ns").start())
    await reset_dut(dut, n)

    a = np.zeros((n, n), dtype=np.int8)
    b = np.zeros((n, n), dtype=np.int8)
    hw  = await drive_and_collect(dut, a, b, n)
    ref = np.matmul(a.astype(np.int64), b.astype(np.int64))
    assert np.array_equal(hw, ref), f"zero test failed\nHW:\n{hw}\nRef:\n{ref}"


@cocotb.test()
async def test_identity(dut):
    n = get_n()
    cocotb.start_soon(Clock(dut.clk, 10, units="ns").start())
    await reset_dut(dut, n)

    rng = np.random.default_rng(7)
    a   = np.eye(n, dtype=np.int8)
    b   = rng.integers(-64, 64, (n, n), dtype=np.int8)
    hw  = await drive_and_collect(dut, a, b, n)
    ref = np.matmul(a.astype(np.int64), b.astype(np.int64))
    assert np.array_equal(hw, ref), f"identity test failed\nHW:\n{hw}\nRef:\n{ref}"


@cocotb.test()
async def test_random_small(dut):
    n = get_n()
    cocotb.start_soon(Clock(dut.clk, 10, units="ns").start())
    await reset_dut(dut, n)

    rng = np.random.default_rng(42)
    for i in range(8):
        a   = rng.integers(-128, 127, (n, n), dtype=np.int8)
        b   = rng.integers(-128, 127, (n, n), dtype=np.int8)
        hw  = await drive_and_collect(dut, a, b, n)
        ref = np.matmul(a.astype(np.int64), b.astype(np.int64))
        assert np.array_equal(hw, ref), \
            f"random test {i} failed\nHW:\n{hw}\nRef:\n{ref}"


@cocotb.test()
async def test_max_values(dut):
    n = get_n()
    cocotb.start_soon(Clock(dut.clk, 10, units="ns").start())
    await reset_dut(dut, n)

    a   = np.full((n, n), 127, dtype=np.int8)
    b   = np.full((n, n), 127, dtype=np.int8)
    hw  = await drive_and_collect(dut, a, b, n)
    ref = np.matmul(a.astype(np.int64), b.astype(np.int64))
    assert np.array_equal(hw, ref), f"max-value test failed\nHW:\n{hw}\nRef:\n{ref}"


@cocotb.test()
async def test_consecutive_matrices(dut):
    n = get_n()
    cocotb.start_soon(Clock(dut.clk, 10, units="ns").start())
    await reset_dut(dut, n)

    rng = np.random.default_rng(99)
    for i in range(4):
        a   = rng.integers(-128, 127, (n, n), dtype=np.int8)
        b   = rng.integers(-128, 127, (n, n), dtype=np.int8)
        hw  = await drive_and_collect(dut, a, b, n)
        ref = np.matmul(a.astype(np.int64), b.astype(np.int64))
        assert np.array_equal(hw, ref), \
            f"consecutive test {i} failed\nHW:\n{hw}\nRef:\n{ref}"
