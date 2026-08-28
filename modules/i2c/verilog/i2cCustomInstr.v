/*
 * Memory-mapped I2C controller wrapper.
 *
 * Register map (32-bit accesses):
 *   base + 0x00 : I2C slave address, bits [6:0]
 *   base + 0x04 : I2C register address, bits [7:0]
 *   base + 0x08 : TX/RX data, bits [7:0]
 *   base + 0x0C : CONTROL/STATUS
 *                 write bit 0 = start write (one-cycle command)
 *                 write bit 1 = start read  (one-cycle command)
 *                 read  bit 0 = busy
 *                 read  bit 1 = done (sticky until next command)
 *                 read  bit 2 = ACK error from last transaction
 *
 * The I2C engine itself is unchanged: this module only replaces the old
 * custom-instruction front end with the OR1420 shared-bus slave interface.
 */
module i2cBus #(
    parameter CLOCK_FREQUENCY = 12000000,
    parameter I2C_FREQUENCY   = 1000000,
    parameter [31:0] baseAddress = 32'h50000040
) (
    input  wire        clock,
    input  wire        reset,

    // OR1420 shared bus slave interface
    input  wire        beginTransactionIn,
    input  wire        endTransactionIn,
    input  wire        readNotWriteIn,
    input  wire        dataValidIn,
    input  wire        busyIn,
    input  wire [31:0] addressDataIn,
    input  wire [3:0]  byteEnablesIn,
    input  wire [7:0]  burstSizeIn,
    output wire [31:0] addressDataOut,
    output reg         endTransactionOut,
    output wire        dataValidOut,
    output reg         busErrorOut,

    output wire        SCL,
    inout  wire        SDA
);

    localparam [1:0] RD_IDLE = 2'd0;
    localparam [1:0] RD_WAIT = 2'd1;
    localparam [1:0] RD_END  = 2'd2;

    // Bus transaction capture, following the existing uartBus convention.
    reg        s_startTransactionReg;
    reg        s_transactionActiveReg;
    reg        s_readNotWriteReg;
    reg [3:0]  s_byteEnablesReg;
    reg [7:0]  s_burstSizeReg;
    reg [31:0] s_busAddressReg;
    reg [31:0] s_dataInReg;
    reg        s_dataInValidReg;

    reg [1:0]  s_readStateReg, s_readStateNext;
    reg [31:0] s_dataOutReg;
    reg        s_dataOutValidReg;

    // Four 32-bit registers occupy 16 bytes.
    wire s_isMyTransaction = s_transactionActiveReg &&
                             (s_busAddressReg[31:4] == baseAddress[31:4]);

    // This peripheral supports only single 32-bit transfers.
    wire s_isBusError = s_isMyTransaction &&
                        ((s_burstSizeReg != 8'd0) ||
                         (!s_readNotWriteReg && (s_byteEnablesReg != 4'b1111)));

    wire s_startReadResponse = (s_readStateReg == RD_IDLE) &&
                               s_startTransactionReg &&
                               s_isMyTransaction &&
                               s_readNotWriteReg &&
                               !s_isBusError;

    wire s_resetReadResponse = reset ||
                               ((s_readStateReg == RD_WAIT) && !busyIn);

    assign addressDataOut = s_dataOutReg;
    assign dataValidOut   = s_dataOutValidReg;

    // MMIO-visible configuration registers.
    reg [6:0] s_i2cAddressReg;
    reg [7:0] s_i2cRegisterReg;
    reg [7:0] s_i2cDataReg;

    // I2C transaction/status state.
    reg  s_startWriteReg;
    reg  s_startReadReg;
    reg  s_oldBusyReg;
    reg  s_doneReg;
    reg  s_ackErrorReg;

    wire       s_i2cBusy;
    wire       s_i2cAckError;
    wire [7:0] s_i2cDataOut;

    wire s_writeRegister = s_dataInValidReg && !s_isBusError;

    // A new command clears DONE; completion makes DONE sticky.
    wire s_i2cFinished = s_oldBusyReg && !s_i2cBusy;

    // OR1420 is big-endian at the C level while the shared bus presents
    // the least-significant software byte on addressDataIn[31:24].
    // Put byte-sized MMIO registers/status in the upper byte so a normal
    // uint32_t load in C reads back the expected value.
    wire [31:0] s_readValue =
        (s_busAddressReg[3:2] == 2'd0) ? {1'b0, s_i2cAddressReg, 24'd0} :
        (s_busAddressReg[3:2] == 2'd1) ? {s_i2cRegisterReg, 24'd0} :
        (s_busAddressReg[3:2] == 2'd2) ? {s_i2cDataReg, 24'd0} :
                                        {5'd0, s_ackErrorReg, s_doneReg, s_i2cBusy, 24'd0};

    always @(posedge clock) begin
        if (reset) begin
            s_startTransactionReg  <= 1'b0;
            s_transactionActiveReg <= 1'b0;
            s_readNotWriteReg      <= 1'b0;
            s_byteEnablesReg       <= 4'd0;
            s_burstSizeReg         <= 8'd0;
            s_busAddressReg        <= 32'd0;
            s_dataInReg            <= 32'd0;
            s_dataInValidReg       <= 1'b0;
            s_dataOutReg           <= 32'd0;
            s_dataOutValidReg      <= 1'b0;
            s_readStateReg         <= RD_IDLE;
            endTransactionOut      <= 1'b0;
            busErrorOut            <= 1'b0;
        end else begin
            s_startTransactionReg <= beginTransactionIn;

            if (endTransactionIn)
                s_transactionActiveReg <= 1'b0;
            else if (beginTransactionIn)
                s_transactionActiveReg <= 1'b1;

            if (beginTransactionIn) begin
                s_readNotWriteReg <= readNotWriteIn;
                s_byteEnablesReg  <= byteEnablesIn;
                s_burstSizeReg    <= burstSizeIn;
                s_busAddressReg   <= addressDataIn;
            end

            if (dataValidIn)
                s_dataInReg <= addressDataIn;

            s_dataInValidReg <= dataValidIn && s_isMyTransaction &&
                                !s_isBusError && !s_readNotWriteReg;

            if (s_resetReadResponse) begin
                s_dataOutReg      <= 32'd0;
                s_dataOutValidReg <= 1'b0;
            end else if (s_startReadResponse) begin
                s_dataOutReg      <= s_readValue;
                s_dataOutValidReg <= 1'b1;
            end

            s_readStateReg    <= s_readStateNext;
            endTransactionOut <= (s_readStateReg == RD_END);
            busErrorOut       <= endTransactionIn ? 1'b0 : s_isBusError;
        end
    end

    always @* begin
        case (s_readStateReg)
            RD_IDLE: s_readStateNext = s_startReadResponse ? RD_WAIT : RD_IDLE;
            RD_WAIT: s_readStateNext = busyIn ? RD_WAIT : RD_END;
            default: s_readStateNext = RD_IDLE;
        endcase
    end

    // Register writes and I2C command generation.
    always @(posedge clock) begin
        if (reset) begin
            s_i2cAddressReg  <= 7'd0;
            s_i2cRegisterReg <= 8'd0;
            s_i2cDataReg     <= 8'd0;
            s_startWriteReg  <= 1'b0;
            s_startReadReg   <= 1'b0;
            s_oldBusyReg     <= 1'b0;
            s_doneReg        <= 1'b0;
            s_ackErrorReg    <= 1'b0;
        end else begin
            // command strobes are one clock wide
            s_startWriteReg <= 1'b0;
            s_startReadReg  <= 1'b0;
            s_oldBusyReg    <= s_i2cBusy;

            if (s_i2cFinished) begin
                s_doneReg     <= 1'b1;
                s_ackErrorReg <= s_i2cAckError;
                s_i2cDataReg  <= s_i2cDataOut;
            end

            if (s_writeRegister) begin
                case (s_busAddressReg[3:2])
                    // The software-visible low byte is on bus bits [31:24].
                    2'd0: s_i2cAddressReg  <= s_dataInReg[30:24];
                    2'd1: s_i2cRegisterReg <= s_dataInReg[31:24];
                    2'd2: s_i2cDataReg     <= s_dataInReg[31:24];
                    2'd3: begin
                        // CONTROL software bits 0/1 appear on bus bits 24/25.
                        // Ignore start requests while the master is already busy.
                        if (!s_i2cBusy) begin
                            if (s_dataInReg[24]) begin
                                s_startWriteReg <= 1'b1;
                                s_doneReg       <= 1'b0;
                                s_ackErrorReg   <= 1'b0;
                            end else if (s_dataInReg[25]) begin
                                s_startReadReg <= 1'b1;
                                s_doneReg      <= 1'b0;
                                s_ackErrorReg  <= 1'b0;
                            end
                        end
                    end
                endcase
            end
        end
    end

    // Existing I2C engine remains unchanged.
    i2cMaster #(
        .CLOCK_FREQUENCY(CLOCK_FREQUENCY),
        .I2C_FREQUENCY(I2C_FREQUENCY)
    ) master (
        .clock(clock),
        .reset(reset),
        .startWrite(s_startWriteReg),
        .startRead(s_startReadReg),
        .address(s_i2cAddressReg),
        .regIn(s_i2cRegisterReg),
        .dataIn(s_i2cDataReg),
        .dataOut(s_i2cDataOut),
        .ackError(s_i2cAckError),
        .busy(s_i2cBusy),
        .SCL(SCL),
        .SDA(SDA)
    );

endmodule
