`timescale 1ns / 1ps

module ring_oscillator #(
  parameter integer NUM_INV = 5  // must be odd
)(
  input  wire clk,       // system clock (for shift register)
  input  wire rstn,      // async reset, active-low
  input  wire en_i,      // enable-chain input
  output wire en_o,      // enable-chain output
  output wire rnd_o      // synchronized random output
);

  // Enable shift register (controls each stage latch)
  reg [NUM_INV-1:0] sreg;

  always @(posedge clk or negedge rstn) begin
    if (!rstn)
      sreg <= {NUM_INV{1'b0}};
    else
      sreg <= {sreg[NUM_INV-2:0], en_i};
  end

  assign en_o = sreg[NUM_INV-1];

  // Ring oscillator nodes
  reg  [NUM_INV-1:0] latch;     // latch outputs
  wire [NUM_INV-1:0] inv_in;
  wire [NUM_INV-1:0] inv_out;

  genvar i;
  generate
    for (i = 0; i < NUM_INV; i = i + 1) begin : ring

      // latch with reset and individual enable
      always @* begin
        if (!en_i) begin
          latch[i] = 1'b0;           // reset
        end else if (sreg[i]) begin
          latch[i] = inv_out[i];     // transparent (follows inverter)
        end else begin
          latch[i] = latch[i];       // hold
        end
      end

      // inverter
      assign inv_out[i] = ~inv_in[i];

    end
  endgenerate

  // Connect chain
  assign inv_in[0]           = latch[NUM_INV-1];   // feedback
  assign inv_in[NUM_INV-1:1] = latch[NUM_INV-2:0];

  // Synchronizer (move oscillator noise into system clock domain)
  reg [1:0] sync;
  always @(posedge clk or negedge rstn) begin
    if (!rstn)
      sync <= 2'b00;
    else
      sync <= {sync[0], latch[NUM_INV-1]};
  end

  assign rnd_o = sync[1];

endmodule
