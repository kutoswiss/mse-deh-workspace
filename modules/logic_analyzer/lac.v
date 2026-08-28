module lac #(parameter sampleBitwidth = 64)
    (input wire                      i_clock,
     input wire [sampleBitwidth-1:0] i_tappedWires);

    // comparators
    localparam reg [2:0] ANY =       3'b000;
    localparam reg [2:0] EQ =        3'b001;
    localparam reg [2:0] LESS =      3'b010;
    localparam reg [2:0] LESSEQ =    3'b011;
    localparam reg [2:0] GREATER =   3'b100;
    localparam reg [2:0] GREATEREQ = 3'b101;

    reg enabled = 0;
    reg [8:0] reset_counter = 9'h1ff;

    // lac configuration (signals from lacAPI)
    wire api_reset;
    wire synchro_reset;
    wire [8:0] api_postTriggerSamples;
    wire [8:0] api_address;
    wire [1:0] api_seqLen;
    wire [2:0] api_comparator0;
    wire [2:0] api_comparator1;
    wire [2:0] api_comparator2;
    wire [2:0] api_comparator3;
    wire [63:0] api_mask0;
    wire [63:0] api_mask1;
    wire [63:0] api_mask2;
    wire [63:0] api_mask3;
    wire [63:0] api_reference0;
    wire [63:0] api_reference1;
    wire [63:0] api_reference2;
    wire [63:0] api_reference3;

    reg [9:0]                trig_shift;
    reg                      triggered = 1'b0;
    reg [8:0]                counter = 9'b0;
    reg [8:0]                startAddress = 0;
    reg [8:0]                ringAddress = 0;
    reg                      done = 0;
    reg [sampleBitwidth-1:0] nextTappedWires;
    reg [sampleBitwidth-1:0] nextTappedWiresDelayed; // because the trigger adds a delay

    wire        jtagClock;
    wire [31:0] dummyOutA;
    wire [31:0] dataHigh;
    wire [31:0] dataLow;

    always @(posedge i_clock) begin
        ringAddress <= ringAddress + 1;

        if (enabled) begin
            enabled <= ~synchro_reset;
            reset_counter <= 9'hff;

            nextTappedWires  <= i_tappedWires;
            nextTappedWiresDelayed  <= nextTappedWires;

            if (i_tappedWires != nextTappedWires) begin
                // only update trigger state if tapped value changes
                case (api_comparator0)
                    ANY :       trig_shift[0] <= 1;
                    EQ :        trig_shift[0] <= ((i_tappedWires & api_mask0) == api_reference0) ? 1 : 0;
                    LESS :      trig_shift[0] <= ((i_tappedWires & api_mask0) < api_reference0) ? 1 : 0;
                    LESSEQ :    trig_shift[0] <= ((i_tappedWires & api_mask0) <= api_reference0) ? 1 : 0;
                    GREATER :   trig_shift[0] <= ((i_tappedWires & api_mask0) > api_reference0) ? 1 : 0;
                    GREATEREQ : trig_shift[0] <= ((i_tappedWires & api_mask0) >= api_reference0) ? 1 : 0;
                    default :   trig_shift[0] <= 0;
                endcase
                case (api_comparator1)
                    ANY :       trig_shift[2] <= 1;
                    EQ :        trig_shift[2] <= ((i_tappedWires & api_mask1) == api_reference1) ? 1 : 0;
                    LESS :      trig_shift[2] <= ((i_tappedWires & api_mask1) < api_reference1) ? 1 : 0;
                    LESSEQ :    trig_shift[2] <= ((i_tappedWires & api_mask1) <= api_reference1) ? 1 : 0;
                    GREATER :   trig_shift[2] <= ((i_tappedWires & api_mask1) > api_reference1) ? 1 : 0;
                    GREATEREQ : trig_shift[2] <= ((i_tappedWires & api_mask1) >= api_reference1) ? 1 : 0;
                    default :   trig_shift[2] <= 0;
                endcase
                case (api_comparator2)
                    ANY :       trig_shift[5] <= 1;
                    EQ :        trig_shift[5] <= ((i_tappedWires & api_mask2) == api_reference2) ? 1 : 0;
                    LESS :      trig_shift[5] <= ((i_tappedWires & api_mask2) < api_reference2) ? 1 : 0;
                    LESSEQ :    trig_shift[5] <= ((i_tappedWires & api_mask2) <= api_reference2) ? 1 : 0;
                    GREATER :   trig_shift[5] <= ((i_tappedWires & api_mask2) > api_reference2) ? 1 : 0;
                    GREATEREQ : trig_shift[5] <= ((i_tappedWires & api_mask2) >= api_reference2) ? 1 : 0;
                    default :   trig_shift[5] <= 0;
                endcase
                case (api_comparator3)
                    ANY :       trig_shift[9] <= 1;
                    EQ :        trig_shift[9] <= ((i_tappedWires & api_mask3) == api_reference3) ? 1 : 0;
                    LESS :      trig_shift[9] <= ((i_tappedWires & api_mask3) < api_reference3) ? 1 : 0;
                    LESSEQ :    trig_shift[9] <= ((i_tappedWires & api_mask3) <= api_reference3) ? 1 : 0;
                    GREATER :   trig_shift[9] <= ((i_tappedWires & api_mask3) > api_reference3) ? 1 : 0;
                    GREATEREQ : trig_shift[9] <= ((i_tappedWires & api_mask3) >= api_reference3) ? 1 : 0;
                    default :   trig_shift[9] <= 0;
                endcase
                trig_shift[1] <= trig_shift[0];
                trig_shift[3] <= trig_shift[1];
                trig_shift[4] <= trig_shift[2];
                trig_shift[6] <= trig_shift[3];
                trig_shift[7] <= trig_shift[4];
                trig_shift[8] <= trig_shift[5];
            end

            case (api_seqLen)
                0 : triggered <= (trig_shift[0] == 1'b1) ? 1'b1 : triggered;
                1 : triggered <= (trig_shift[2:1] == 2'b11) ? 1'b1 : triggered;
                2 : triggered <= (trig_shift[5:3] == 3'b111) ? 1'b1 : triggered;
                3 : triggered <= (trig_shift[9:6] == 4'b1111) ? 1'b1 : triggered;
                default : triggered <= triggered;
            endcase

            counter <= triggered ? counter - 1 : counter;
            // done <= (~done & triggered & (counter == 0)) ? 1'b1 : done;
            done <= ~done ? (triggered & (counter == 0)) : done;
            startAddress <= done ? startAddress : startAddress + 1;
        end else begin

            // use 512 cycles to wipe the whole sram
            reset_counter <= reset_counter - 1;
            enabled <= reset_counter == 0;

            nextTappedWiresDelayed <= 0;
            done <= 0;
            trig_shift <= 0;
            startAddress <= ringAddress + 1;
            counter <= api_postTriggerSamples;
            triggered <= 0;

        end
    end

    semiDualPortSSRAM ssramLow(
        .clockA(i_clock),
        .clockB(jtagClock),
        .writeEnable(~done),
        .addressA(ringAddress),
        .addressB(api_address),
        .dataIn(nextTappedWiresDelayed[31:0]),
        .dataOutA(dummyOutA),
        .dataOutB(dataLow));

    semiDualPortSSRAM ssramHigh(
        .clockA(i_clock),
        .clockB(jtagClock),
        .writeEnable(~done),
        .addressA(ringAddress),
        .addressB(api_address),
        .dataIn(nextTappedWiresDelayed[63:32]),
        .dataOutA(dummyOutA),
        .dataOutB(dataHigh));

    lacAPI lacAPI(
        .i_done(done),
        .i_startAddress(startAddress),
        .i_dataLow(dataLow),
        .i_dataHigh(dataHigh),
        .o_jtagClock(jtagClock),
        .o_reset(api_reset),
        .o_postTriggerSamples(api_postTriggerSamples),
        .o_address(api_address),
        .o_seqLen(api_seqLen),
        .o_comparator0(api_comparator0),
        .o_comparator1(api_comparator1),
        .o_comparator2(api_comparator2),
        .o_comparator3(api_comparator3),
        .o_mask0(api_mask0),
        .o_mask1(api_mask1),
        .o_mask2(api_mask2),
        .o_mask3(api_mask3),
        .o_reference0(api_reference0),
        .o_reference1(api_reference1),
        .o_reference2(api_reference2),
        .o_reference3(api_reference3)
        );

    synchroFlop synchroFlopReset(
        .clockIn(jtagClock),
        .clockOut(i_clock),
        .reset(1'b0),
        .D(api_reset),
        .Q(synchro_reset)
    );

endmodule
