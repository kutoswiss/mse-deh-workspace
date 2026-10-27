module crc32Dma #(
    parameter [31:0] BASE_ADDRESS = 32'h50000160,
    parameter [31:0] LAST_ADDRESS = 32'h5000017F
)(
    input wire        clock,
    input wire        reset,

    // slave interface inputs
    input wire        slaveBeginTransactionIn,
    input wire        slaveReadNWriteIn,
    input wire        slaveDataValidIn,
    input wire [31:0] slaveAddressDataIn,

    // slave interface outputs
    output reg        slaveDataValidOut,
    output reg        slaveEndTransactionOut,
    output reg [31:0] slaveAddressDataOut,

    // dma master interface inputs
    input wire        masterBusGrant,
    input wire        masterDataValidIn,
    input wire        masterEndTransactionIn,
    input wire [31:0] masterAddressDataIn,

    // dma master interface outputs
    output reg        masterRequestBus,
    output reg        masterBeginTransactionOut,
    output reg        masterReadNWriteOut,
    output reg [3:0]  masterByteEnablesOut,
    output reg [31:0] masterAddressDataOut,
    output reg [7:0]  masterBurstSizeOut
);

// slave state machine definition 
localparam [1:0] SLAVE_IDLE        = 2'b00;
localparam [1:0] SLAVE_WAIT_WRITE  = 2'b01;
localparam [1:0] SLAVE_READ_END    = 2'b10;

// dma state machine definition 
localparam [2:0] DMA_IDLE          = 3'b000;
localparam [2:0] DMA_REQUEST_BUS   = 3'b001;
localparam [2:0] DMA_START_READ    = 3'b010;
localparam [2:0] DMA_WAIT_RESPONSE = 3'b011;
localparam [2:0] DMA_FINISH        = 3'b100;

// internal register address
localparam [2:0] REG_CONTROL     = 3'b000;
localparam [2:0] REG_SOURCE      = 3'b001;
localparam [2:0] REG_LENGTH      = 3'b010;
localparam [2:0] REG_STATUS      = 3'b011;
localparam [2:0] REG_CRC         = 3'b100;
localparam [2:0] REG_IRQ_CONTROL = 3'b101;

// registers
reg [31:0] sourceAddressReg;
reg [31:0] endAddressReg;
reg [31:0] currentAddressReg;
reg [31:0] lengthBytesReg;
reg [1:0]  irqControlReg;
reg        busyReg;
reg        doneReg;
reg        issueReadReg;

// registers
reg [2:0]  dmaStateReg;
reg [1:0]  slaveStateReg;
reg [2:0]  selectedReg;
reg        startCommandReg;

// crc32 core 
reg         crc32Restart;
reg         crc32DataValidIn;
reg  [31:0] crc32DataIn;
wire [31:0] crc32DataOut;

// crc32 core instance
crc32Core crc32 (
    .clock(clock),
    .reset(reset),
    .restart(crc32Restart),
    .dataValid(crc32DataValidIn),
    .dataIn(crc32DataIn),
    .crcOut(crc32DataOut)
);

// continiously verify address range
wire addressHit = (slaveAddressDataIn[31:5] >= BASE_ADDRESS[31:5]) && (slaveAddressDataIn[31:5] <= LAST_ADDRESS[31:5]);

// continiously return the status of the crc32 dma
wire [1:0] statusWire = {doneReg, busyReg};

// slave state machine
always @(posedge clock) begin
    if (reset) begin
        slaveStateReg          <= SLAVE_IDLE;
        selectedReg            <= REG_CONTROL;
        startCommandReg        <= 1'b0;
        sourceAddressReg       <= 32'd0;
        lengthBytesReg         <= 32'd0;
        irqControlReg          <= 2'd0;
        slaveDataValidOut      <= 1'b0;
        slaveEndTransactionOut <= 1'b0;
        slaveAddressDataOut    <= 32'd0;
    end else begin
        startCommandReg        <= 1'b0;
        slaveDataValidOut      <= 1'b0;
        slaveEndTransactionOut <= 1'b0;
        slaveAddressDataOut    <= 32'd0;

        case (slaveStateReg)
            SLAVE_IDLE: begin
                if (slaveBeginTransactionIn && addressHit) begin
                    selectedReg <= slaveAddressDataIn[4:2];
                    if (slaveReadNWriteIn) begin
                        // registers read
                        case (slaveAddressDataIn[4:2])
                            REG_SOURCE:      slaveAddressDataOut <= sourceAddressReg;
                            REG_LENGTH:      slaveAddressDataOut <= lengthBytesReg;
                            REG_STATUS:      slaveAddressDataOut <= statusWire;
                            REG_CRC:         slaveAddressDataOut <= crc32DataOut;
                            REG_IRQ_CONTROL: slaveAddressDataOut <= irqControlReg;
                            default:         slaveAddressDataOut <= 32'b0;
                        endcase
                        slaveDataValidOut <= 1'b1;
                        slaveStateReg <= SLAVE_READ_END;
                    end else begin
                        slaveStateReg <= SLAVE_WAIT_WRITE;
                    end
                end
            end

            SLAVE_WAIT_WRITE: begin
                if (slaveDataValidIn) begin
                    // registers write
                    case (selectedReg)
                        REG_CONTROL: startCommandReg  <= slaveAddressDataIn[0];
                        REG_SOURCE:  sourceAddressReg <= slaveAddressDataIn;
                        REG_LENGTH:  lengthBytesReg   <= slaveAddressDataIn;
                        default: ;
                    endcase
                    slaveStateReg <= SLAVE_IDLE;
                end
            end

            SLAVE_READ_END: begin
                slaveEndTransactionOut <= 1'b1;
                slaveStateReg <= SLAVE_IDLE;
            end

            default: slaveStateReg <= SLAVE_IDLE;
        endcase
    end
end

// dma master state machine
always @(posedge clock) begin
    if (reset) begin
        dmaStateReg <= DMA_IDLE;

        masterRequestBus <= 1'b0;
        masterBeginTransactionOut <= 1'b0;
        masterReadNWriteOut <= 1'b0;
        masterByteEnablesOut <= 4'b0;
        masterAddressDataOut <= 32'b0;
        masterBurstSizeOut <= 8'b0;

        crc32Restart <= 1'b0;
        crc32DataValidIn <= 1'b0;
        crc32DataIn <= 32'b0;

        currentAddressReg <= 32'd0;
        endAddressReg     <= 32'd0;
        busyReg           <= 1'b0;
        doneReg           <= 1'b0;
        issueReadReg      <= 1'b0;
    end else begin
        masterRequestBus <= 1'b0;
        masterBeginTransactionOut <= 1'b0;
        masterReadNWriteOut <= 1'b0;
        masterByteEnablesOut <= 4'b0;
        masterAddressDataOut <= 32'b0;
        masterBurstSizeOut <= 8'b0;

        crc32Restart <= 1'b0;
        crc32DataValidIn <= 1'b0;
        crc32DataIn <= 32'b0;

        issueReadReg      <= 1'b0;

        case (dmaStateReg) 
            DMA_IDLE: begin
                if (startCommandReg) begin
                    crc32Restart <= 1'b1;
                    currentAddressReg <= sourceAddressReg;
                    endAddressReg <= sourceAddressReg + lengthBytesReg;
                    busyReg <= 1'b1;
                    doneReg <= 1'b0;
                    dmaStateReg <= (lengthBytesReg == 32'd0) ? DMA_FINISH : DMA_REQUEST_BUS;
                end
            end

            DMA_REQUEST_BUS: begin
                masterRequestBus <= 1'b1;
                if (masterBusGrant) begin
                    masterRequestBus <= 1'b0;
                    dmaStateReg <= DMA_START_READ;
                end
            end

            DMA_START_READ: begin
                issueReadReg <= 1'b1;
                masterBeginTransactionOut <= 1'b1;
                masterReadNWriteOut <= 1'b1;
                masterAddressDataOut <= currentAddressReg;
                masterByteEnablesOut <= 4'hF;
                dmaStateReg <= DMA_WAIT_RESPONSE;
            end

            DMA_WAIT_RESPONSE: begin
                if (masterDataValidIn) begin
                    crc32DataIn <= masterAddressDataIn;
                    crc32DataValidIn <= 1'b1;
                end
                if (masterEndTransactionIn) begin
                    currentAddressReg <= currentAddressReg + 4;
                    dmaStateReg <= (currentAddressReg + 4 >= endAddressReg) ? DMA_FINISH : DMA_REQUEST_BUS;
                end
            end

            DMA_FINISH: begin
                busyReg <= 1'b0;
                doneReg <= 1'b1;
                dmaStateReg <= DMA_IDLE;
            end

            default: dmaStateReg <= DMA_IDLE;
        endcase
    end
end
endmodule