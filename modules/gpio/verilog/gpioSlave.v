module gpioSlave #(
    parameter [31:0] BASE_ADDRESS = 32'h50000100,
    parameter [31:0] LAST_ADDRESS = 32'h5000011F,
    parameter INVERT_PINS         = 1'b0 
)(
    // inputs
    input wire clock,
    input wire reset,
    input wire beginTransactionIn,
    input wire readNWriteIn,
    input wire dataValidIn,
    input wire [31:0] addressDataIn,

    // outputs
    output reg dataValidOut,
    output reg endTransactionOut,
    output reg [31:0] addressDataOut,

    // inouts
    inout wire [31:0] gpioPins
);

// internal state machine definition 
localparam [1:0] IDLE       = 2'd0;
localparam [1:0] WAIT_WRITE = 2'd1;
localparam [1:0] READ_END   = 2'd2;

// internal register addresses
localparam [2:0] REG_DIR =  3'b000;
localparam [2:0] REG_PIN =  3'b001;
localparam [2:0] REG_PORT = 3'b010;
localparam [2:0] REG_SET =  3'b011;
localparam [2:0] REG_CLR =  3'b100;

// current state
reg [1:0] state;

// selected register
reg [2:0] selectedRegister;

// registers
reg [31:0] gpioDirReg;
reg [31:0] gpioPinReg;
reg [31:0] gpioPortReg;

// continiously verify address range
wire addressHit = (addressDataIn[31:5] >= BASE_ADDRESS[31:5]) && (addressDataIn[31:5] <= LAST_ADDRESS[31:5]);

// continiously assign gpio pins based on dir and port registers
genvar n;
generate
    for (n = 0; n < 32; n = n + 1) begin : pin_buffers 
        assign gpioPins[n] = (gpioDirReg[n] == 1'b0) ? 1'bz : INVERT_PINS ? ~gpioPortReg[n] : gpioPortReg[n];
    end
endgenerate

// logic
always @(posedge clock) begin
    if (reset) begin
        state <= IDLE;
        selectedRegister <= REG_DIR;
        gpioDirReg <= 32'd0;
        gpioPinReg <= 32'd0;
        gpioPortReg <= 32'd0;
        dataValidOut <= 1'b0;
        endTransactionOut <= 1'b0;
        addressDataOut <= 1'b0;
    end else begin
        dataValidOut <= 1'b0;
        endTransactionOut <= 1'b0;
        addressDataOut <= 1'b0;
        gpioPinReg <= (gpioPortReg ^ {32{INVERT_PINS}}) & gpioDirReg;

        case (state)
            IDLE: begin
                if (beginTransactionIn && addressHit) begin
                    selectedRegister <= addressDataIn[4:2];
                    if (readNWriteIn) begin
                        // registers read
                        case (addressDataIn[4:2])
                            REG_DIR:  addressDataOut <= gpioDirReg;
                            REG_PIN:  addressDataOut <= gpioPinReg;
                            REG_PORT: addressDataOut <= gpioPortReg;
                            default:  addressDataOut <= 32'd0;
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
                        REG_DIR:  gpioDirReg  <= addressDataIn;
                        REG_PORT: gpioPortReg <= addressDataIn;
                        REG_SET:  gpioPortReg <= gpioPortReg | addressDataIn;
                        REG_CLR:  gpioPortReg  <= gpioPortReg & ~addressDataIn;
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