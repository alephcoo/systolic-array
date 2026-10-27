import random
import numpy as np
import cocotb
from cocotb.clock import Clock
from cocotb.triggers import RisingEdge, FallingEdge, ClockCycles
import pytest


N = int(cocotb.plusargs.get("N", "4"))
DATA_W = 8
ACCUM_W = 32
TIMEOUT_CYCLES = 500


async def reset_dut(dut):
    dut.rst_n.value = 0
    dut.valid_in.value = 0
    dut.ready_in.value = 1
    dut.acc_clear.value = 0
    for i in range(N):
        dut.a_row[i].value = 0
        dut.b_col[i].value = 0
    await ClockCycles(dut.clk, 5)
    dut.rst_n.value = 1
    await RisingEdge(dut.clk)


async def drive_and_collect(dut, a_mat, b_mat):
    dut.acc_clear.value = 1
    await RisingEdge(dut.clk)
    dut.acc_clear.value = 0

    timeout = 0
    for k in range(N):
        for i in range(N):
            dut.a_row[i].value = int(a_mat[i][k]) & 0xFF
        for j in range(N):
            dut.b_col[j].value = int(b_mat[k][j]) & 0xFF

        dut.valid_in.value = 1

        while True:
            await RisingEdge(dut.clk)
            timeout += 1
            if timeout > TIMEOUT_CYCLES:
                raise TimeoutError("DUT never asserted ready_out")
            if dut.ready_out.value == 1:
                break

    dut.valid_in.value = 0

    timeout = 0
    while True:
        await RisingEdge(dut.clk)
        timeout += 1
        if timeout > TIMEOUT_CYCLES:
            raise TimeoutError("DUT never asserted valid_out")
        if dut.valid_out.value == 1:
            break

    result = np.zeros((N, N), dtype=np.int64)
    for r in range(N):
        for c in range(N):
            raw = int(dut.result[r][c].value)
            if raw >= (1 << (ACCUM_W - 1)):
                raw -= 1 << ACCUM_W
            result[r][c] = raw

    return result


@cocotb.test()
async def test_zeros(dut):
    cocotb.start_soon(Clock(dut.clk, 10, units="ns").start())
    await reset_dut(dut)

    a = np.zeros((N, N), dtype=np.int8)
    b = np.zeros((N, N), dtype=np.int8)
    hw = await drive_and_collect(dut, a, b)
    ref = np.matmul(a.astype(np.int64), b.astype(np.int64))
    assert np.array_equal(hw, ref), f"zero test failed: {hw} vs {ref}"


@cocotb.test()
async def test_identity(dut):
    cocotb.start_soon(Clock(dut.clk, 10, units="ns").start())
    await reset_dut(dut)

    a = np.eye(N, dtype=np.int8)
    b = (np.random.randint(-64, 64, (N, N))).astype(np.int8)
    hw = await drive_and_collect(dut, a, b)
    ref = np.matmul(a.astype(np.int64), b.astype(np.int64))
    assert np.array_equal(hw, ref), f"identity test failed: {hw} vs {ref}"


@cocotb.test()
async def test_random_small(dut):
    cocotb.start_soon(Clock(dut.clk, 10, units="ns").start())
    await reset_dut(dut)

    rng = np.random.default_rng(42)
    for _ in range(8):
        a = rng.integers(-128, 127, (N, N), dtype=np.int8)
        b = rng.integers(-128, 127, (N, N), dtype=np.int8)
        hw = await drive_and_collect(dut, a, b)
        ref = np.matmul(a.astype(np.int64), b.astype(np.int64))
        assert np.array_equal(hw, ref), f"random test mismatch:\nHW:\n{hw}\nRef:\n{ref}"


@cocotb.test()
async def test_max_values(dut):
    cocotb.start_soon(Clock(dut.clk, 10, units="ns").start())
    await reset_dut(dut)

    a = np.full((N, N), 127, dtype=np.int8)
    b = np.full((N, N), 127, dtype=np.int8)
    hw = await drive_and_collect(dut, a, b)
    ref = np.matmul(a.astype(np.int64), b.astype(np.int64))
    assert np.array_equal(hw, ref), f"max value test failed: {hw} vs {ref}"


@cocotb.test()
async def test_consecutive_matrices(dut):
    cocotb.start_soon(Clock(dut.clk, 10, units="ns").start())
    await reset_dut(dut)

    rng = np.random.default_rng(99)
    for i in range(4):
        a = rng.integers(-128, 127, (N, N), dtype=np.int8)
        b = rng.integers(-128, 127, (N, N), dtype=np.int8)
        hw = await drive_and_collect(dut, a, b)
        ref = np.matmul(a.astype(np.int64), b.astype(np.int64))
        assert np.array_equal(hw, ref), f"consecutive test {i} failed: {hw} vs {ref}"
