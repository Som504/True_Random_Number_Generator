`timescale 1ns / 1ps
// ==========================================================
// Debiasing unit (Von Neumann extractor)
// - Takes a raw random bitstream (raw_in)
// - Processes pairs of bits
// - Outputs debiased bits (valid when valid_out=1)
// ==========================================================

module de_biasing (
    input  wire clk,          // system clock
    input  wire rstn,         // async reset, active-low
    input  wire raw_in,       // raw random bit (from XOR of ring oscillators)
    output reg  debias_out,   // debiased random bit
    output reg  valid_out     // high when debias_out is valid
);

  // Shift register to store 2-bit group
  reg [1:0] pair;

  always @(posedge clk or negedge rstn) begin
    if (!rstn) begin
      pair      <= 2'b00;
      debias_out <= 1'b0;
      valid_out  <= 1'b0;
    end else begin
      // Shift in new raw bit
      pair <= {pair[0], raw_in};

      // Only decide when we have a full pair
      if (pair[1] ^ pair[0]) begin
        // pair = 01 -> output 0
        // pair = 10 -> output 1
        debias_out <= pair[0];
        valid_out  <= 1'b1;
      end else begin
        // pair = 00 or 11 -> discard
        valid_out  <= 1'b0;
      end
    end
  end

endmodule

