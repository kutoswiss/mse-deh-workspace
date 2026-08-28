// using the jtag interface, the user can communicate with this module
module lacAPI (
    input wire         i_done,               // if data capture is finished (from lac)
    input wire [8:0]   i_startAddress,       // first address to read from ring (from lac)
    input wire [31:0]  i_dataLow,            // from ssram
    input wire [31:0]  i_dataHigh,           // from ssram
    output wire        o_jtagClock,          // to ssram
    output wire [8:0]  o_address,            // to ssram
    output wire        o_reset,
    output wire [8:0]  o_postTriggerSamples,
    output wire [1:0]  o_seqLen,
    output wire [2:0]  o_comparator0,
                       o_comparator1,
                       o_comparator2,
                       o_comparator3,
    output wire [63:0] o_mask0,
                       o_mask1,
                       o_mask2,
                       o_mask3,
                       o_reference0,
                       o_reference1,
                       o_reference2,
                       o_reference3
    );


    // jtag interface ----------------------------------------------------------

    wire jtdi, jtck, jshift, jupdate, jrstn;
    // chain 1 signals
    wire jtdo1, jrti1, jce1;
    // unused chain 2 signals
    wire jtdo2, jrti2, jce2;

    // only used for simulation
    reg tck, tms, tdi;
    wire tdo;

    JTAGG JTAGG(
        // Can be uncommented if for simulation purposes (requires custom JTAGG module)
        // .TCK(tck),
        // .TMS(tms),
        // .TDI(tdi),
        // .TDO(tdo),

        .JTDO2(jtdo2),
        .JTDO1(jtdo1),
        .JTDI(jtdi),
        .JTCK(jtck),
        .JRTI2(jrti2),
        .JRTI1(jrti1),
        .JSHIFT(jshift),
        .JUPDATE(jupdate),
        .JRSTN(jrstn),
        .JCE2(jce2),
        .JCE1(jce1)
    );

    // Internal Signals
    assign jtdo1 = shiftReg[0];
    assign jtdo2 = shiftReg[0]; // make yosys happy (otherwise not used)


    // Chain 1 -----------------------------------------------------------------

    localparam [31:0] ERROR = 32'heeeeeeee;

    // states
    localparam [3:0] NOP =           4'b0000;
    localparam [3:0] INIT_FETCH =     4'b0001;
    localparam [3:0] FETCH_LOW =      4'b0010;
    localparam [3:0] FETCH_HIGH =     4'b0011;

    localparam [3:0] SELECT_TRIG =    4'b1000;
    localparam [3:0] SET_COMPARATOR = 4'b1001;
    localparam [3:0] SET_MASK =       4'b1010;
    localparam [3:0] SET_REFERENCE =  4'b1011;

    localparam [3:0] SET_TRIG_POS =   4'b1100;
    localparam [3:0] SET_SEQ_LEN =    4'b1101;

    localparam [3:0] DEBUG =          4'b1110;
    localparam [3:0] RESET =          4'b1111;


    reg [35:0] shiftReg;
    reg [3:0]  instrReg = 4'b0;
    reg [31:0] dataReg = 9;
    reg [31:0] outReg = 9;
    reg [8:0]  address = 9;
    reg [31:0] debugValue = 9;

    reg [3:0] state = NOP;
    reg next_mask_low = 0;
    reg next_ref_low = 0;

    // reg [8:0] counter = 0;

    // comparators
    localparam reg [2:0] ANY =       3'b000;
    localparam reg [2:0] EQ =        3'b001;
    localparam reg [2:0] LESS =      3'b010;
    localparam reg [2:0] LESSEQ =    3'b011;
    localparam reg [2:0] GREATER =   3'b100;
    localparam reg [2:0] GREATEREQ = 3'b101;

    // lac configuration
    reg [1:0] selectedTrig = 0;
    reg reset = 0;
    reg [8:0] postTriggerSamples = 9'b000000010;

    reg [1:0] seqLen = 3; // actual length is seqLen + 1
    reg [2:0] comparator0 = ANY;
    reg [2:0] comparator1 = ANY;
    reg [2:0] comparator2 = ANY;
    reg [2:0] comparator3 = ANY;
    reg [63:0] mask0 = 32'hffffffff;
    reg [63:0] mask1 = 32'hffffffff;
    reg [63:0] mask2 = 32'hffffffff;
    reg [63:0] mask3 = 32'hffffffff;
    reg [63:0] reference0 = 12;
    reg [63:0] reference1 = 11;
    reg [63:0] reference2 = 10;
    reg [63:0] reference3 = 9;

    always @(negedge jtck) begin

        // jtag implementation
        if (jrstn == 0) begin
            shiftReg <= 36'b0;
        end else begin
            if (jupdate) begin
                instrReg <= shiftReg[35:32]; // update instruction register
                dataReg <= shiftReg[31:0]; // update data register
            end else begin
                instrReg <= 4'b0;
            end
            if (jce1) begin
                if (jshift) begin
                    shiftReg <= {jtdi, shiftReg[35:1]}; // shift data in
                end
                else begin
                    shiftReg <= {4'b00000, outReg}; // capture out register
                    outReg <= 0;
                end
            end
        end

        state         <= instrReg;

        address       <= (state == INIT_FETCH) ? i_startAddress :
                         (state == FETCH_HIGH) ? (address + 1) : address;

        outReg        <= ((state == INIT_FETCH) && !jce1) ? {{31{1'b0}}, i_done} :
                         ((state == FETCH_LOW) && !jce1) ? i_dataLow :
                         ((state == FETCH_HIGH) && !jce1) ? i_dataHigh :
                         ((state == DEBUG) && !jce1) ? debugValue : outReg;

        // trigger control
        reset         <= (state == RESET) ? 1'b1 : 1'b0;

        next_mask_low <= (state == SELECT_TRIG) ? 1 :
                         (state == SET_MASK) ? 0 : next_mask_low;

        next_ref_low  <= (state == SELECT_TRIG) ? 1 :
                         (state == SET_REFERENCE) ? 0 : next_ref_low;


        // trigger config
        postTriggerSamples <= (state == SET_TRIG_POS) ? dataReg[8:0] : postTriggerSamples;

        selectedTrig  <= (state == SELECT_TRIG) ? dataReg : selectedTrig;

        seqLen       <= (state == SET_SEQ_LEN) ? dataReg : seqLen;

        if (state == SET_COMPARATOR) begin
            case (selectedTrig)
                0 : comparator0 <= dataReg[2:0];
                1 : comparator1 <= dataReg[2:0];
                2 : comparator2 <= dataReg[2:0];
                3 : comparator3 <= dataReg[2:0];
                default : outReg <= ERROR;
            endcase
        end

        if ((state == SET_MASK) && next_mask_low) begin
            case (selectedTrig)
                0 : mask0[31:0] <= dataReg;
                1 : mask1[31:0] <= dataReg;
                2 : mask2[31:0] <= dataReg;
                3 : mask3[31:0] <= dataReg;
                default : outReg <= ERROR;
            endcase
        end

        if ((state == SET_MASK) && !next_mask_low) begin
            case (selectedTrig)
                0 : mask0[63:32] <= dataReg;
                1 : mask1[63:32] <= dataReg;
                2 : mask2[63:32] <= dataReg;
                3 : mask3[63:32] <= dataReg;
                default : outReg <= ERROR;
            endcase
        end

        if ((state == SET_REFERENCE) && next_ref_low) begin
            case (selectedTrig)
                0 : reference0[31:0] <= dataReg;
                1 : reference1[31:0] <= dataReg;
                2 : reference2[31:0] <= dataReg;
                3 : reference3[31:0] <= dataReg;
                default : outReg <= ERROR;
            endcase
        end

        if ((state == SET_REFERENCE) && !next_ref_low) begin
            case (selectedTrig)
                0 : reference0[63:32] <= dataReg;
                1 : reference1[63:32] <= dataReg;
                2 : reference2[63:32] <= dataReg;
                3 : reference3[63:32] <= dataReg;
                default : outReg <= ERROR;
            endcase
        end

        // debug
        case (dataReg)
            0 : debugValue <= {{23{1'b0}}, i_startAddress};
            1 : debugValue <= {{23{1'b0}}, address};
            // 2 : debugValue <= {{23{1'b0}}, counter};
            3 : debugValue <= i_dataLow;
            4 : debugValue <= {{23{1'b0}}, postTriggerSamples};
            5 : debugValue <= dataReg;
            6 : debugValue <= {{31{1'b0}}, i_done};

            7 : debugValue <= {{30{1'b0}}, seqLen};

            16 : debugValue <= mask0[31:0];
            17 : debugValue <= mask0[63:32];
            18 : debugValue <= mask1[31:0];
            19 : debugValue <= mask1[63:32];
            20 : debugValue <= mask2[31:0];
            21 : debugValue <= mask2[63:32];
            22 : debugValue <= mask3[31:0];
            23 : debugValue <= mask3[63:32];

            32 : debugValue <= comparator0;
            33 : debugValue <= comparator1;
            34 : debugValue <= comparator2;
            35 : debugValue <= comparator3;

            48 : debugValue <= reference0[31:0];
            49 : debugValue <= reference0[63:32];
            50 : debugValue <= reference1[31:0];
            51 : debugValue <= reference1[63:32];
            52 : debugValue <= reference2[31:0];
            53 : debugValue <= reference2[63:32];
            54 : debugValue <= reference3[31:0];
            55 : debugValue <= reference3[63:32];

            default : debugValue <= ERROR;
        endcase

    end

    // Output signals ----------------------------------------------------------
    assign o_address = address;
    assign o_jtagClock = jtck;
    assign o_reset = reset;
    assign o_postTriggerSamples = postTriggerSamples;
    assign o_seqLen = seqLen;
    assign o_comparator0 = comparator0;
    assign o_comparator1 = comparator1;
    assign o_comparator2 = comparator2;
    assign o_comparator3 = comparator3;
    assign o_mask0 = mask0;
    assign o_mask1 = mask1;
    assign o_mask2 = mask2;
    assign o_mask3 = mask3;
    assign o_reference0 = reference0;
    assign o_reference1 = reference1;
    assign o_reference2 = reference2;
    assign o_reference3 = reference3;

endmodule
