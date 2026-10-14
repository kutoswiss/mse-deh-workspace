`timescale 1ns/1ps

// HEPIA CoRES - CRC32 waveform exercise.
// Computes the CRC32 of the ASCII string "12345678" through the bus wrapper.
module crc32_tb;
localparam [31:0] BASE = 32'h50000140;
localparam integer PERIOD = 10;

// Register offsets (byte addresses, matching crc32Slave)
localparam [31:0] OFF_CONTROL    = 32'h00;
localparam [31:0] OFF_DATA       = 32'h04;
localparam [31:0] OFF_RESULT     = 32'h08;
localparam [31:0] OFF_WORD_COUNT = 32'h0C;

// Reference: standard CRC-32 (IEEE 802.3, as zlib/Python) of "12345678"
localparam [31:0] EXPECTED_CRC = 32'h9AE0DAAF;

reg clock = 1'b0;
reg reset = 1'b1;
reg beginTransactionIn = 1'b0;
reg readNWriteIn = 1'b0;
reg dataValidIn = 1'b0;
reg [31:0] addressDataIn = 32'b0;
wire dataValidOut, endTransactionOut;
wire [31:0] addressDataOut;

integer phase = 0; // Waveform marker, not a DUT port.
reg [31:0] readResult = 32'hxxxxxxxx;
reg [31:0] readCount  = 32'hxxxxxxxx;

always #(PERIOD / 2) clock = ~clock;

crc32Slave #(.BASE_ADDRESS(32'h50000140), .LAST_ADDRESS(32'h5000015F)) dut (
    .clock(clock), .reset(reset),
    .beginTransactionIn(beginTransactionIn),
    .readNWriteIn(readNWriteIn), .dataValidIn(dataValidIn),
    .addressDataIn(addressDataIn),
    .dataValidOut(dataValidOut), .endTransactionOut(endTransactionOut),
    .addressDataOut(addressDataOut)
  );

initial begin
$dumpfile("crc32.vcd");
$dumpvars(0, crc32_tb); // Include DUT internals (and the CRC core).
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

// The DUT returns read data on the rising edge after its address phase.
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
if (which_read == 0) readResult = addressDataOut;
else                 readCount  = addressDataOut;
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

// "12345678" = 0x31 0x32 0x33 0x34 0x35 0x36 0x37 0x38
// Packed big-endian (first character in bits [31:24]), as a big-endian
// CPU like OpenRISC would load it from memory.
phase = 1; write_reg(OFF_CONTROL, 32'h00000001); // restart CRC
phase = 2; write_reg(OFF_DATA, 32'h34333231); // "1234", first char in [7:0]
phase = 3; write_reg(OFF_DATA, 32'h38373635); // "5678"k
phase = 4; read_reg (OFF_RESULT,     0);
phase = 5; read_reg (OFF_WORD_COUNT, 1);

phase = 6;
repeat (3) @(negedge clock);
$display("CRC32 result : 0x%08h (expected 0x%08h)", readResult, EXPECTED_CRC);
$display("Word count   : %0d (expected 2)", readCount);
$display("Stimulus finished. Inspect the waveform; no automatic checks were made.");
$finish;
end
endmodule
