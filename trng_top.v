// ============================================================================
// trng_top  -  3× ring_oscillator  → XOR → sync → de_biasing → sampling_unit_crc
// Output: data_o[7:0] with valid_o pulse (after NUM_RAW_BITS mixes)
// ============================================================================

`timescale 1ns/1ps

module trng_top #(
  // Ring sizes (must be odd)
  parameter integer NUM_INV0      = 3,
  parameter integer NUM_INV1      = 5,
  parameter integer NUM_INV2      = 7,

  // Output sample width (state/byte width)
  parameter integer SAMPLE_WIDTH  = 8,

  // Number of debiased bits mixed per output byte (power of 2; neoTRNG uses 64)
  parameter integer NUM_RAW_BITS  = 64,

  // CRC-8 taps used for mixing (x^8 + x^2 + x^1 + 1)
  parameter [7:0]   POLY          = 8'b0000_0111
)(
  input  wire                    clk,       // system clock
  input  wire                    rstn,      // async reset, active-low
  input  wire                    enable_i,  // global enable (feeds ring enable chain head)
  output wire                    valid_o,   // 1-cycle pulse when data_o is valid
  output wire [SAMPLE_WIDTH-1:0] data_o     // random byte
);

  // --------------------------------------------------------------------------
  // (optional) compile-time ceil(log2(x)) helper
  // --------------------------------------------------------------------------
  function integer clog2;
    input integer value;
    integer v;
  begin
    if (value <= 1) begin
      clog2 = 1;
    end else begin
      v = value - 1;
      clog2 = 0;
      while (v > 0) begin
        v = v >> 1;
        clog2 = clog2 + 1;
      end
    end
  end
  endfunction

  // --------------------------------------------------------------------------
  // 3 ring oscillators (daisy-chain their enable)
  //   assumed ports: (clk, rstn, en_i, en_o, rnd_o)
  // --------------------------------------------------------------------------
  wire ro0_bit, ro1_bit, ro2_bit;
  wire en0_out, en1_out, en2_out;

  ring_oscillator #(.NUM_INV(NUM_INV0)) u_ro0 (
    .clk (clk),
    .rstn(rstn),
    .en_i(enable_i),   // chain head
    .en_o(en0_out),
    .rnd_o(ro0_bit)
  );

  ring_oscillator #(.NUM_INV(NUM_INV1)) u_ro1 (
    .clk (clk),
    .rstn(rstn),
    .en_i(en0_out),    // chained from RO0
    .en_o(en1_out),
    .rnd_o(ro1_bit)
  );

  ring_oscillator #(.NUM_INV(NUM_INV2)) u_ro2 (
    .clk (clk),
    .rstn(rstn),
    .en_i(en1_out),    // chained from RO1
    .en_o(en2_out),    // exposed if you add more cells
    .rnd_o(ro2_bit)
  );

  // XOR-combine the three rings
  wire raw_xor = ro0_bit ^ ro1_bit ^ ro2_bit;

  // --------------------------------------------------------------------------
  // 2-FF synchronizer (ALWAYS keep this between async/raw and clocked logic)
  // --------------------------------------------------------------------------
  reg [1:0] sync;
  always @(posedge clk or negedge rstn) begin
    if (!rstn)
      sync <= 2'b00;
    else
      sync <= {sync[0], raw_xor};
  end
  wire sync_bit = sync[1];

  // --------------------------------------------------------------------------
  // Debiasing (Von Neumann extractor)
  //   Ports: (clk, rstn, raw_in, debias_out, valid_out)
  // --------------------------------------------------------------------------
  wire deb_bit;
  wire deb_valid;

  de_biasing u_debias (
    .clk        (clk),
    .rstn       (rstn),
    .raw_in     (sync_bit),
    .debias_out (deb_bit),
    .valid_out  (deb_valid)
  );

  // --------------------------------------------------------------------------
  // Sampling + CRC mixing (8-bit state, mix NUM_RAW_BITS per output)
  //   Ports: (clk, rstn, debias_bit, debias_valid, rnd_out, valid_out)
  //   Params: STATE_WIDTH=SAMPLE_WIDTH, NUM_RAW_BITS, POLY
  // --------------------------------------------------------------------------
  sampling_unit_crc #(
    .STATE_WIDTH (SAMPLE_WIDTH),
    .NUM_RAW_BITS(NUM_RAW_BITS),
    .POLY        (POLY)
  ) u_sampling (
    .clk          (clk),
    .rstn         (rstn),
    .debias_bit   (deb_bit),
    .debias_valid (deb_valid),
    .rnd_out      (data_o),
    .valid_out    (valid_o)
  );

endmodule
