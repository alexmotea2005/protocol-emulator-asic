<!---

This file is used to generate your project datasheet. Please fill in the information below and delete any unused
sections.

You can also include images in this folder and reference them in the markdown. Each image must be less than
512 kb in size, and the combined size of all images must be less than 1 MB.
-->

## How it works

This project is a programmable protocol emulator: a small processor with an instruction set designed for
driving and sampling I/O pins with cycle-exact timing. Instead of fixed UART, SPI or I2C blocks, each
protocol is implemented as firmware loaded into the chip, so new protocols can be supported after fabrication.

The current version is a placeholder design used to validate the build flow: the outputs `uo_out` are the
sum of `ui_in` and `uio_in`.

## How to test

Current placeholder: set values on `ui_in` and `uio_in` and check that `uo_out` shows their sum (modulo 256).

The final design will be tested by loading a firmware program and observing UART, SPI and I2C traffic on the output pins.

## External hardware

None for the current version. The final design is intended to connect to standard UART, SPI and I2C devices.
