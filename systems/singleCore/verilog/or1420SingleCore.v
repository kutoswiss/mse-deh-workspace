module or1420SingleCore ( input wire         clock12MHz,
                                             clock50MHz,
                                             nReset,
                          input wire         RxD,
                          output wire        TxD,

                          output wire        sdramClk,
                          output wire        sdramCke,
                                             sdramCsN,
                                             sdramRasN,
                                             sdramCasN,
                                             sdramWeN,
                          output wire [1:0]  sdramDqmN,
                          output wire [12:0] sdramAddr,
                          output wire [1:0]  sdramBa,
                          inout wire [15:0]  sdramData,

                          // The spi interface
                          output wire        spiScl,
                                             spiNCs,
                          inout wire         spiSiIo0,
                                             spiSoIo1,
                                             spiIo2,
                                             spiIo3,

                          output wire        pixelClock,
                                             horizontalSync,
                                             verticalSync,
                                             activePixel,
                      
                          output wire [4:0]  hdmiRed,
                                             hdmiBlue,
                                             hdmiGreen,
                                             
                          output wire        SCL,
                          inout wire         SDA,
                          input wire         camPclk,
                                             camHsync,
                                             camVsync,
                                             biosBypass,
                          input wire [7:0]   camData,

                          output wire [3:0] columnAddress,
                          output wire [9:0] nRedRow,
                          output wire [9:0] nGreenRow,
                          output wire [9:0] nBlueRow
                           );

  wire        s_busIdle, s_snoopableBurst;
  wire        s_systemClock, s_systemClockX2, s_swapByteDone, s_flashDone, s_cpuFreqDone;
  wire [31:0] s_swapByteResult, s_flashResult, s_cpuFreqResult;
  wire [5:0]  s_memoryDistance = 6'd0;
  wire        s_busError, s_beginTransaction, s_endTransaction;
  wire [31:0] s_addressData;
  wire [3:0]  s_byteEnables;
  wire        s_readNotWrite, s_dataValid, s_busy;
  wire [7:0]  s_burstSize;
  
  
  /*
   *
   * We use a PLL to generate the required clocks for the HDMI part
   *
   */
  reg[4:0] s_resetCountReg;
  wire     s_pixelClock;
  wire     s_pixelClkX2;
  wire     s_pllLocked;
  wire     s_reset = ~s_resetCountReg[4];

  assign camnReset = s_resetCountReg[4];


  always @(posedge s_systemClock or negedge s_pllLocked)
    if (s_pllLocked == 1'b0) s_resetCountReg <= 5'd0;
    else s_resetCountReg <= (s_resetCountReg[4] == 1'b0) ? s_resetCountReg + 5'd1 : s_resetCountReg;
  
  wire s_resetPll = ~nReset;
  wire s_feedbackClock;
  localparam CPU_CLOCK_FREQUENCY=74250000;
  // CPU @ 74.25MHz
  EHXPLLL #(
        .PLLRST_ENA("ENABLED"),
        .INTFB_WAKE("DISABLED"),
        .STDBY_ENABLE("DISABLED"),
        .DPHASE_SOURCE("DISABLED"),
        .OUTDIVIDER_MUXA("DIVA"),
        .OUTDIVIDER_MUXB("DIVB"),
        .OUTDIVIDER_MUXC("DIVC"),
        .OUTDIVIDER_MUXD("DIVD"),
        .CLKI_DIV(1),
        .CLKOP_ENABLE("ENABLED"),
        .CLKOP_DIV(4),
        .CLKOP_CPHASE(1),
        .CLKOP_FPHASE(0),
        .CLKOS_ENABLE("ENABLED"),
        .CLKOS_DIV(8),
        .CLKOS_CPHASE(1),
        .CLKOS_FPHASE(0),
        .CLKOS2_ENABLE("ENABLED"),
        .CLKOS2_DIV(8),
        .CLKOS2_CPHASE(1),
        .CLKOS2_FPHASE(0),
        .CLKOS3_ENABLE("ENABLED"),
        .CLKOS3_DIV(4),
        .CLKOS3_CPHASE(1),
        .CLKOS3_FPHASE(0),
        .FEEDBK_PATH("INT_OP"),
        .CLKFB_DIV(2)
    ) pll_1 (
        .RST(s_resetPll),
        .STDBY(1'b0),
        .CLKI(clock12MHz),
        .CLKOP(s_pixelClkX2),
        .CLKOS(s_pixelClock),
        .CLKOS2(s_systemClock),
        .CLKOS3(s_systemClockX2),
        .CLKFB(s_feedbackClock),
        .CLKINTFB(s_feedbackClock),
        .PHASESEL0(1'b0),
        .PHASESEL1(1'b0),
        .PHASEDIR(1'b1),
        .PHASESTEP(1'b1),
        .PHASELOADREG(1'b1),
        .PLLWAKESYNC(1'b0),
        .ENCLKOP(1'b0),
        .LOCK(s_pllLocked)
	);


  /*
   * Here we instantiate the UART
   *
   */
  wire s_uartIrq, s_uartEndTransaction, s_uartDataValid, s_uartBusError;
  wire [31:0] s_uartAddressData;
  uartBus #( .baseAddress(32'h50000000) ) uart1
           ( .clock(s_systemClock),
             .clock_50MHz(clock50MHz),
             .reset(s_reset),
             .irq(s_uartIrq),
             .beginTransactionIn(s_beginTransaction),
             .endTransactionIn(s_endTransaction),
             .readNWriteIn(s_readNotWrite),
             .dataValidIn(s_dataValid),
             .busyIn(s_busy),
             .addressDataIn(s_addressData),
             .byteEnablesIn(s_byteEnables),
             .burstSizeIn(s_burstSize),
             .addressDataOut(s_uartAddressData),
             .endTransactionOut(s_uartEndTransaction),
             .dataValidOut(s_uartDataValid),
             .busErrorOut(s_uartBusError),
             .RxD(RxD),
             .TxD(TxD));

  /*
   * Here we instantiate the SDRAM controller
   *
   */
  wire        s_sdramInitBusy, s_sdramEndTransaction, s_sdramDataValid;
  wire        s_sdramBusy, s_sdramBusError;
  wire [31:0] s_sdramAddressData;
  wire        s_cpuReset = s_reset | s_sdramInitBusy;
  
  sdramController #( .baseAddress(32'h00000000),
                     .systemClockInHz(CPU_CLOCK_FREQUENCY)) sdram
                   ( .clock(s_systemClock),
                     .clockX2(s_systemClockX2),
                     .reset(s_reset),
                     .memoryDistanceIn(s_memoryDistance),
                     .sdramDelay(2'd2),
                     .sdramInitBusy(s_sdramInitBusy),
                     .beginTransactionIn(s_beginTransaction),
                     .endTransactionIn(s_endTransaction),
                     .readNotWriteIn(s_readNotWrite),
                     .dataValidIn(s_dataValid),
                     .busErrorIn(s_busError),
                     .busyIn(s_busy),
                     .addressDataIn(s_addressData),
                     .byteEnablesIn(s_byteEnables),
                     .burstSizeIn(s_burstSize),
                     .endTransactionOut(s_sdramEndTransaction),
                     .dataValidOut(s_sdramDataValid),
                     .busyOut(s_sdramBusy),
                     .busErrorOut(s_sdramBusError),
                     .addressDataOut(s_sdramAddressData),
                     .sdramClk(sdramClk),
                     .sdramCke(sdramCke),
                     .sdramCsN(sdramCsN),
                     .sdramRasN(sdramRasN),
                     .sdramCasN(sdramCasN),
                     .sdramWeN(sdramWeN),
                     .sdramDqmN(sdramDqmN),
                     .sdramAddr(sdramAddr),
                     .sdramBa(sdramBa),
                     .sdramData(sdramData));

  /*
   * Here we instantiate the CPU
   *
   */
  wire [31:0] s_cpu1CiResult;
  wire [31:0] s_cpu1CiDataA, s_cpu1CiDataB, s_delayResult;
  wire [7:0]  s_cpu1CiN;
  wire        s_cpu1CiRa, s_cpu1CiRb, s_cpu1CiRc, s_cpu1CiStart, s_cpu1CiCke, s_cpu1CiDone, s_delayCiDone;
  wire [4:0]  s_cpu1CiA, s_cpu1CiB, s_cpu1CiC;
  wire        s_cpu1IcacheRequestBus, s_cpu1DcacheRequestBus;
  wire        s_cpu1IcacheBusAccessGranted, s_cpu1DcacheBusAccessGranted;
  wire        s_cpu1BeginTransaction, s_cpu1EndTransaction, s_cpu1ReadNotWrite;
  wire [31:0] s_cpu1AddressData;
  wire [3:0]  s_cpu1byteEnables;
  wire        s_cpu1DataValid;
  wire [7:0]  s_cpu1BurstSize;
  wire        s_spm1Irq, s_stall;
  
  assign s_cpu1CiDone = s_swapByteDone | s_flashDone | s_cpuFreqDone | s_delayCiDone;
  assign s_cpu1CiResult = s_swapByteResult | s_flashResult | s_cpuFreqResult | s_delayResult; 

  or1420Top #( .NOP_INSTRUCTION(32'h1500FFFF)) cpu1
             (.cpuClock(s_systemClock),
              .cpuReset(s_cpuReset),
              .irq(1'b0),
              .cpuIsStalled(s_stall),
              .iCacheReqBus(s_cpu1IcacheRequestBus),
              .dCacheReqBus(s_cpu1DcacheRequestBus),
              .iCacheBusGrant(s_cpu1IcacheBusAccessGranted),
              .dCacheBusGrant(s_cpu1DcacheBusAccessGranted),
              .busErrorIn(s_busError),
              .busyIn(s_busy),
              .beginTransActionOut(s_cpu1BeginTransaction),
              .addressDataIn(s_addressData),
              .addressDataOut(s_cpu1AddressData),
              .endTransactionIn(s_endTransaction),
              .endTransactionOut(s_cpu1EndTransaction),
              .byteEnablesOut(s_cpu1byteEnables),
              .dataValidIn(s_dataValid),
              .dataValidOut(s_cpu1DataValid),
              .readNotWriteOut(s_cpu1ReadNotWrite),
              .burstSizeOut(s_cpu1BurstSize),
              .ciStart(s_cpu1CiStart),
              .ciReadRa(s_cpu1CiRa),
              .ciReadRb(s_cpu1CiRb),
              .ciWriteRd(s_cpu1CiRc),
              .ciN(s_cpu1CiN),
              .ciA(s_cpu1CiA),
              .ciB(s_cpu1CiB),
              .ciD(s_cpu1CiC),
              .ciDataA(s_cpu1CiDataA),
              .ciDataB(s_cpu1CiDataB),
              .ciResult(s_cpu1CiResult),
              .ciDone(s_cpu1CiDone));
              
              assign s_cpu1CiCke = 1'b1;

  /*
   *
   * Here we define a custom instruction that determines the cpu-frequency
   *
   *
   */
  wire [31:0] s_cpuFreqValue;
  assign s_cpuFreqDone = (s_cpu1CiN == 8'd4) ? s_cpu1CiStart : 1'b0;
  assign s_cpuFreqResult = (s_cpu1CiN == 8'd4 && s_cpu1CiStart == 1'b1) ? s_cpuFreqValue : 32'd0;
  
  processorId #( .processorId(1),
                 .NumberOfProcessors(1),
                 .ReferenceClockFrequencyInHz(50000000) ) cpuFreq
               ( .clock(s_systemClock),
                 .reset(s_cpuReset),
                 .referenceClock(clock50MHz),
                 .biosBypass(biosBypass),
                 .procFreqId(s_cpuFreqValue) );

  /*
   *
   * Here we define a custom instruction that swaps bytes
   *
   */
  swapByte #(.customIntructionNr(8'd1)) ise1
            (.ciN(s_cpu1CiN),
             .ciDataA(s_cpu1CiDataA),
             .ciDataB(s_cpu1CiDataB),
             .ciStart(s_cpu1CiStart),
             .ciCke(s_cpu1CiCke),
             .ciDone(s_swapByteDone),
             .ciResult(s_swapByteResult));
  /*
   * Memory-mapped I2C controller.
   * Register bank: 0x50000040 .. 0x5000004F
   */
  wire [31:0] s_i2cAddressData;
  wire        s_i2cEndTransaction, s_i2cDataValid, s_i2cBusError;

  i2cBus #(.CLOCK_FREQUENCY(CPU_CLOCK_FREQUENCY),
           .I2C_FREQUENCY(400000),
           .baseAddress(32'h50000040)) i2cm
          (.clock(s_systemClock),
           .reset(s_cpuReset),
           .beginTransactionIn(s_beginTransaction),
           .endTransactionIn(s_endTransaction),
           .readNotWriteIn(s_readNotWrite),
           .dataValidIn(s_dataValid),
           .busyIn(s_busy),
           .addressDataIn(s_addressData),
           .byteEnablesIn(s_byteEnables),
           .burstSizeIn(s_burstSize),
           .addressDataOut(s_i2cAddressData),
           .endTransactionOut(s_i2cEndTransaction),
           .dataValidOut(s_i2cDataValid),
           .busErrorOut(s_i2cBusError),
           .SDA(SDA),
           .SCL(SCL));

  /*
   *
   * Here we define a custom instruction that implements a blocking micro-second(s) delay element
   *
   */
  delayIse #(.referenceClockFrequencyInHz(50000000),
             .customInstructionId(8'd6) ) delayMicro
            (.clock(s_systemClock),
             .referenceClock(clock50MHz),
             .reset(s_cpuReset),
             .ciStart(s_cpu1CiStart),
             .ciCke(s_cpu1CiCke),
             .ciN(s_cpu1CiN),
             .ciValueA(s_cpu1CiDataA),
             .ciValueB(s_cpu1CiDataB),
             .ciDone(s_delayCiDone),
             .ciResult(s_delayResult));

  /*
   * Camera interface
   *
   * MMIO control/status: 0x50000060
   * DMA master: framebuffer writes to SDRAM
   */
  // Camera DMA master interface
  wire        s_camMasterReqBus, s_camMasterAckBus;
  wire        s_camMasterBeginTransaction, s_camMasterEndTransaction;
  wire        s_camMasterDataValid;
  wire [31:0] s_camMasterAddressData;
  wire [3:0]  s_camMasterByteEnables;
  wire [7:0]  s_camMasterBurstSize;


  // Camera MMIO slave interface
  wire        s_camSlaveEndTransaction, s_camSlaveDataValid, s_camSlaveBusError;
  wire [31:0] s_camSlaveAddressData;


  camera camIf    			// Activate if VHDL
//  camera #(.baseAddress(32'h50000060),   // Activate if verilog
//           .clockFrequencyInHz(CPU_CLOCK_FREQUENCY)) camIf // Activate if verilog
          (.clock(s_systemClock),
           .pclk(camPclk),
           .reset(s_cpuReset),
           .hsync(camHsync),
           .vsync(camVsync),
           .camData(camData),

           .slaveBeginTransactionIn(s_beginTransaction),
           .slaveEndTransactionIn(s_endTransaction),
           .slaveReadNotWriteIn(s_readNotWrite),
           .slaveDataValidIn(s_dataValid),
           .slaveBusyIn(s_busy),
           .slaveAddressDataIn(s_addressData),
           .slaveByteEnablesIn(s_byteEnables),
           .slaveBurstSizeIn(s_burstSize),
           .slaveAddressDataOut(s_camSlaveAddressData),
           .slaveEndTransactionOut(s_camSlaveEndTransaction),
           .slaveDataValidOut(s_camSlaveDataValid),
           .slaveBusErrorOut(s_camSlaveBusError),

           // DMA master interface
           .masterRequestBus(s_camMasterReqBus),
           .masterBusGrant(s_camMasterAckBus),
           .masterBusyIn(s_busy),
           .masterBusErrorIn(s_busError),
           .masterBeginTransactionOut(s_camMasterBeginTransaction),
           .masterEndTransactionOut(s_camMasterEndTransaction),
           .masterDataValidOut(s_camMasterDataValid),
           .masterAddressDataOut(s_camMasterAddressData),
           .masterByteEnablesOut(s_camMasterByteEnables),
           .masterBurstSizeOut(s_camMasterBurstSize));

  
  /*
   * Logic analyser connected to the camera DMA write-master interface.
   *
   * i_tappedWires layout:
   *   [63:51] unused
   *   [50:19] address/data bus
   *   [18:11] burst size
   *   [10:7]  byte enables
   *   [6]     bus error
   *   [5]     bus busy
   *   [4]     data valid
   *   [3]     end transaction
   *   [2]     begin transaction
   *   [1]     bus grant
   *   [0]     bus request
   */
  //lac #(.sampleBitwidth(64)) cameraDmaLac (
  //    .i_clock(s_systemClock),
  //    .i_tappedWires({
  //        13'd0,
  //        s_camMasterAddressData,
  //        s_camMasterBurstSize,
  //        s_camMasterByteEnables,
  //        s_busError,
  //        s_busy,
  //        s_camMasterDataValid,
  //        s_camMasterEndTransaction,
  //        s_camMasterBeginTransaction,
  //        s_camMasterAckBus,
  //        s_camMasterReqBus
  //    })
  //);

  /* MMIO performance counter at 0x50000120. */
  wire        s_perfEndTransaction;
  wire        s_perfDataValid;
  wire [31:0] s_perfAddressData;

  perf #(
      .BASE_ADDRESS(32'h50000120),
      .CLOCK_FREQUENCY_HZ(CPU_CLOCK_FREQUENCY)
  ) perf1 (
      .clock(s_systemClock),
      .reset(s_reset),
      .beginTransactionIn(s_beginTransaction),
      .readNWriteIn(s_readNotWrite),
      .dataValidIn(s_dataValid),
      .addressDataIn(s_addressData),
      .dataValidOut(s_perfDataValid),
      .endTransactionOut(s_perfEndTransaction),
      .addressDataOut(s_perfAddressData)
  );

  /*
   *
   * Here we define the gpio slave
   *
   */
   wire [1:0] s_gpioUnused;
   assign columnAddress = 4'b0000;

   wire s_gpioDataValid, s_gpioEndTransaction;
   wire [31:0] s_gpioAddressData;

   gpioSlave #(.INVERT_PINS(1)) gpio1 (
    .clock(s_systemClock),
    .reset(s_reset),
    .beginTransactionIn(s_beginTransaction),
    .readNWriteIn(s_readNotWrite),
    .dataValidIn(s_dataValid),
    .addressDataIn(s_addressData),
    .dataValidOut(s_gpioDataValid),
    .endTransactionOut(s_gpioEndTransaction),
    .addressDataOut(s_gpioAddressData),
    .gpioPins({s_gpioUnused, nBlueRow, nGreenRow, nRedRow})
   );

  /*
   *
   * Here we define the crc32 slave
   *
   */
   wire s_crc32DataValid, s_crc32EndTransaction;
   wire [31:0] s_crc32AddressData;

   crc32Slave crc32(
    .clock(s_systemClock),
    .reset(s_reset),
    .beginTransactionIn(s_beginTransaction),
    .readNWriteIn(s_readNotWrite),
    .dataValidIn(s_dataValid),
    .addressDataIn(s_addressData),
    .dataValidOut(s_crc32DataValid),
    .endTransactionOut(s_crc32EndTransaction),
    .addressDataOut(s_crc32AddressData),
   );

  /*
   *
   * Here we define the crc32 dma 
   *
   */

  // crc32 dma master interface
  wire        s_crc32DmaMasterReqBus;
  wire        s_crc32DmaMasterBusGranted;
  wire        s_crc32DmaMasterBeginTransaction;
  wire        s_crc32DmaMasterReadNotWrite;
  wire [3:0]  s_crc32DmaMasterByteEnables;
  wire [31:0] s_crc32DmaMasterAddressData;
  wire [7:0]  s_crc32DmaMasterBurstSize;

  // crc32 dma slave interface
  wire        s_crc32DmaSlaveDataValid;
  wire        s_crc32DmaSlaveEndTransaction;
  wire [31:0] s_crc32DmaSlaveAddressData;

  //assign s_crc32DmaMasterReqBus = 1'd0;
  //assign s_crc32DmaMasterBeginTransaction = 1'd0;
  //assign s_crc32DmaMasterReadNotWrite = 1'd0;
  //assign s_crc32DmaMasterByteEnables = 4'd0;
  //assign s_crc32DmaMasterAddressData = 32'd0;
  //assign s_crc32DmaMasterBurstSize = 8'd0;

  //assign s_crc32DmaSlaveDataValid = 1'd0;
  //assign s_crc32DmaSlaveEndTransaction = 1'd0;
  //assign s_crc32DmaSlaveAddressData = 32'd0;

  //crc32Dma #(.BURST_SIZE(240)) crc32_dma(
  crc32Dma #(.BURST_SIZE(16)) crc32_dma(
  //crc32Dma crc32_dma(
   .clock(s_systemClock),
   .reset(s_reset),

   // Slave interface
   .slaveBeginTransactionIn(s_beginTransaction),
   .slaveReadNWriteIn(s_readNotWrite),
   .slaveDataValidIn(s_dataValid),
   .slaveAddressDataIn(s_addressData),

   .slaveDataValidOut(s_crc32DmaSlaveDataValid),
   .slaveEndTransactionOut(s_crc32DmaSlaveEndTransaction),
   .slaveAddressDataOut(s_crc32DmaSlaveAddressData),

   // DMA master interface
   .masterBusGrant(s_crc32DmaMasterBusGranted),
   .masterDataValidIn(s_dataValid),
   .masterAddressDataIn(s_addressData),
   .masterEndTransactionIn(s_endTransaction),

   .masterRequestBus(s_crc32DmaMasterReqBus),
   .masterBeginTransactionOut(s_crc32DmaMasterBeginTransaction),
   .masterReadNWriteOut(s_crc32DmaMasterReadNotWrite),
   .masterByteEnablesOut(s_crc32DmaMasterByteEnables),
   .masterAddressDataOut(s_crc32DmaMasterAddressData),
   .masterBurstSizeOut(s_crc32DmaMasterBurstSize)
  );

  /*
   * Logic analyser connected to the CRC32 DMA write-master interface.
   */
  lac #(.sampleBitwidth(64)) crc32DmaLacDeGeneve (
      .i_clock(s_systemClock),
      .i_tappedWires({
          18'd0,
          s_endTransaction, // 1
          s_crc32DmaMasterBeginTransaction, // 1
          s_addressData, // 32
          s_dataValid, // 1
          s_crc32DmaMasterBurstSize, // 8
          s_crc32DmaMasterBusGranted, // 1
          s_crc32DmaMasterReqBus // 1
      })
  );

  /*
   *
   * Here the hdmi controller is defined
   *
   */
  wire        s_hdmiRequestBus, s_hdmiBusgranted, s_hdmiBeginTransaction;
  wire        s_hdmiEndTransaction, s_hdmiDataValid, s_hdmiReadNotWrite;
  wire [3:0]  s_hdmiByteEnables;
  wire [7:0]  s_hdmiBurstSize;
  wire [31:0] s_hdmiAddressData;

  screens #(.baseAddress(32'h50000020)) hdmi 
           (.pixelClockIn(s_pixelClock),
            .clock(s_systemClock),
            .reset(s_reset),
            .testPicture(1'b0),
            .requestTransaction(s_hdmiRequestBus),
            .transactionGranted(s_hdmiBusgranted),
            .beginTransactionIn(s_beginTransaction),
            .endTransactionIn(s_endTransaction),
            .readNotWriteIn(s_readNotWrite),
            .dataValidIn(s_dataValid),
            .busErrorIn(s_busError),
            .addressDataIn(s_addressData),
            .byteEnablesIn(s_byteEnables),
            .burstSizeIn(s_burstSize),
            .beginTransactionOut(s_hdmiBeginTransaction),
            .endTransactionOut(s_hdmiEndTransaction),
            .dataValidOut(s_hdmiDataValid),
            .readNotWriteOut(s_hdmiReadNotWrite),
            .byteEnablesOut(s_hdmiByteEnables),
            .burstSizeOut(s_hdmiBurstSize),
            .addressDataOut(s_hdmiAddressData),
            .pixelClkX2(s_pixelClkX2),
            .hdmiRed(hdmiRed),
            .hdmiGreen(hdmiGreen),
            .hdmiBlue(hdmiBlue),
            .pixelClock(pixelClock),
            .horizontalSync(horizontalSync),
            .verticalSync(verticalSync),
            .activePixel(activePixel)
            );

  /*
   *
   * Here the spi-flash controller is defined
   *
   */
  wire [31:0] s_flashAddressData;
  wire s_flashEndTransaction, s_flashDataValid, s_flashBusError;
  spiBus #( .baseAddress(32'h04000000),
            .customIntructionNr(8'd2)) flash
          ( .clock(s_systemClock),
            .reset(s_reset),
            .spiScl(spiScl),
            .spiNCs(spiNCs),
            .spiSiIo0(spiSiIo0),
            .spiSoIo1(spiSoIo1),
            .spiIo2(spiIo2),
            .spiIo3(spiIo3),
            .ciN(s_cpu1CiN),
            .ciDataA(s_cpu1CiDataA),
            .ciDataB(s_cpu1CiDataB),
            .ciStart(s_cpu1CiStart),
            .ciCke(s_cpu1CiCke),
            .ciDone(s_flashDone),
            .ciResult(s_flashResult),
            .beginTransactionIn(s_beginTransaction),
            .endTransactionIn(s_endTransaction),
            .readNotWriteIn(s_readNotWrite),
            .busErrorIn(s_busError),
            .addressDataIn(s_addressData),
            .burstSizeIn(s_burstSize),
            .byteEnablesIn(s_byteEnables),
            .addressDataOut(s_flashAddressData),
            .endTransactionOut(s_flashEndTransaction),
            .dataValidOut(s_flashDataValid),
            .busErrorOut(s_flashBusError) );

  /*
   *
   * Here we define the bios
   *
   */
  wire [31:0] s_biosAddressData;
  wire        s_biosBusError, s_biosDataValid, s_biosEndTransaction;
  bios start (.clock(s_systemClock),
              .reset(s_reset),
              .addressDataIn(s_addressData),
              .beginTransactionIn(s_beginTransaction),
              .endTransactionIn(s_endTransaction),
              .readNotWriteIn(s_readNotWrite),
              .busErrorIn(s_busError),
              .dataValidIn(s_dataValid),
              .byteEnablesIn(s_byteEnables),
              .burstSizeIn(s_burstSize),
              .addressDataOut(s_biosAddressData),
              .busErrorOut(s_biosBusError),
              .dataValidOut(s_biosDataValid),
              .endTransactionOut(s_biosEndTransaction));

  /*
   *
   * Here we define the bus arbiter
   *
   */
 wire [31:0] s_busRequests, s_busGrants;
 wire        s_arbBusError, s_arbEndTransaction;
 
 assign s_busRequests[31] = s_cpu1DcacheRequestBus;
 assign s_busRequests[30] = s_cpu1IcacheRequestBus;
 assign s_busRequests[29] = s_hdmiRequestBus;
 assign s_busRequests[28] = s_camMasterReqBus;
 assign s_busRequests[27] = s_crc32DmaMasterReqBus;
 assign s_busRequests[26:0] = 27'd0;
 
 assign s_cpu1DcacheBusAccessGranted = s_busGrants[31];
 assign s_cpu1IcacheBusAccessGranted = s_busGrants[30];
 assign s_hdmiBusgranted             = s_busGrants[29];
 assign s_camMasterAckBus            = s_busGrants[28];
 assign s_crc32DmaMasterBusGranted   = s_busGrants[27];

 busArbiter arbiter ( .clock(s_systemClock),
                      .reset(s_reset),
                      .busRequests(s_busRequests),
                      .busGrants(s_busGrants),
                      .busErrorOut(s_arbBusError),
                      .endTransactionOut(s_arbEndTransaction),
                      .busIdle(s_busIdle),
                      .snoopableBurst(s_snoopableBurst),
                      .beginTransactionIn(s_beginTransaction),
                      .endTransactionIn(s_endTransaction),
                      .dataValidIn(s_dataValid),
                      .addressDataIn(s_addressData[31:30]),
                      .burstSizeIn(s_burstSize));
 
  /*
   *
   * Here we define the bus architecture
   *
   */
 assign s_busError = s_arbBusError | 
                     s_biosBusError | 
                     s_uartBusError | 
                     s_sdramBusError | 
                     s_flashBusError | 
                     s_i2cBusError | 
                     s_camSlaveBusError;

 assign s_beginTransaction = s_cpu1BeginTransaction | 
                             s_hdmiBeginTransaction | 
                             s_camMasterBeginTransaction | 
                             s_crc32DmaMasterBeginTransaction;

 assign s_endTransaction   = s_cpu1EndTransaction | 
                             s_arbEndTransaction | 
                             s_biosEndTransaction | 
                             s_uartEndTransaction | 
                             s_perfEndTransaction |
                             s_sdramEndTransaction | 
                             s_hdmiEndTransaction | 
                             s_flashEndTransaction |
                             s_camMasterEndTransaction | 
                             s_camSlaveEndTransaction | 
                             s_i2cEndTransaction | 
                             s_gpioEndTransaction | 
                             s_crc32EndTransaction |
                             s_crc32DmaSlaveEndTransaction;

 assign s_addressData      = s_cpu1AddressData | 
                             s_biosAddressData | 
                             s_uartAddressData | 
                             s_perfAddressData | 
                             s_sdramAddressData | 
                             s_hdmiAddressData |
                             s_flashAddressData | 
                             s_camMasterAddressData | 
                             s_camSlaveAddressData | 
                             s_i2cAddressData | 
                             s_gpioAddressData | 
                             s_crc32AddressData |
                             s_crc32DmaSlaveAddressData | 
                             s_crc32DmaMasterAddressData;

 assign s_byteEnables      = s_cpu1byteEnables | 
                             s_hdmiByteEnables | 
                             s_camMasterByteEnables | 
                             s_crc32DmaMasterByteEnables;

 assign s_readNotWrite     = s_cpu1ReadNotWrite | 
                             s_hdmiReadNotWrite |
                             s_crc32DmaMasterReadNotWrite;

 assign s_dataValid        = s_cpu1DataValid | 
                             s_biosDataValid | 
                             s_uartDataValid | 
                             s_perfDataValid | 
                             s_sdramDataValid | 
                             s_hdmiDataValid |
                             s_flashDataValid | 
                             s_camMasterDataValid | 
                             s_camSlaveDataValid | 
                             s_i2cDataValid | 
                             s_gpioDataValid | 
                             s_crc32DataValid |
                             s_crc32DmaSlaveDataValid;

 assign s_busy             = s_sdramBusy;

 assign s_burstSize        = s_cpu1BurstSize | 
                             s_hdmiBurstSize | 
                             s_camMasterBurstSize |
                             s_crc32DmaMasterBurstSize;
 
endmodule
