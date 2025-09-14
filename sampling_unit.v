// ==========================================================
// sampling_unit_crc
// - 8-bit (or param) CRC/LFSR state
// - Mixes NUM_RAW_BITS debiased bits into that state
// - Emits the state as one byte when the mix count completes
//   (Default: STATE_WIDTH=8, NUM_RAW_BITS=64, POLY = x^8 + x^2 + x^1 + 1 -> 8'b0000_0111)
// ==========================================================

`timescale 1ns/1ps

module sampling_unit_crc #(
    parameter integer STATE_WIDTH = 8,           // CRC state width (typically 8)
    parameter integer NUM_RAW_BITS = 64,         // how many debiased bits per output byte (power of 2)
    parameter [STATE_WIDTH-1:0] POLY = 8'b0000_0111  // CRC taps; width must match STATE_WIDTH
)(
    input  wire                       clk,
    input  wire                       rstn,          // async reset, active-low
    input  wire                       debias_bit,    // debiased input bit
    input  wire                       debias_valid,  // 1 when debias_bit is valid
    output reg  [STATE_WIDTH-1:0]     rnd_out,       // output byte (STATE_WIDTH bits)
    output reg                        valid_out      // 1-cycle pulse when rnd_out is valid
);

  // -------- helper: ceil(log2(x)) --------
  function integer clog2;
    input integer value; integer v;
  begin
    if (value <= 1) clog2 = 1;
    else begin
      v = value - 1; clog2 = 0;
      while (v > 0) begin v = v >> 1; clog2 = clog2 + 1; end
    end
  end
  endfunction

  // CRC/LFSR state and mix counter
  reg  [STATE_WIDTH-1:0] state;
  reg  [clog2(NUM_RAW_BITS):0] mix_cnt;

  wire feedback = state[STATE_WIDTH-1] ^ debias_bit;

  // (Optional) sanity checks (simulation-only)
  // synthesis translate_off
  initial begin
    if ((1 << clog2(NUM_RAW_BITS)) != NUM_RAW_BITS)
      $error("NUM_RAW_BITS must be a power of two (got %0d)", NUM_RAW_BITS);
    if (STATE_WIDTH <= 0) $error("STATE_WIDTH must be > 0");
  end
  // synthesis translate_on

  always @(posedge clk or negedge rstn) begin
    if (!rstn) begin
      state     <= {STATE_WIDTH{1'b0}};
      mix_cnt   <= { (clog2(NUM_RAW_BITS)+1) {1'b0} };
      rnd_out   <= {STATE_WIDTH{1'b0}};
      valid_out <= 1'b0;
    end else begin
      valid_out <= 1'b0; // default

      if (debias_valid) begin
        // CRC-style update: shift left, and if feedback is 1, XOR with POLY
        if (feedback)
          state <= ({state[STATE_WIDTH-2:0], 1'b0}) ^ POLY;
        else
          state <= {state[STATE_WIDTH-2:0], 1'b0};

        // count how many debiased bits we have mixed into the state
        mix_cnt <= mix_cnt + {{(clog2(NUM_RAW_BITS)){1'b0}}, 1'b1};

        // when NUM_RAW_BITS bits have been mixed, emit the byte
        if (mix_cnt == (NUM_RAW_BITS-1)) begin
          rnd_out   <= state;   // final mixed state becomes the output byte
          valid_out <= 1'b1;    // pulse valid
          mix_cnt   <= { (clog2(NUM_RAW_BITS)+1) {1'b0} };  // restart count
        end
      end
    end
  end

endmodule
