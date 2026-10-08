`timescale 1ns/1ps

// HEPIA CoRES - GPIO waveform exercise. No automatic pass/fail checks.
module gpio_tb;
  localparam [31:0] BASE = 32'h50000100;
  localparam integer PERIOD = 10;

  reg clock = 1'b0;
  reg reset = 1'b1;
  reg beginTransactionIn = 1'b0;
  reg readNWriteIn = 1'b0;
  reg dataValidIn = 1'b0;
  reg [31:0] addressDataIn = 32'b0;
  wire dataValidOut, endTransactionOut;
  wire [31:0] addressDataOut;
  // No external assign or pullup: only DUT pin buffers drive this net.
  wire [31:0] gpioPins;

  integer phase = 0; // Waveform marker, not a DUT port.
  reg [31:0] readDir = 32'hxxxxxxxx;
  reg [31:0] readPin = 32'hxxxxxxxx;

  always #(PERIOD / 2) clock = ~clock;

  // Match the 32-bit gpioSlave interface in the exercise handout.
  gpioSlave #(.INVERT_PINS(1)) dut (
    .clock(clock), .reset(reset),
    .beginTransactionIn(beginTransactionIn),
    .readNWriteIn(readNWriteIn), .dataValidIn(dataValidIn),
    .addressDataIn(addressDataIn),
    .dataValidOut(dataValidOut), .endTransactionOut(endTransactionOut),
    .addressDataOut(addressDataOut), .gpioPins(gpioPins)
  );

  initial begin
    $dumpfile("gpio.vcd");
    $dumpvars(0, gpio_tb); // Include DUT internals as well as testbench signals.
  end

  task write_reg;
    input [31:0] offset;
    input [31:0] value;
    begin
      @(negedge clock);
      beginTransactionIn = 1'b1;
      readNWriteIn = 1'b0;
      dataValidIn = 1'b0;
      addressDataIn = BASE + offset;
      @(negedge clock);
      beginTransactionIn = 1'b0;
      dataValidIn = 1'b1;
      addressDataIn = value;
      @(negedge clock);
      dataValidIn = 1'b0;
      addressDataIn = 32'b0;
      @(negedge clock);
    end
  endtask

  // This DUT returns read data on the rising edge after its address phase.
  // Capture at the following falling edge, after nonblocking updates settle.
  // 'which_read' selects an observation register, not a peripheral register.
  task read_reg;
    input [31:0] offset;
    input integer which_read;
    begin
      @(negedge clock);
      beginTransactionIn = 1'b1;
      readNWriteIn = 1'b1;
      dataValidIn = 1'b0;
      addressDataIn = BASE + offset;
      @(negedge clock);
      if (which_read == 3) readDir = addressDataOut;
      else                 readPin = addressDataOut;
      beginTransactionIn = 1'b0;
      addressDataIn = 32'b0;
      @(negedge clock);
      readNWriteIn = 1'b0;
      @(negedge clock);
    end
  endtask

  initial begin
    // Avoid reset races: hold it for several cycles, release on a falling edge.
    repeat (4) @(negedge clock);
    reset = 1'b0;
    repeat (2) @(negedge clock);

    phase = 1; write_reg(32'h00, 32'h00FF00FF); // RegDIR
    phase = 2; write_reg(32'h08, 32'hAAAAAAAA); // RegPORT
    phase = 3; read_reg (32'h00, 3);           // RegDIR
    phase = 4; read_reg (32'h04, 4);           // RegPIN
    phase = 5; write_reg(32'h0C, 32'h0000000F); // RegSET
    phase = 6; write_reg(32'h10, 32'h000000F0); // RegCLR

    phase = 7;
    repeat (3) @(negedge clock);
    $display("Stimulus finished. Inspect the waveform; no automatic checks were made.");
    $finish;
  end
endmodule
