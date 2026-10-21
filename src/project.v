/*
 * Copyright (c) 2026 Alex Motea
 * SPDX-License-Identifier: Apache-2.0
 */

`default_nettype none

module tt_um_alexmotea2005_protocol_emulator (
    input  wire [7:0] ui_in,    // Dedicated inputs
    output wire [7:0] uo_out,   // Dedicated outputs
    input  wire [7:0] uio_in,   // IOs: Input path
    output wire [7:0] uio_out,  // IOs: Output path
    output wire [7:0] uio_oe,   // IOs: Enable path (active high: 0=input, 1=output)
    input  wire       ena,      // always 1 when the design is powered, so you can ignore it
    input  wire       clk,      // clock
    input  wire       rst_n     // reset_n - low to reset
);

  // Pini:
  //   ui_in[7:0]  = octetul de trimis (mod normal)
  //   uio_in[0]   = START  - puls de 1 ciclu: trimite octetul de pe ui_in
  //   uio_in[1]   = RX     - linia seriala de intrare
  //   uio_in[2]   = ECHO   - 1 = retrimite pe TX fiecare octet primit pe RX
  //   uo_out[0]   = TX
  //   uo_out[1]   = BUSY
  //   uo_out[2]   = RX_VALID (impuls de 1 ciclu)
  //   uo_out[3]   = RX_ERROR (impuls de 1 ciclu)

  wire start_in = uio_in[0];
  wire rx_in    = uio_in[1];
  wire echo     = uio_in[2];

  // ---------------- Receptor ----------------
  wire [7:0] rx_data;
  wire       rx_valid;
  wire       rx_error;

  uart_rx #(.CLKS_PER_BIT(434)) u_uart_rx (
      .clk   (clk),
      .rst_n (rst_n),
      .rx    (rx_in),
      .data  (rx_data),
      .valid (rx_valid),
      .error (rx_error)
  );

  // ---------------- Transmitator ----------------
  // In modul ECHO, transmitatorul porneste singur cu octetul primit.
  wire       tx_start = echo ? rx_valid : start_in;
  wire [7:0] tx_data  = echo ? rx_data  : ui_in;

  wire tx;
  wire busy;

  uart_tx #(.CLKS_PER_BIT(434)) u_uart_tx (
      .clk   (clk),
      .rst_n (rst_n),
      .start (tx_start),
      .data  (tx_data),
      .tx    (tx),
      .busy  (busy)
  );

  // ---------------- Iesiri ----------------
  assign uo_out  = {4'b0, rx_error, rx_valid, busy, tx};
  assign uio_out = 0;
  assign uio_oe  = 0;   // toti pinii bidirectionali sunt intrari

  // Intrari nefolosite
  wire _unused = &{ena, uio_in[7:3], 1'b0};

endmodule