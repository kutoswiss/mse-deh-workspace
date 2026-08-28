/* Native 640x480p60 timing generator (25.2 MHz pixel clock). */
module video_640x480 (
    input  wire       pixelClockIn,
    input  wire       pixelClkX2,
    input  wire       reset,
    input  wire       testPicture,
`ifdef GECKO5Education
    output wire [4:0] hdmiRed,
    output wire [4:0] hdmiGreen,
    output wire [4:0] hdmiBlue,
    output wire       pixelClock,
    output wire       horizontalSync,
    output wire       verticalSync,
    output wire       activePixel,
`else
    output reg  [3:0] red,
    output reg  [3:0] green,
    output reg  [3:0] blue,
    output reg        pixelClock,
    output reg        horizontalSync,
    output reg        verticalSync,
    output reg        activePixel,
`endif
    output reg  [9:0] pixelIndex,
    output reg  [9:0] lineIndex,
    output reg        requestPixel,
    output reg        newScreen,
    output reg        nextLine,
    output reg        hSyncOut,
    output reg        vSyncOut,
    input  wire       hSyncIn,
    input  wire       vSyncIn,
    input  wire       activeIn,
    input  wire [4:0] redIn,
    input  wire [4:0] blueIn,
    input  wire [5:0] greenIn
);

  localparam [9:0] H_ACTIVE = 10'd640;
  localparam [9:0] H_FRONT  = 10'd16;
  localparam [9:0] H_SYNC   = 10'd96;
  localparam [9:0] H_TOTAL  = 10'd800;

  localparam [9:0] V_ACTIVE = 10'd480;
  localparam [9:0] V_FRONT  = 10'd10;
  localparam [9:0] V_SYNC   = 10'd2;
  localparam [9:0] V_TOTAL  = 10'd525;

  reg [9:0] hCountReg;
  reg [9:0] vCountReg;

  wire activeVideo = (hCountReg < H_ACTIVE) && (vCountReg < V_ACTIVE);
  wire hSyncRaw = ~((hCountReg >= H_ACTIVE + H_FRONT) &&
                    (hCountReg <  H_ACTIVE + H_FRONT + H_SYNC));
  wire vSyncRaw = ~((vCountReg >= V_ACTIVE + V_FRONT) &&
                    (vCountReg <  V_ACTIVE + V_FRONT + V_SYNC));

  wire [4:0] testRed   = activeVideo ? {hCountReg[8:7], 3'b000} : 5'd0;
  wire [5:0] testGreen = activeVideo ? {hCountReg[6:5], 4'b0000} : 6'd0;
  wire [4:0] testBlue  = activeVideo ? {vCountReg[8:7], 3'b000} : 5'd0;

  wire [4:0] selectedRed   = testPicture ? testRed   : redIn;
  wire [5:0] selectedGreen = testPicture ? testGreen : greenIn;
  wire [4:0] selectedBlue  = testPicture ? testBlue  : blueIn;
  wire selectedHSync = testPicture ? hSyncRaw    : hSyncIn;
  wire selectedVSync = testPicture ? vSyncRaw    : vSyncIn;
  wire selectedActive = testPicture ? activeVideo : activeIn;

  always @(posedge pixelClockIn) begin
    if (reset) begin
      hCountReg    <= 10'd0;
      vCountReg    <= 10'd0;
      pixelIndex   <= 10'd0;
      lineIndex    <= 10'd0;
      requestPixel <= 1'b0;
      newScreen    <= 1'b0;
      nextLine     <= 1'b0;
      hSyncOut     <= 1'b1;
      vSyncOut     <= 1'b1;
    end else begin
      if (hCountReg == H_TOTAL - 1) begin
        hCountReg <= 10'd0;
        vCountReg <= (vCountReg == V_TOTAL - 1) ? 10'd0 : vCountReg + 10'd1;
      end else begin
        hCountReg <= hCountReg + 10'd1;
      end

      pixelIndex   <= hCountReg;
      lineIndex    <= vCountReg;
      requestPixel <= activeVideo;
      hSyncOut     <= hSyncRaw;
      vSyncOut     <= vSyncRaw;

      /* Start fetching the next line at the end of each active line. */
      nextLine <= (hCountReg == H_ACTIVE - 1) && (vCountReg < V_ACTIVE - 1);

      /* Prefetch line zero during the final vertical-blanking line. */
      newScreen <= (hCountReg == 10'd0) && (vCountReg == V_TOTAL - 1);
    end
  end

  reg       pixelClockReg;
  reg [4:0] redReg;
  reg [5:0] greenReg;
  reg [4:0] blueReg;
  reg       hSyncReg;
  reg       vSyncReg;
  reg       activeReg;

  always @(posedge pixelClkX2) begin
    if (reset) begin
      pixelClockReg <= 1'b1;
      redReg        <= 5'd0;
      greenReg      <= 6'd0;
      blueReg       <= 5'd0;
      hSyncReg      <= 1'b1;
      vSyncReg      <= 1'b1;
      activeReg     <= 1'b0;
    end else begin
      pixelClockReg <= ~pixelClockReg;
      if (pixelClockReg) begin
        redReg    <= selectedRed;
        greenReg  <= selectedGreen;
        blueReg   <= selectedBlue;
        hSyncReg  <= selectedHSync;
        vSyncReg  <= selectedVSync;
        activeReg <= selectedActive;
      end
    end
  end

`ifdef GECKO5Education
  OFS1P3IX hsyncff  (.CD(reset), .D(hSyncReg),      .SP(1'b1), .SCLK(pixelClkX2), .Q(horizontalSync));
  OFS1P3IX vsyncff  (.CD(reset), .D(vSyncReg),      .SP(1'b1), .SCLK(pixelClkX2), .Q(verticalSync));
  OFS1P3IX activeff (.CD(reset), .D(activeReg),     .SP(1'b1), .SCLK(pixelClkX2), .Q(activePixel));
  OFS1P3IX clockff  (.CD(reset), .D(pixelClockReg), .SP(1'b1), .SCLK(pixelClkX2), .Q(pixelClock));

  genvar i;
  generate
    for (i = 0; i < 5; i = i + 1) begin : output_bits
      OFS1P3IX redff   (.CD(reset), .D(redReg[i]),     .SP(1'b1), .SCLK(pixelClkX2), .Q(hdmiRed[i]));
      OFS1P3IX greenff (.CD(reset), .D(greenReg[i+1]), .SP(1'b1), .SCLK(pixelClkX2), .Q(hdmiGreen[i]));
      OFS1P3IX blueff  (.CD(reset), .D(blueReg[i]),    .SP(1'b1), .SCLK(pixelClkX2), .Q(hdmiBlue[i]));
    end
  endgenerate
`else
  always @* begin
    red            = redReg[4:1];
    green          = greenReg[5:2];
    blue           = blueReg[4:1];
    horizontalSync = hSyncReg;
    verticalSync   = vSyncReg;
    activePixel    = activeReg;
    pixelClock     = pixelClockReg;
  end
`endif

endmodule

