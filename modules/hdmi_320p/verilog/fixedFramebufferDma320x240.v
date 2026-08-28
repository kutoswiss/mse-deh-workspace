/*
 * Fixed 320x240 RGB565 framebuffer reader.
 * A source line is 320 16-bit pixels = 160 32-bit words and is transferred
 * with one burst.  The screens module displays every source line twice.
 */
module fixedFramebufferDma320x240 (
    input  wire        clock,
    input  wire        reset,
    input  wire [31:0] framebufferBaseAddress,
    input  wire        newScreen,
    input  wire        newLine,
    output wire        bufferWe,
    output wire [8:0]  bufferAddress,
    output wire [31:0] bufferData,
    output wire        writeIndex,
    output wire        requestTransaction,
    input  wire        transactionGranted,
    input  wire        endTransactionIn,
    input  wire        dataValidIn,
    input  wire        busErrorIn,
    input  wire [31:0] addressDataIn,
    output wire        beginTransactionOut,
    output wire        endTransactionOut,
    output wire        dataValidOut,
    output wire        readNotWriteOut,
    output wire [3:0]  byteEnablesOut,
    output wire [7:0]  burstSizeOut,
    output wire [31:0] addressDataOut
);

  localparam [2:0] IDLE       = 3'd0;
  localparam [2:0] REQUEST    = 3'd1;
  localparam [2:0] START      = 3'd2;
  localparam [2:0] READ       = 3'd3;
  localparam [2:0] LINE_DONE  = 3'd4;
  localparam [2:0] ERROR_WAIT = 3'd5;

  reg [2:0]  stateReg;
  reg [2:0]  stateNext;
  reg [31:0] currentAddressReg;
  reg [8:0]  writeAddressReg;
  reg        writeIndexReg;
  reg        endTransactionInReg;
  reg        linePendingReg;

  wire lineRequest = newScreen | newLine | linePendingReg;

  always @* begin
    case (stateReg)
      IDLE:       stateNext = lineRequest ? REQUEST : IDLE;
      REQUEST:    stateNext = transactionGranted ? START : REQUEST;
      START:      stateNext = READ;
      READ:       stateNext = busErrorIn ? ERROR_WAIT :
                              endTransactionInReg ? LINE_DONE : READ;
      LINE_DONE:  stateNext = IDLE;
      ERROR_WAIT: stateNext = endTransactionInReg ? IDLE : ERROR_WAIT;
      default:    stateNext = IDLE;
    endcase
  end

  always @(posedge clock) begin
    if (reset) begin
      stateReg            <= IDLE;
      currentAddressReg   <= framebufferBaseAddress;
      writeAddressReg     <= 9'd0;
      writeIndexReg       <= 1'b0;
      endTransactionInReg <= 1'b0;
      linePendingReg      <= 1'b0;
    end else begin
      stateReg            <= stateNext;
      endTransactionInReg <= endTransactionIn;

      /* Never silently lose a line event while the bus is busy. */
      if ((newScreen || newLine) && stateReg != IDLE)
        linePendingReg <= 1'b1;
      else if (stateReg == IDLE && lineRequest)
        linePendingReg <= 1'b0;

      if (newScreen)
        currentAddressReg <= framebufferBaseAddress;
      else if (stateReg == READ && dataValidIn)
        currentAddressReg <= currentAddressReg + 32'd4;

      if (stateReg == START)
        writeAddressReg <= 9'd0;
      else if (stateReg == READ && dataValidIn)
        writeAddressReg <= writeAddressReg + 9'd1;

      if (newScreen)
        writeIndexReg <= 1'b0;
      else if (stateReg == LINE_DONE)
        writeIndexReg <= ~writeIndexReg;
    end
  end

  assign requestTransaction  = (stateReg == REQUEST);
  assign beginTransactionOut = (stateReg == START);
  assign endTransactionOut   = 1'b0;
  assign dataValidOut        = 1'b0;
  assign readNotWriteOut     = (stateReg == START);
  assign byteEnablesOut      = (stateReg == START) ? 4'hF : 4'h0;
  /* The shared bus represents a burst of N words as N-1. */
  assign burstSizeOut        = (stateReg == START) ? 8'd159 : 8'd0;
  assign addressDataOut      = (stateReg == START) ? currentAddressReg : 32'd0;
  assign bufferWe            = (stateReg == READ) && dataValidIn;
  assign bufferAddress       = writeAddressReg;
  assign bufferData          = addressDataIn;
  assign writeIndex          = writeIndexReg;

endmodule

