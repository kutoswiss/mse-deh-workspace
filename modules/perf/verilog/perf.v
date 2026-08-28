module perf #(
    parameter [31:0] BASE_ADDRESS = 32'h50000120,
    parameter [31:0] CLOCK_FREQUENCY_HZ = 32'd74250000
)(
    input  wire        clock,
    input  wire        reset,
    input  wire        beginTransactionIn,
    input  wire        readNWriteIn,
    input  wire        dataValidIn,
    input  wire [31:0] addressDataIn,
    output reg         dataValidOut,
    output reg         endTransactionOut,
    output reg  [31:0] addressDataOut
);

    localparam [1:0] IDLE       = 2'd0;
    localparam [1:0] WAIT_WRITE = 2'd1;
    localparam [1:0] READ_END   = 2'd2;

    localparam [2:0] REG_CONTROL  = 3'd0;
    localparam [2:0] REG_STATUS   = 3'd1;
    localparam [2:0] REG_COUNTER  = 3'd2;
    localparam [2:0] REG_CAPTURE  = 3'd3;
    localparam [2:0] REG_CLOCK_HZ = 3'd4;

    localparam [31:0] CMD_START   = 32'h00000001;
    localparam [31:0] CMD_STOP    = 32'h00000002;
    localparam [31:0] CMD_CLEAR   = 32'h00000004;
    localparam [31:0] CMD_CAPTURE = 32'h00000008;

    reg [1:0]  stateReg;
    reg [2:0]  selectedRegisterReg;
    reg [31:0] counterReg;
    reg [31:0] captureReg;
    reg        runningReg;
    reg        overflowReg;

    wire addressHit = addressDataIn[31:5] == BASE_ADDRESS[31:5];

    always @(posedge clock) begin
        if (reset) begin
            stateReg            <= IDLE;
            selectedRegisterReg <= 3'd0;
            counterReg          <= 32'd0;
            captureReg          <= 32'd0;
            runningReg          <= 1'b0;
            overflowReg         <= 1'b0;
            dataValidOut        <= 1'b0;
            endTransactionOut   <= 1'b0;
            addressDataOut      <= 32'd0;
        end else begin
            dataValidOut      <= 1'b0;
            endTransactionOut <= 1'b0;
            addressDataOut    <= 32'd0;

            if (runningReg) begin
                if (counterReg == 32'hFFFFFFFF) begin
                    counterReg  <= 32'hFFFFFFFF;
                    overflowReg <= 1'b1;
                end else begin
                    counterReg <= counterReg + 32'd1;
                end
            end

            case (stateReg)
                IDLE: begin
                    if (beginTransactionIn && addressHit) begin
                        selectedRegisterReg <= addressDataIn[4:2];
                        if (readNWriteIn) begin
                            case (addressDataIn[4:2])
                                REG_CONTROL:  addressDataOut <= 32'd0;
                                REG_STATUS:   addressDataOut <= {30'd0, overflowReg, runningReg};
                                REG_COUNTER:  addressDataOut <= counterReg;
                                REG_CAPTURE:  addressDataOut <= captureReg;
                                REG_CLOCK_HZ: addressDataOut <= CLOCK_FREQUENCY_HZ;
                                default:      addressDataOut <= 32'd0;
                            endcase
                            dataValidOut <= 1'b1;
                            stateReg     <= READ_END;
                        end else begin
                            stateReg <= WAIT_WRITE;
                        end
                    end
                end

                WAIT_WRITE: begin
                    if (dataValidIn) begin
                        if (selectedRegisterReg == REG_CONTROL) begin
                            /* Priority: CLEAR, START, STOP, CAPTURE. */
                            if (addressDataIn & CMD_CLEAR) begin
                                counterReg  <= 32'd0;
                                captureReg  <= 32'd0;
                                runningReg  <= 1'b0;
                                overflowReg <= 1'b0;
                            end else if (addressDataIn & CMD_START) begin
                                counterReg  <= 32'd0;
                                captureReg  <= 32'd0;
                                runningReg  <= 1'b1;
                                overflowReg <= 1'b0;
                            end else if (addressDataIn & CMD_STOP) begin
                                captureReg <= counterReg;
                                runningReg <= 1'b0;
                            end else if (addressDataIn & CMD_CAPTURE) begin
                                captureReg <= counterReg;
                            end
                        end
                        stateReg <= IDLE;
                    end
                end

                READ_END: begin
                    endTransactionOut <= 1'b1;
                    stateReg          <= IDLE;
                end

                default: stateReg <= IDLE;
            endcase
        end
    end
endmodule
