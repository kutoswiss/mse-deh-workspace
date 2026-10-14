module crc32Slave #(
    parameter [31:0] BASE_ADDRESS = 32'h50000140,
    parameter [31:0] LAST_ADDRESS = 32'h5000015F
)(
    // inputs
    input wire        clock,
    input wire        reset,
    input wire        beginTransactionIn,
    input wire        readNWriteIn,
    input wire        dataValidIn,
    input wire [31:0] addressDataIn,

    // outputs
    output reg        dataValidOut,
    output reg        endTransactionOut,
    output reg [31:0] addressDataOut
);

// internal state machine definition 
localparam [1:0] IDLE       = 2'd0;
localparam [1:0] WAIT_WRITE = 2'd1;
localparam [1:0] READ_END   = 2'd2;

// internal register addresses
localparam [2:0] REG_CONTROL    = 3'b000;
localparam [2:0] REG_DATA       = 3'b001;
localparam [2:0] REG_RESULT     = 3'b010;
localparam [2:0] REG_WORD_COUNT = 3'b011;

// registers
reg [1:0]  state;
reg [2:0]  selectedRegister;
reg [31:0] wordCount;

// crc32 core 
reg         crc32Restart;
reg         crc32DataValidIn;
reg [31:0]  crc32DataIn;
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
wire addressHit = (addressDataIn[31:5] >= BASE_ADDRESS[31:5]) && (addressDataIn[31:5] <= LAST_ADDRESS[31:5]);

// logic
always @(posedge clock) begin
    if (reset) begin
        state <= IDLE;
        selectedRegister <= REG_CONTROL;

        endTransactionOut <= 1'b0;
        addressDataOut <= 32'b0;
        dataValidOut <= 1'b0;

        crc32Restart <= 1'b0;
        crc32DataValidIn <= 1'b0;
        crc32DataIn <= 32'b0;

        wordCount <= 32'b0;
    end else begin
        endTransactionOut <= 1'b0;
        addressDataOut <= 32'b0;
        dataValidOut <= 1'b0;

        crc32Restart <= 1'b0;
        crc32DataValidIn <= 1'b0;
        crc32DataIn <= 32'b0;

        case (state)
            IDLE: begin
                if (beginTransactionIn && addressHit) begin 
                    selectedRegister <= addressDataIn[4:2];
                    if (readNWriteIn) begin
                        // registers read
                        case (addressDataIn[4:2])
                            REG_RESULT:     addressDataOut <= crc32DataOut;
                            REG_WORD_COUNT: addressDataOut <= wordCount;
                            default:        addressDataOut <= 32'b0;
                        endcase
                        dataValidOut <= 1'b1;
                        state <= READ_END;
                    end else begin
                        state <= WAIT_WRITE;
                    end
                end
            end

            WAIT_WRITE: begin
                if (dataValidIn) begin
                    // registers write
                    case (selectedRegister)
                        REG_CONTROL: begin
                            crc32Restart <= 1'b1;
                            wordCount    <= 32'b0;
                        end
                        REG_DATA: begin 
                            crc32DataIn      <= addressDataIn;
                            crc32DataValidIn <= 1'b1;
                            wordCount        <= wordCount + 32'b1;
                        end
                        default: ;
                    endcase
                    state <= IDLE;
                end
            end

            READ_END: begin 
                endTransactionOut <= 1'b1;
                state <= IDLE;
            end
        endcase
    end
end

endmodule