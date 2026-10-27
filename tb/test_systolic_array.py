import numpy as np
import cocotb
from cocotb.clock import Clock
from cocotb.triggers import RisingEdge, ClockCycles


DATA_W  = 8
ACCUM_W = 32


def get_n():
    return int(cocotb.plusargs.get("N", "4"))


def pack_row(vals, width=DATA_W):
    out = 0
    for i, v in enumerate(vals):
        out |= (int(v) & ((1 << width) - 1)) << (i * width)
    return out


def unpack_result(raw, n, accum_w=ACCUM_W):
    mask = (1 << accum_w) - 1
    mat  = np.zeros((n, n), dtype=np.int64)
    for r in range(n):
        for c in range(n):
            val = (raw >> ((r * n + c) * accum_w)) & mask
            if val >= (1 << (accum_w - 1)):
                val -= 1 << accum_w
            mat[r][c] = val
    return mat


async def reset_dut(dut, n):
    dut.rst_n.value     = 0
    dut.valid_in.value  = 0
    dut.ready_in.value  = 1
    dut.acc_clear.value = 0
    dut.a_row.value     = 0
    dut.b_col.value     = 0
    await ClockCycles(dut.clk, 5)
    dut.rst_n.value = 1
    await RisingEdge(dut.clk)


async def drive_and_collect(dut, a_mat, b_mat, n):
    timeout = 20 * n

    dut.acc_clear.value = 1
    await RisingEdge(dut.clk)
    dut.acc_clear.value = 0

    for k in range(n):
        dut.a_row.value    = pack_row([a_mat[r][k] for r in range(n)])
        dut.b_col.value    = pack_row([b_mat[k][c] for c in range(n)])
        dut.valid_in.value = 1
        await RisingEdge(dut.clk)

    dut.valid_in.value = 0

    for _ in range(timeout):
        await RisingEdge(dut.clk)
        if dut.valid_out.value == 1:
            break
    else:
        raise TimeoutError(f"valid_out never asserted after {timeout} cycles")

    return unpack_result(int(dut.result.value), n)


@cocotb.test()
async def test_zeros(dut):
    n = get_n()
    cocotb.start_soon(Clock(dut.clk, 10, units="ns").start())
    await reset_dut(dut, n)

    a   = np.zeros((n, n), dtype=np.int8)
    b   = np.zeros((n, n), dtype=np.int8)
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
