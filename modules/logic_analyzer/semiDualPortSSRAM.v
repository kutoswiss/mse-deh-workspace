module semiDualPortSSRAM #(parameter bitwidth = 32,
                           parameter nrOfEntries = 512)
                          (input wire                             clockA,
                                                                  clockB,
                                                                  writeEnable,
                           input wire [$clog2(nrOfEntries)-1 : 0] addressA,
                                                                  addressB,
                           input wire [bitwidth-1 : 0]            dataIn,
                           output reg [bitwidth-1 : 0]            dataOutA,
                                                                  dataOutB);
reg [bitwidth-1 : 0] memoryContent [nrOfEntries-1 : 0];

always @(posedge clockA) begin
    dataOutA <= memoryContent[addressA];
    if (writeEnable == 1'b1) memoryContent[addressA] <= dataIn;
end

always @(posedge clockB)
    dataOutB <= memoryContent[addressB];
endmodule
