`default_nettype none

// Receptor UART: 1 bit de start, 8 biti de date (LSB primul), 1 bit de stop
module uart_rx #(
    parameter CLKS_PER_BIT = 434   // 50 MHz / 115200 baud
) (
    input  wire       clk,
    input  wire       rst_n,
    input  wire       rx,      // linia seriala de intrare (1 = repaus)
    output reg  [7:0] data,    // ultimul octet primit corect
    output reg        valid,   // 1 pentru un ciclu cand a sosit un octet corect
    output reg        error    // 1 pentru un ciclu daca bitul de stop nu a fost 1
);

  // ---------------------------------------------------------------
  // 1. Sincronizator cu doua flip-flop-uri
  //    Linia rx vine din exterior, fara legatura cu ceasul nostru.
  //    O trecem prin doua registre ca sa evitam metastabilitatea.
  // ---------------------------------------------------------------
  reg rx_meta;
  reg rx_sync;

  always @(posedge clk) begin
    if (!rst_n) begin
      rx_meta <= 1'b1;
      rx_sync <= 1'b1;
    end else begin
      rx_meta <= rx;
      rx_sync <= rx_meta;
    end
  end

  // ---------------------------------------------------------------
  // 2. Masina de stari
  // ---------------------------------------------------------------
  localparam IDLE  = 2'd0;
  localparam START = 2'd1;
  localparam DATA  = 2'd2;
  localparam STOP  = 2'd3;

  reg [1:0]  state;
  reg [15:0] clk_cnt;   // numara ciclii din bitul curent
  reg [2:0]  bit_idx;   // ce bit de date citim (0..7)
  reg [7:0]  shift;     // aici se aduna bitii primiti

  always @(posedge clk) begin
    if (!rst_n) begin
      state   <= IDLE;
      clk_cnt <= 0;
      bit_idx <= 0;
      shift   <= 0;
      data    <= 0;
      valid   <= 1'b0;
      error   <= 1'b0;
    end else begin
      // valid si error sunt impulsuri de un singur ciclu
      valid <= 1'b0;
      error <= 1'b0;

      case (state)
        // Asteptam ca linia sa coboare: posibil bit de start
        IDLE: begin
          clk_cnt <= 0;
          bit_idx <= 0;
          if (rx_sync == 1'b0)
            state <= START;
        end

        // Mergem la mijlocul bitului de start si verificam ca e tot 0
        START: begin
          if (clk_cnt == (CLKS_PER_BIT - 1) / 2) begin
            clk_cnt <= 0;
            if (rx_sync == 1'b0)
              state <= DATA;    // bit de start valid
            else
              state <= IDLE;    // a fost doar un zgomot scurt
          end else
            clk_cnt <= clk_cnt + 1;
        end

        // Citim cei 8 biti, fiecare la mijlocul lui
        DATA: begin
          if (clk_cnt == CLKS_PER_BIT - 1) begin
            clk_cnt <= 0;
            // LSB vine primul: bitul nou intra pe stanga si
            // dupa 8 pasi primul bit ajunge pe pozitia 0
            shift <= {rx_sync, shift[7:1]};
            if (bit_idx == 7)
              state <= STOP;
            else
              bit_idx <= bit_idx + 1;
          end else
            clk_cnt <= clk_cnt + 1;
        end

        // La mijlocul bitului de stop verificam ca linia e 1
        STOP: begin
          if (clk_cnt == CLKS_PER_BIT - 1) begin
            clk_cnt <= 0;
            state   <= IDLE;
            if (rx_sync == 1'b1) begin
              data  <= shift;   // octet primit corect
              valid <= 1'b1;
            end else
              error <= 1'b1;    // eroare de cadru (framing error)
          end else
            clk_cnt <= clk_cnt + 1;
        end

        default: state <= IDLE;
      endcase
    end
  end

endmodule