# SPDX-FileCopyrightText: © 2026 Alex Motea
# SPDX-License-Identifier: Apache-2.0

import cocotb
from cocotb.clock import Clock
from cocotb.triggers import ClockCycles, RisingEdge

CLKS_PER_BIT = 434  # trebuie sa fie la fel ca in project.v


# ---------------------------------------------------------------
# Functii ajutatoare pentru citirea pinilor de iesire
# ---------------------------------------------------------------
def tx(dut):
    return int(dut.uo_out.value) & 1


def busy(dut):
    return (int(dut.uo_out.value) >> 1) & 1


def rx_error(dut):
    return (int(dut.uo_out.value) >> 3) & 1


def set_uio(dut, start=0, rx=1, echo=0):
    """Seteaza pinii uio_in: bit0 = START, bit1 = RX, bit2 = ECHO."""
    dut.uio_in.value = (echo << 2) | (rx << 1) | start


async def reset(dut):
    """Porneste ceasul de 50 MHz si reseteaza cipul."""
    clock = Clock(dut.clk, 20, unit="ns")
    cocotb.start_soon(clock.start())

    dut.ena.value = 1
    dut.ui_in.value = 0
    set_uio(dut)
    dut.rst_n.value = 0
    await ClockCycles(dut.clk, 10)
    dut.rst_n.value = 1
    await ClockCycles(dut.clk, 5)


# ---------------------------------------------------------------
# Un receptor UART scris in Python: asculta pinul TX al cipului
# ---------------------------------------------------------------
async def uart_receive(dut):
    # Asteapta bitul de start (linia coboara in 0)
    while tx(dut) == 1:
        await RisingEdge(dut.clk)

    # Mergi la mijlocul bitului de start si verifica-l
    await ClockCycles(dut.clk, CLKS_PER_BIT // 2)
    assert tx(dut) == 0, "Bitul de start nu este 0"

    # Citeste 8 biti de date, cate unul la mijlocul fiecarui bit
    value = 0
    for i in range(8):
        await ClockCycles(dut.clk, CLKS_PER_BIT)
        value |= tx(dut) << i

    # Verifica bitul de stop
    await ClockCycles(dut.clk, CLKS_PER_BIT)
    assert tx(dut) == 1, "Bitul de stop nu este 1"
    return value


# ---------------------------------------------------------------
# Un transmitator UART scris in Python: trimite pe pinul RX al cipului
# ---------------------------------------------------------------
async def uart_send(dut, byte, echo=1, stop_bit=1):
    bits = [0] + [(byte >> i) & 1 for i in range(8)] + [stop_bit]
    for b in bits:
        set_uio(dut, rx=b, echo=echo)
        await ClockCycles(dut.clk, CLKS_PER_BIT)
    set_uio(dut, rx=1, echo=echo)   # linia revine in repaus


# ---------------------------------------------------------------
# Test 1: transmitatorul trimite octetii pusi pe ui_in
# ---------------------------------------------------------------
@cocotb.test()
async def test_uart_tx(dut):
    await reset(dut)
    assert tx(dut) == 1, "In repaus linia TX trebuie sa fie 1"

    for byte in [0x55, 0x00, 0xFF, 0xA3, ord("J")]:
        dut.ui_in.value = byte
        set_uio(dut, start=1)          # puls de START de un ciclu
        await ClockCycles(dut.clk, 1)
        set_uio(dut, start=0)

        received = await uart_receive(dut)
        dut._log.info(f"TX: trimis 0x{byte:02X}, primit 0x{received:02X}")
        assert received == byte, f"Asteptat 0x{byte:02X}, primit 0x{received:02X}"

        while busy(dut) == 1:
            await RisingEdge(dut.clk)


# ---------------------------------------------------------------
# Test 2: modul ECHO - ce intra pe RX trebuie sa iasa identic pe TX
# ---------------------------------------------------------------
@cocotb.test()
async def test_uart_echo(dut):
    await reset(dut)
    set_uio(dut, echo=1)
    await ClockCycles(dut.clk, 5)

    for byte in [0x55, 0x00, 0xFF, 0xA3, ord("J"), ord("S")]:
        # Pornim receptorul Python in paralel, ca sa prinda ecoul de la inceput
        rx_task = cocotb.start_soon(uart_receive(dut))
        await uart_send(dut, byte)
        received = await rx_task

        dut._log.info(f"ECHO: trimis 0x{byte:02X}, intors 0x{received:02X}")
        assert received == byte, f"Asteptat 0x{byte:02X}, intors 0x{received:02X}"

        while busy(dut) == 1:
            await RisingEdge(dut.clk)


# ---------------------------------------------------------------
# Test 3: un octet cu bitul de stop gresit trebuie sa dea RX_ERROR
# ---------------------------------------------------------------
@cocotb.test()
async def test_uart_rx_framing_error(dut):
    await reset(dut)
    set_uio(dut, echo=1)
    await ClockCycles(dut.clk, 5)

    cocotb.start_soon(uart_send(dut, 0x5A, stop_bit=0))

    saw_error = False
    for _ in range(11 * CLKS_PER_BIT):
        await RisingEdge(dut.clk)
        if rx_error(dut) == 1:
            saw_error = True

    dut._log.info(f"RX_ERROR observat: {saw_error}")
    assert saw_error, "Receptorul trebuia sa semnaleze eroare de cadru"