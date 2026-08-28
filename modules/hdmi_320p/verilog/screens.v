/*
 * Minimal fixed 320x240 RGB565 framebuffer, scaled 2x to 640x480 video.
 *
 * The complete framebuffer resides in SDRAM.  Two 512x32 dual-port RAMs are
 * used as alternating line buffers.  For compatibility with the original
 * graphics controller, baseAddress selects a four-register MMIO window:
 *   +0x0 width       (fixed at 320)
 *   +0x4 height      (fixed at 240)
 *   +0x8 pixel mode  (fixed at 1: RGB565)
 *   +0xC framebuffer SDRAM address (read/write)
 */
module screens #(
    parameter [31:0] baseAddress = 32'h00000000
)(
    input  wire        pixelClockIn,  // 25.2 MHz
    input  wire        pixelClkX2,    // 50.4 MHz
    input  wire        clock,         // system/bus clock
    input  wire        reset,
    input  wire        testPicture,

    output wire        requestTransaction,
    input  wire        transactionGranted,
    input  wire        beginTransactionIn,
    input  wire        endTransactionIn,
    input  wire        readNotWriteIn,
    input  wire        dataValidIn,
    input  wire        busErrorIn,
    input  wire [31:0] addressDataIn,
    input  wire [3:0]  byteEnablesIn,
    input  wire [7:0]  burstSizeIn,
    output wire        beginTransactionOut,
    output wire        endTransactionOut,
    output wire        dataValidOut,
    output wire        readNotWriteOut,
    output wire [3:0]  byteEnablesOut,
    output wire [7:0]  burstSizeOut,
    output wire [31:0] addressDataOut,

    output wire [4:0]  hdmiRed,
    output wire [4:0]  hdmiGreen,
    output wire [4:0]  hdmiBlue,
    output wire        pixelClock,
    output wire        horizontalSync,
    output wire        verticalSync,
    output wire        activePixel
);

  wire [9:0] pixelIndex;
  wire [9:0] lineIndex;
  wire       requestPixel;
  wire       newScreen;
  wire       nextLine;
  wire       hSyncRaw;
  wire       vSyncRaw;

  reg [3:0] hSyncPipe;
  reg [3:0] vSyncPipe;
  reg [3:0] activePipe;

  reg [9:0] readPixelCounterReg;
  reg       displayBufferIndexReg;
  reg       halfWordSelectReg;
  reg [15:0] pixelDataReg;
  reg [4:0] redPixelReg;
  reg [5:0] greenPixelReg;
  reg [4:0] bluePixelReg;

  /* Two output pixels select one source pixel; two source pixels share a word. */
  wire [8:0] lineBufferReadAddress = {1'b0, readPixelCounterReg[9:2]};
  wire [31:0] lineBufferData0;
  wire [31:0] lineBufferData1;

  wire        lineBufferWriteEnable;
  wire [8:0]  lineBufferWriteAddress;
  wire [31:0] lineBufferWriteData;
  wire        writeBufferIndex;

  /* Read the buffer opposite the one currently selected for DMA writes. */
  wire [31:0] displayedWord = displayBufferIndexReg ? lineBufferData1
                                                     : lineBufferData0;
  wire [15:0] selectedPixel = halfWordSelectReg ? displayedWord[31:16]
                                                 : displayedWord[15:0];

  wire newScreenSlow;
  wire newLineSlow;
  /* Prefetch the next source line while the second copy of the current line
   * is being displayed.  This gives DMA almost two complete video lines. */
  wire fetchNextSourceLine = nextLine && !lineIndex[0];

  /* Small MMIO slave retaining the programming interface of the old block. */
  reg [31:0] framebufferBaseAddressReg;
  reg [31:0] slaveAddressReg;
  reg        slaveActiveReg;
  reg        slaveReadReg;
  reg        slaveEndReg;
  reg        slaveDataValidReg;
  reg [31:0] slaveReadDataReg;

  wire slaveAddressHit = (addressDataIn[31:4] == baseAddress[31:4]);

  always @(posedge clock) begin
    if (reset) begin
      framebufferBaseAddressReg <= 32'd1; // unaligned means disabled
      slaveAddressReg           <= 32'd0;
      slaveActiveReg            <= 1'b0;
      slaveReadReg              <= 1'b0;
      slaveEndReg               <= 1'b0;
      slaveDataValidReg         <= 1'b0;
      slaveReadDataReg          <= 32'd0;
    end else begin
      slaveEndReg       <= 1'b0;
      slaveDataValidReg <= 1'b0;

      if (beginTransactionIn && slaveAddressHit) begin
        slaveAddressReg <= addressDataIn;
        slaveActiveReg  <= 1'b1;
        slaveReadReg    <= readNotWriteIn;

        if (readNotWriteIn) begin
          case (addressDataIn[3:2])
            2'd0: slaveReadDataReg <= 32'd320;
            2'd1: slaveReadDataReg <= 32'd240;
            2'd2: slaveReadDataReg <= 32'd1;
            default: slaveReadDataReg <= framebufferBaseAddressReg;
          endcase
        end
      end

      if (slaveActiveReg && slaveReadReg) begin
        slaveEndReg       <= 1'b1;
        slaveDataValidReg <= 1'b1;
        slaveActiveReg    <= 1'b0;
      end else if (slaveActiveReg && dataValidIn) begin
        /* Width, height, and mode writes are acknowledged but intentionally
         * ignored because this implementation is fixed at 640x480 RGB565. */
        if (slaveAddressReg[3:2] == 2'd3)
          framebufferBaseAddressReg <= addressDataIn;
        slaveEndReg    <= 1'b1;
        slaveActiveReg <= 1'b0;
      end

      if (busErrorIn || endTransactionIn)
        slaveActiveReg <= 1'b0;
    end
  end

  video_640x480 timing (
      .pixelClockIn(pixelClockIn),
      .pixelClkX2(pixelClkX2),
      .reset(reset),
      .testPicture(testPicture),
      .hdmiRed(hdmiRed),
      .hdmiGreen(hdmiGreen),
      .hdmiBlue(hdmiBlue),
      .pixelClock(pixelClock),
      .horizontalSync(horizontalSync),
      .verticalSync(verticalSync),
      .activePixel(activePixel),
      .pixelIndex(pixelIndex),
      .lineIndex(lineIndex),
      .requestPixel(requestPixel),
      .newScreen(newScreen),
      .nextLine(nextLine),
      .hSyncOut(hSyncRaw),
      .vSyncOut(vSyncRaw),
      .hSyncIn(hSyncPipe[3]),
      .vSyncIn(vSyncPipe[3]),
      .activeIn(activePipe[3]),
      .redIn(redPixelReg),
      .greenIn(greenPixelReg),
      .blueIn(bluePixelReg)
  );

  always @(posedge pixelClockIn) begin
    if (reset) begin
      hSyncPipe             <= 4'hF;
      vSyncPipe             <= 4'hF;
      activePipe            <= 4'h0;
      readPixelCounterReg   <= 10'd0;
      displayBufferIndexReg <= 1'b0;
      halfWordSelectReg     <= 1'b0;
      pixelDataReg          <= 16'd0;
      redPixelReg           <= 5'd0;
      greenPixelReg         <= 6'd0;
      bluePixelReg          <= 5'd0;
    end else begin
      hSyncPipe  <= {hSyncPipe[2:0], hSyncRaw};
      vSyncPipe  <= {vSyncPipe[2:0], vSyncRaw};
      activePipe <= {activePipe[2:0], requestPixel};

      if (newScreen)
        displayBufferIndexReg <= 1'b0;
      else if (nextLine && lineIndex[0])
        displayBufferIndexReg <= ~displayBufferIndexReg;

      if (nextLine)
        readPixelCounterReg <= 10'd0;
      else if (requestPixel)
        readPixelCounterReg <= readPixelCounterReg + 10'd1;

      halfWordSelectReg <= readPixelCounterReg[1];
      pixelDataReg      <= selectedPixel;
      redPixelReg       <= pixelDataReg[15:11];
      greenPixelReg     <= pixelDataReg[10:5];
      bluePixelReg      <= pixelDataReg[4:0];
    end
  end

  dualPortRam2k lineBuffer0 (
      .address1(lineBufferWriteAddress),
      .address2(lineBufferReadAddress),
      .clock1(clock),
      .clock2(pixelClockIn),
      .writeEnable(lineBufferWriteEnable && !writeBufferIndex),
      .dataIn1(lineBufferWriteData),
      .dataOut2(lineBufferData0)
  );

  dualPortRam2k lineBuffer1 (
      .address1(lineBufferWriteAddress),
      .address2(lineBufferReadAddress),
      .clock1(clock),
      .clock2(pixelClockIn),
      .writeEnable(lineBufferWriteEnable && writeBufferIndex),
      .dataIn1(lineBufferWriteData),
      .dataOut2(lineBufferData1)
  );

  synchroFlop newScreenSynchronizer (
      .clockIn(pixelClockIn),
      .clockOut(clock),
      .reset(reset),
      .D(newScreen),
      .Q(newScreenSlow)
  );

  synchroFlop newLineSynchronizer (
      .clockIn(pixelClockIn),
      .clockOut(clock),
      .reset(reset),
      .D(fetchNextSourceLine),
      .Q(newLineSlow)
  );

  fixedFramebufferDma320x240 dma (
      .clock(clock),
      .reset(reset),
      .framebufferBaseAddress(framebufferBaseAddressReg),
      .newScreen(newScreenSlow),
      .newLine(newLineSlow),
      .bufferWe(lineBufferWriteEnable),
      .bufferAddress(lineBufferWriteAddress),
      .bufferData(lineBufferWriteData),
      .writeIndex(writeBufferIndex),
      .requestTransaction(requestTransaction),
      .transactionGranted(transactionGranted),
      .endTransactionIn(endTransactionIn),
      .dataValidIn(dataValidIn),
      .busErrorIn(busErrorIn),
      .addressDataIn(addressDataIn),
      .beginTransactionOut(dmaBeginTransaction),
      .endTransactionOut(dmaEndTransaction),
      .dataValidOut(dmaDataValid),
      .readNotWriteOut(dmaReadNotWrite),
      .byteEnablesOut(dmaByteEnables),
      .burstSizeOut(dmaBurstSize),
      .addressDataOut(dmaAddressData)
  );

  wire        dmaBeginTransaction;
  wire        dmaEndTransaction;
  wire        dmaDataValid;
  wire        dmaReadNotWrite;
  wire [3:0]  dmaByteEnables;
  wire [7:0]  dmaBurstSize;
  wire [31:0] dmaAddressData;

  assign beginTransactionOut = dmaBeginTransaction;
  assign endTransactionOut   = slaveEndReg | dmaEndTransaction;
  assign dataValidOut        = slaveDataValidReg | dmaDataValid;
  assign readNotWriteOut     = dmaReadNotWrite;
  assign byteEnablesOut      = dmaByteEnables;
  assign burstSizeOut        = dmaBurstSize;
  assign addressDataOut      = slaveDataValidReg ? slaveReadDataReg
                                                 : dmaAddressData;

endmodule

