`default_nettype none

// Transmitator UART: 1 bit de start, 8 biti de date (LSB primul), 1 bit de stop
module uart_tx #(
    parameter CLKS_PER_BIT = 434   // 50 MHz / 115200 baud
) (
    input  wire       clk,
    input  wire       rst_n,
    input  wire       start,   // 1 pentru un ciclu: incepe transmisia
    input  wire [7:0] data,    // octetul de trimis
    output reg        tx,      // linia seriala (1 = repaus)
    output wire       busy     // 1 cat timp se transmite
);

  // Starile masinii de stari
  localparam IDLE  = 2'd0;
  localparam START = 2'd1;
  localparam DATA  = 2'd2;
  localparam STOP  = 2'd3;

  reg [1:0]  state;
  reg [15:0] clk_cnt;   // numara ciclii din bitul curent
  reg [2:0]  bit_idx;   // ce bit de date trimitem (0..7)
  reg [7:0]  shift;     // copia octetului, deplasata bit cu bit

  assign busy = (state != IDLE);

  always @(posedge clk) begin
    if (!rst_n) begin
      state   <= IDLE;
      tx      <= 1'b1;
      clk_cnt <= 0;
      bit_idx <= 0;
      shift   <= 0;
    end else begin
      case (state)
        IDLE: begin
          tx      <= 1'b1;
          clk_cnt <= 0;
          bit_idx <= 0;
          if (start) begin
            shift <= data;      // memoram octetul
            state <= START;
          end
        end

        START: begin
          tx <= 1'b0;           // bitul de start
          if (clk_cnt == CLKS_PER_BIT - 1) begin
            clk_cnt <= 0;
            state   <= DATA;
          end else
            clk_cnt <= clk_cnt + 1;
        end

        DATA: begin
          tx <= shift[0];       // bitul curent de date
          if (clk_cnt == CLKS_PER_BIT - 1) begin
            clk_cnt <= 0;
            shift   <= shift >> 1;   // urmatorul bit ajunge pe pozitia 0
            if (bit_idx == 7)
              state <= STOP;
            else
              bit_idx <= bit_idx + 1;
          end else
            clk_cnt <= clk_cnt + 1;
        end

        STOP: begin
          tx <= 1'b1;           // bitul de stop
          if (clk_cnt == CLKS_PER_BIT - 1) begin
            clk_cnt <= 0;
            state   <= IDLE;
          end else
            clk_cnt <= clk_cnt + 1;
        end

        default: state <= IDLE;
      endcase
    end
  end

endmodule