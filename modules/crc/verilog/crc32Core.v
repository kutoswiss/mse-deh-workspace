module crc32Core
  (input  clock,
   input  reset,
   input  restart,
   input  dataValid,
   input  [31:0] dataIn,
   output [31:0] crcOut);
  wire [31:0] crcreg;
  wire [31:0] n2;
  wire n6;
  wire [7:0] n14;
  wire [7:0] n15;
  wire [7:0] n16;
  wire [23:0] n17;
  wire [31:0] n18;
  wire n19;
  wire [31:0] n20;
  wire [31:0] n22;
  wire [31:0] n24;
  wire [31:0] n25;
  wire [31:0] n27;
  wire [31:0] n28;
  wire n29;
  wire [31:0] n31;
  wire [31:0] n33;
  wire [31:0] n35;
  wire [31:0] n36;
  wire n37;
  wire [31:0] n39;
  wire [31:0] n41;
  wire [31:0] n43;
  wire [31:0] n44;
  wire n45;
  wire [31:0] n47;
  wire [31:0] n49;
  wire [31:0] n51;
  wire [31:0] n52;
  wire n53;
  wire [31:0] n55;
  wire [31:0] n57;
  wire [31:0] n59;
  wire [31:0] n60;
  wire n61;
  wire [31:0] n63;
  wire [31:0] n65;
  wire [31:0] n67;
  wire [31:0] n68;
  wire n69;
  wire [31:0] n71;
  wire [31:0] n73;
  wire [31:0] n75;
  wire [31:0] n76;
  wire n77;
  wire [31:0] n79;
  wire [31:0] n81;
  wire [31:0] n83;
  wire [31:0] n84;
  wire [7:0] n85;
  wire [7:0] n86;
  wire [7:0] n87;
  wire [23:0] n88;
  wire [31:0] n89;
  wire n90;
  wire [31:0] n91;
  wire [31:0] n93;
  wire [31:0] n95;
  wire [31:0] n96;
  wire [31:0] n98;
  wire [31:0] n99;
  wire n100;
  wire [31:0] n102;
  wire [31:0] n104;
  wire [31:0] n106;
  wire [31:0] n107;
  wire n108;
  wire [31:0] n110;
  wire [31:0] n112;
  wire [31:0] n114;
  wire [31:0] n115;
  wire n116;
  wire [31:0] n118;
  wire [31:0] n120;
  wire [31:0] n122;
  wire [31:0] n123;
  wire n124;
  wire [31:0] n126;
  wire [31:0] n128;
  wire [31:0] n130;
  wire [31:0] n131;
  wire n132;
  wire [31:0] n134;
  wire [31:0] n136;
  wire [31:0] n138;
  wire [31:0] n139;
  wire n140;
  wire [31:0] n142;
  wire [31:0] n144;
  wire [31:0] n146;
  wire [31:0] n147;
  wire n148;
  wire [31:0] n150;
  wire [31:0] n152;
  wire [31:0] n154;
  wire [31:0] n155;
  wire [7:0] n156;
  wire [7:0] n157;
  wire [7:0] n158;
  wire [23:0] n159;
  wire [31:0] n160;
  wire n161;
  wire [31:0] n162;
  wire [31:0] n164;
  wire [31:0] n166;
  wire [31:0] n167;
  wire [31:0] n169;
  wire [31:0] n170;
  wire n171;
  wire [31:0] n173;
  wire [31:0] n175;
  wire [31:0] n177;
  wire [31:0] n178;
  wire n179;
  wire [31:0] n181;
  wire [31:0] n183;
  wire [31:0] n185;
  wire [31:0] n186;
  wire n187;
  wire [31:0] n189;
  wire [31:0] n191;
  wire [31:0] n193;
  wire [31:0] n194;
  wire n195;
  wire [31:0] n197;
  wire [31:0] n199;
  wire [31:0] n201;
  wire [31:0] n202;
  wire n203;
  wire [31:0] n205;
  wire [31:0] n207;
  wire [31:0] n209;
  wire [31:0] n210;
  wire n211;
  wire [31:0] n213;
  wire [31:0] n215;
  wire [31:0] n217;
  wire [31:0] n218;
  wire n219;
  wire [31:0] n221;
  wire [31:0] n223;
  wire [31:0] n225;
  wire [31:0] n226;
  wire [7:0] n227;
  wire [7:0] n228;
  wire [7:0] n229;
  wire [23:0] n230;
  wire [31:0] n231;
  wire n232;
  wire [31:0] n233;
  wire [31:0] n235;
  wire [31:0] n237;
  wire [31:0] n238;
  wire [31:0] n240;
  wire [31:0] n241;
  wire n242;
  wire [31:0] n244;
  wire [31:0] n246;
  wire [31:0] n248;
  wire [31:0] n249;
  wire n250;
  wire [31:0] n252;
  wire [31:0] n254;
  wire [31:0] n256;
  wire [31:0] n257;
  wire n258;
  wire [31:0] n260;
  wire [31:0] n262;
  wire [31:0] n264;
  wire [31:0] n265;
  wire n266;
  wire [31:0] n268;
  wire [31:0] n270;
  wire [31:0] n272;
  wire [31:0] n273;
  wire n274;
  wire [31:0] n276;
  wire [31:0] n278;
  wire [31:0] n280;
  wire [31:0] n281;
  wire n282;
  wire [31:0] n284;
  wire [31:0] n286;
  wire [31:0] n288;
  wire [31:0] n289;
  wire n290;
  wire [31:0] n292;
  wire [31:0] n294;
  wire [31:0] n296;
  wire [31:0] n297;
  wire [31:0] n298;
  wire [31:0] n300;
  reg [31:0] n303;
  assign crcOut = n2; //(module output)
  /*# ../../modules/crc/vhdl/crc32Core.vhd:19:10 */
  assign crcreg = n303; // (signal)
  /*# ../../modules/crc/vhdl/crc32Core.vhd:43:37 */
  assign n2 = crcreg ^ 32'b11111111111111111111111111111111;
  /*# ../../modules/crc/vhdl/crc32Core.vhd:47:22 */
  assign n6 = reset | restart;
  /*# ../../modules/crc/vhdl/crc32Core.vhd:29:29 */
  assign n14 = crcreg[7:0]; // extract
  /*# ../../modules/crc/vhdl/crc32Core.vhd:30:38 */
  assign n15 = dataIn[7:0]; // extract
  /*# ../../modules/crc/vhdl/crc32Core.vhd:29:42 */
  assign n16 = n14 ^ n15;
  /*# ../../modules/crc/vhdl/crc32Core.vhd:24:14 */
  assign n17 = crcreg[31:8]; // extract
  /*# ../../modules/crc/vhdl/crc32Core.vhd:24:14 */
  assign n18 = {n17, n16};
  /*# ../../modules/crc/vhdl/crc32Core.vhd:32:15 */
  assign n19 = n18[0]; // extract
  /*# ../../modules/crc/vhdl/crc32Core.vhd:24:14 */
  assign n20 = {n17, n16};
  /*# ../../modules/crc/vhdl/crc32Core.vhd:33:18 */
  assign n22 = n20 >> 31'b0000000000000000000000000000001;
  /*# ../../modules/crc/vhdl/crc32Core.vhd:33:38 */
  assign n24 = n22 ^ 32'b11101101101110001000001100100000;
  /*# ../../modules/crc/vhdl/crc32Core.vhd:24:14 */
  assign n25 = {n17, n16};
  /*# ../../modules/crc/vhdl/crc32Core.vhd:35:18 */
  assign n27 = n25 >> 31'b0000000000000000000000000000001;
  /*# ../../modules/crc/vhdl/crc32Core.vhd:32:9 */
  assign n28 = n19 ? n24 : n27;
  /*# ../../modules/crc/vhdl/crc32Core.vhd:32:15 */
  assign n29 = n28[0]; // extract
  /*# ../../modules/crc/vhdl/crc32Core.vhd:33:18 */
  assign n31 = n28 >> 31'b0000000000000000000000000000001;
  /*# ../../modules/crc/vhdl/crc32Core.vhd:33:38 */
  assign n33 = n31 ^ 32'b11101101101110001000001100100000;
  /*# ../../modules/crc/vhdl/crc32Core.vhd:35:18 */
  assign n35 = n28 >> 31'b0000000000000000000000000000001;
  /*# ../../modules/crc/vhdl/crc32Core.vhd:32:9 */
  assign n36 = n29 ? n33 : n35;
  /*# ../../modules/crc/vhdl/crc32Core.vhd:32:15 */
  assign n37 = n36[0]; // extract
  /*# ../../modules/crc/vhdl/crc32Core.vhd:33:18 */
  assign n39 = n36 >> 31'b0000000000000000000000000000001;
  /*# ../../modules/crc/vhdl/crc32Core.vhd:33:38 */
  assign n41 = n39 ^ 32'b11101101101110001000001100100000;
  /*# ../../modules/crc/vhdl/crc32Core.vhd:35:18 */
  assign n43 = n36 >> 31'b0000000000000000000000000000001;
  /*# ../../modules/crc/vhdl/crc32Core.vhd:32:9 */
  assign n44 = n37 ? n41 : n43;
  /*# ../../modules/crc/vhdl/crc32Core.vhd:32:15 */
  assign n45 = n44[0]; // extract
  /*# ../../modules/crc/vhdl/crc32Core.vhd:33:18 */
  assign n47 = n44 >> 31'b0000000000000000000000000000001;
  /*# ../../modules/crc/vhdl/crc32Core.vhd:33:38 */
  assign n49 = n47 ^ 32'b11101101101110001000001100100000;
  /*# ../../modules/crc/vhdl/crc32Core.vhd:35:18 */
  assign n51 = n44 >> 31'b0000000000000000000000000000001;
  /*# ../../modules/crc/vhdl/crc32Core.vhd:32:9 */
  assign n52 = n45 ? n49 : n51;
  /*# ../../modules/crc/vhdl/crc32Core.vhd:32:15 */
  assign n53 = n52[0]; // extract
  /*# ../../modules/crc/vhdl/crc32Core.vhd:33:18 */
  assign n55 = n52 >> 31'b0000000000000000000000000000001;
  /*# ../../modules/crc/vhdl/crc32Core.vhd:33:38 */
  assign n57 = n55 ^ 32'b11101101101110001000001100100000;
  /*# ../../modules/crc/vhdl/crc32Core.vhd:35:18 */
  assign n59 = n52 >> 31'b0000000000000000000000000000001;
  /*# ../../modules/crc/vhdl/crc32Core.vhd:32:9 */
  assign n60 = n53 ? n57 : n59;
  /*# ../../modules/crc/vhdl/crc32Core.vhd:32:15 */
  assign n61 = n60[0]; // extract
  /*# ../../modules/crc/vhdl/crc32Core.vhd:33:18 */
  assign n63 = n60 >> 31'b0000000000000000000000000000001;
  /*# ../../modules/crc/vhdl/crc32Core.vhd:33:38 */
  assign n65 = n63 ^ 32'b11101101101110001000001100100000;
  /*# ../../modules/crc/vhdl/crc32Core.vhd:35:18 */
  assign n67 = n60 >> 31'b0000000000000000000000000000001;
  /*# ../../modules/crc/vhdl/crc32Core.vhd:32:9 */
  assign n68 = n61 ? n65 : n67;
  /*# ../../modules/crc/vhdl/crc32Core.vhd:32:15 */
  assign n69 = n68[0]; // extract
  /*# ../../modules/crc/vhdl/crc32Core.vhd:33:18 */
  assign n71 = n68 >> 31'b0000000000000000000000000000001;
  /*# ../../modules/crc/vhdl/crc32Core.vhd:33:38 */
  assign n73 = n71 ^ 32'b11101101101110001000001100100000;
  /*# ../../modules/crc/vhdl/crc32Core.vhd:35:18 */
  assign n75 = n68 >> 31'b0000000000000000000000000000001;
  /*# ../../modules/crc/vhdl/crc32Core.vhd:32:9 */
  assign n76 = n69 ? n73 : n75;
  /*# ../../modules/crc/vhdl/crc32Core.vhd:32:15 */
  assign n77 = n76[0]; // extract
  /*# ../../modules/crc/vhdl/crc32Core.vhd:33:18 */
  assign n79 = n76 >> 31'b0000000000000000000000000000001;
  /*# ../../modules/crc/vhdl/crc32Core.vhd:33:38 */
  assign n81 = n79 ^ 32'b11101101101110001000001100100000;
  /*# ../../modules/crc/vhdl/crc32Core.vhd:35:18 */
  assign n83 = n76 >> 31'b0000000000000000000000000000001;
  /*# ../../modules/crc/vhdl/crc32Core.vhd:32:9 */
  assign n84 = n77 ? n81 : n83;
  /*# ../../modules/crc/vhdl/crc32Core.vhd:29:29 */
  assign n85 = n84[7:0]; // extract
  /*# ../../modules/crc/vhdl/crc32Core.vhd:30:38 */
  assign n86 = dataIn[15:8]; // extract
  /*# ../../modules/crc/vhdl/crc32Core.vhd:29:42 */
  assign n87 = n85 ^ n86;
  /*# ../../modules/crc/vhdl/crc32Core.vhd:24:14 */
  assign n88 = n84[31:8]; // extract
  /*# ../../modules/crc/vhdl/crc32Core.vhd:24:14 */
  assign n89 = {n88, n87};
  /*# ../../modules/crc/vhdl/crc32Core.vhd:32:15 */
  assign n90 = n89[0]; // extract
  /*# ../../modules/crc/vhdl/crc32Core.vhd:24:14 */
  assign n91 = {n88, n87};
  /*# ../../modules/crc/vhdl/crc32Core.vhd:33:18 */
  assign n93 = n91 >> 31'b0000000000000000000000000000001;
  /*# ../../modules/crc/vhdl/crc32Core.vhd:33:38 */
  assign n95 = n93 ^ 32'b11101101101110001000001100100000;
  /*# ../../modules/crc/vhdl/crc32Core.vhd:24:14 */
  assign n96 = {n88, n87};
  /*# ../../modules/crc/vhdl/crc32Core.vhd:35:18 */
  assign n98 = n96 >> 31'b0000000000000000000000000000001;
  /*# ../../modules/crc/vhdl/crc32Core.vhd:32:9 */
  assign n99 = n90 ? n95 : n98;
  /*# ../../modules/crc/vhdl/crc32Core.vhd:32:15 */
  assign n100 = n99[0]; // extract
  /*# ../../modules/crc/vhdl/crc32Core.vhd:33:18 */
  assign n102 = n99 >> 31'b0000000000000000000000000000001;
  /*# ../../modules/crc/vhdl/crc32Core.vhd:33:38 */
  assign n104 = n102 ^ 32'b11101101101110001000001100100000;
  /*# ../../modules/crc/vhdl/crc32Core.vhd:35:18 */
  assign n106 = n99 >> 31'b0000000000000000000000000000001;
  /*# ../../modules/crc/vhdl/crc32Core.vhd:32:9 */
  assign n107 = n100 ? n104 : n106;
  /*# ../../modules/crc/vhdl/crc32Core.vhd:32:15 */
  assign n108 = n107[0]; // extract
  /*# ../../modules/crc/vhdl/crc32Core.vhd:33:18 */
  assign n110 = n107 >> 31'b0000000000000000000000000000001;
  /*# ../../modules/crc/vhdl/crc32Core.vhd:33:38 */
  assign n112 = n110 ^ 32'b11101101101110001000001100100000;
  /*# ../../modules/crc/vhdl/crc32Core.vhd:35:18 */
  assign n114 = n107 >> 31'b0000000000000000000000000000001;
  /*# ../../modules/crc/vhdl/crc32Core.vhd:32:9 */
  assign n115 = n108 ? n112 : n114;
  /*# ../../modules/crc/vhdl/crc32Core.vhd:32:15 */
  assign n116 = n115[0]; // extract
  /*# ../../modules/crc/vhdl/crc32Core.vhd:33:18 */
  assign n118 = n115 >> 31'b0000000000000000000000000000001;
  /*# ../../modules/crc/vhdl/crc32Core.vhd:33:38 */
  assign n120 = n118 ^ 32'b11101101101110001000001100100000;
  /*# ../../modules/crc/vhdl/crc32Core.vhd:35:18 */
  assign n122 = n115 >> 31'b0000000000000000000000000000001;
  /*# ../../modules/crc/vhdl/crc32Core.vhd:32:9 */
  assign n123 = n116 ? n120 : n122;
  /*# ../../modules/crc/vhdl/crc32Core.vhd:32:15 */
  assign n124 = n123[0]; // extract
  /*# ../../modules/crc/vhdl/crc32Core.vhd:33:18 */
  assign n126 = n123 >> 31'b0000000000000000000000000000001;
  /*# ../../modules/crc/vhdl/crc32Core.vhd:33:38 */
  assign n128 = n126 ^ 32'b11101101101110001000001100100000;
  /*# ../../modules/crc/vhdl/crc32Core.vhd:35:18 */
  assign n130 = n123 >> 31'b0000000000000000000000000000001;
  /*# ../../modules/crc/vhdl/crc32Core.vhd:32:9 */
  assign n131 = n124 ? n128 : n130;
  /*# ../../modules/crc/vhdl/crc32Core.vhd:32:15 */
  assign n132 = n131[0]; // extract
  /*# ../../modules/crc/vhdl/crc32Core.vhd:33:18 */
  assign n134 = n131 >> 31'b0000000000000000000000000000001;
  /*# ../../modules/crc/vhdl/crc32Core.vhd:33:38 */
  assign n136 = n134 ^ 32'b11101101101110001000001100100000;
  /*# ../../modules/crc/vhdl/crc32Core.vhd:35:18 */
  assign n138 = n131 >> 31'b0000000000000000000000000000001;
  /*# ../../modules/crc/vhdl/crc32Core.vhd:32:9 */
  assign n139 = n132 ? n136 : n138;
  /*# ../../modules/crc/vhdl/crc32Core.vhd:32:15 */
  assign n140 = n139[0]; // extract
  /*# ../../modules/crc/vhdl/crc32Core.vhd:33:18 */
  assign n142 = n139 >> 31'b0000000000000000000000000000001;
  /*# ../../modules/crc/vhdl/crc32Core.vhd:33:38 */
  assign n144 = n142 ^ 32'b11101101101110001000001100100000;
  /*# ../../modules/crc/vhdl/crc32Core.vhd:35:18 */
  assign n146 = n139 >> 31'b0000000000000000000000000000001;
  /*# ../../modules/crc/vhdl/crc32Core.vhd:32:9 */
  assign n147 = n140 ? n144 : n146;
  /*# ../../modules/crc/vhdl/crc32Core.vhd:32:15 */
  assign n148 = n147[0]; // extract
  /*# ../../modules/crc/vhdl/crc32Core.vhd:33:18 */
  assign n150 = n147 >> 31'b0000000000000000000000000000001;
  /*# ../../modules/crc/vhdl/crc32Core.vhd:33:38 */
  assign n152 = n150 ^ 32'b11101101101110001000001100100000;
  /*# ../../modules/crc/vhdl/crc32Core.vhd:35:18 */
  assign n154 = n147 >> 31'b0000000000000000000000000000001;
  /*# ../../modules/crc/vhdl/crc32Core.vhd:32:9 */
  assign n155 = n148 ? n152 : n154;
  /*# ../../modules/crc/vhdl/crc32Core.vhd:29:29 */
  assign n156 = n155[7:0]; // extract
  /*# ../../modules/crc/vhdl/crc32Core.vhd:30:38 */
  assign n157 = dataIn[23:16]; // extract
  /*# ../../modules/crc/vhdl/crc32Core.vhd:29:42 */
  assign n158 = n156 ^ n157;
  /*# ../../modules/crc/vhdl/crc32Core.vhd:24:14 */
  assign n159 = n155[31:8]; // extract
  /*# ../../modules/crc/vhdl/crc32Core.vhd:24:14 */
  assign n160 = {n159, n158};
  /*# ../../modules/crc/vhdl/crc32Core.vhd:32:15 */
  assign n161 = n160[0]; // extract
  /*# ../../modules/crc/vhdl/crc32Core.vhd:24:14 */
  assign n162 = {n159, n158};
  /*# ../../modules/crc/vhdl/crc32Core.vhd:33:18 */
  assign n164 = n162 >> 31'b0000000000000000000000000000001;
  /*# ../../modules/crc/vhdl/crc32Core.vhd:33:38 */
  assign n166 = n164 ^ 32'b11101101101110001000001100100000;
  /*# ../../modules/crc/vhdl/crc32Core.vhd:24:14 */
  assign n167 = {n159, n158};
  /*# ../../modules/crc/vhdl/crc32Core.vhd:35:18 */
  assign n169 = n167 >> 31'b0000000000000000000000000000001;
  /*# ../../modules/crc/vhdl/crc32Core.vhd:32:9 */
  assign n170 = n161 ? n166 : n169;
  /*# ../../modules/crc/vhdl/crc32Core.vhd:32:15 */
  assign n171 = n170[0]; // extract
  /*# ../../modules/crc/vhdl/crc32Core.vhd:33:18 */
  assign n173 = n170 >> 31'b0000000000000000000000000000001;
  /*# ../../modules/crc/vhdl/crc32Core.vhd:33:38 */
  assign n175 = n173 ^ 32'b11101101101110001000001100100000;
  /*# ../../modules/crc/vhdl/crc32Core.vhd:35:18 */
  assign n177 = n170 >> 31'b0000000000000000000000000000001;
  /*# ../../modules/crc/vhdl/crc32Core.vhd:32:9 */
  assign n178 = n171 ? n175 : n177;
  /*# ../../modules/crc/vhdl/crc32Core.vhd:32:15 */
  assign n179 = n178[0]; // extract
  /*# ../../modules/crc/vhdl/crc32Core.vhd:33:18 */
  assign n181 = n178 >> 31'b0000000000000000000000000000001;
  /*# ../../modules/crc/vhdl/crc32Core.vhd:33:38 */
  assign n183 = n181 ^ 32'b11101101101110001000001100100000;
  /*# ../../modules/crc/vhdl/crc32Core.vhd:35:18 */
  assign n185 = n178 >> 31'b0000000000000000000000000000001;
  /*# ../../modules/crc/vhdl/crc32Core.vhd:32:9 */
  assign n186 = n179 ? n183 : n185;
  /*# ../../modules/crc/vhdl/crc32Core.vhd:32:15 */
  assign n187 = n186[0]; // extract
  /*# ../../modules/crc/vhdl/crc32Core.vhd:33:18 */
  assign n189 = n186 >> 31'b0000000000000000000000000000001;
  /*# ../../modules/crc/vhdl/crc32Core.vhd:33:38 */
  assign n191 = n189 ^ 32'b11101101101110001000001100100000;
  /*# ../../modules/crc/vhdl/crc32Core.vhd:35:18 */
  assign n193 = n186 >> 31'b0000000000000000000000000000001;
  /*# ../../modules/crc/vhdl/crc32Core.vhd:32:9 */
  assign n194 = n187 ? n191 : n193;
  /*# ../../modules/crc/vhdl/crc32Core.vhd:32:15 */
  assign n195 = n194[0]; // extract
  /*# ../../modules/crc/vhdl/crc32Core.vhd:33:18 */
  assign n197 = n194 >> 31'b0000000000000000000000000000001;
  /*# ../../modules/crc/vhdl/crc32Core.vhd:33:38 */
  assign n199 = n197 ^ 32'b11101101101110001000001100100000;
  /*# ../../modules/crc/vhdl/crc32Core.vhd:35:18 */
  assign n201 = n194 >> 31'b0000000000000000000000000000001;
  /*# ../../modules/crc/vhdl/crc32Core.vhd:32:9 */
  assign n202 = n195 ? n199 : n201;
  /*# ../../modules/crc/vhdl/crc32Core.vhd:32:15 */
  assign n203 = n202[0]; // extract
  /*# ../../modules/crc/vhdl/crc32Core.vhd:33:18 */
  assign n205 = n202 >> 31'b0000000000000000000000000000001;
  /*# ../../modules/crc/vhdl/crc32Core.vhd:33:38 */
  assign n207 = n205 ^ 32'b11101101101110001000001100100000;
  /*# ../../modules/crc/vhdl/crc32Core.vhd:35:18 */
  assign n209 = n202 >> 31'b0000000000000000000000000000001;
  /*# ../../modules/crc/vhdl/crc32Core.vhd:32:9 */
  assign n210 = n203 ? n207 : n209;
  /*# ../../modules/crc/vhdl/crc32Core.vhd:32:15 */
  assign n211 = n210[0]; // extract
  /*# ../../modules/crc/vhdl/crc32Core.vhd:33:18 */
  assign n213 = n210 >> 31'b0000000000000000000000000000001;
  /*# ../../modules/crc/vhdl/crc32Core.vhd:33:38 */
  assign n215 = n213 ^ 32'b11101101101110001000001100100000;
  /*# ../../modules/crc/vhdl/crc32Core.vhd:35:18 */
  assign n217 = n210 >> 31'b0000000000000000000000000000001;
  /*# ../../modules/crc/vhdl/crc32Core.vhd:32:9 */
  assign n218 = n211 ? n215 : n217;
  /*# ../../modules/crc/vhdl/crc32Core.vhd:32:15 */
  assign n219 = n218[0]; // extract
  /*# ../../modules/crc/vhdl/crc32Core.vhd:33:18 */
  assign n221 = n218 >> 31'b0000000000000000000000000000001;
  /*# ../../modules/crc/vhdl/crc32Core.vhd:33:38 */
  assign n223 = n221 ^ 32'b11101101101110001000001100100000;
  /*# ../../modules/crc/vhdl/crc32Core.vhd:35:18 */
  assign n225 = n218 >> 31'b0000000000000000000000000000001;
  /*# ../../modules/crc/vhdl/crc32Core.vhd:32:9 */
  assign n226 = n219 ? n223 : n225;
  /*# ../../modules/crc/vhdl/crc32Core.vhd:29:29 */
  assign n227 = n226[7:0]; // extract
  /*# ../../modules/crc/vhdl/crc32Core.vhd:30:38 */
  assign n228 = dataIn[31:24]; // extract
  /*# ../../modules/crc/vhdl/crc32Core.vhd:29:42 */
  assign n229 = n227 ^ n228;
  /*# ../../modules/crc/vhdl/crc32Core.vhd:24:14 */
  assign n230 = n226[31:8]; // extract
  /*# ../../modules/crc/vhdl/crc32Core.vhd:24:14 */
  assign n231 = {n230, n229};
  /*# ../../modules/crc/vhdl/crc32Core.vhd:32:15 */
  assign n232 = n231[0]; // extract
  /*# ../../modules/crc/vhdl/crc32Core.vhd:24:14 */
  assign n233 = {n230, n229};
  /*# ../../modules/crc/vhdl/crc32Core.vhd:33:18 */
  assign n235 = n233 >> 31'b0000000000000000000000000000001;
  /*# ../../modules/crc/vhdl/crc32Core.vhd:33:38 */
  assign n237 = n235 ^ 32'b11101101101110001000001100100000;
  /*# ../../modules/crc/vhdl/crc32Core.vhd:24:14 */
  assign n238 = {n230, n229};
  /*# ../../modules/crc/vhdl/crc32Core.vhd:35:18 */
  assign n240 = n238 >> 31'b0000000000000000000000000000001;
  /*# ../../modules/crc/vhdl/crc32Core.vhd:32:9 */
  assign n241 = n232 ? n237 : n240;
  /*# ../../modules/crc/vhdl/crc32Core.vhd:32:15 */
  assign n242 = n241[0]; // extract
  /*# ../../modules/crc/vhdl/crc32Core.vhd:33:18 */
  assign n244 = n241 >> 31'b0000000000000000000000000000001;
  /*# ../../modules/crc/vhdl/crc32Core.vhd:33:38 */
  assign n246 = n244 ^ 32'b11101101101110001000001100100000;
  /*# ../../modules/crc/vhdl/crc32Core.vhd:35:18 */
  assign n248 = n241 >> 31'b0000000000000000000000000000001;
  /*# ../../modules/crc/vhdl/crc32Core.vhd:32:9 */
  assign n249 = n242 ? n246 : n248;
  /*# ../../modules/crc/vhdl/crc32Core.vhd:32:15 */
  assign n250 = n249[0]; // extract
  /*# ../../modules/crc/vhdl/crc32Core.vhd:33:18 */
  assign n252 = n249 >> 31'b0000000000000000000000000000001;
  /*# ../../modules/crc/vhdl/crc32Core.vhd:33:38 */
  assign n254 = n252 ^ 32'b11101101101110001000001100100000;
  /*# ../../modules/crc/vhdl/crc32Core.vhd:35:18 */
  assign n256 = n249 >> 31'b0000000000000000000000000000001;
  /*# ../../modules/crc/vhdl/crc32Core.vhd:32:9 */
  assign n257 = n250 ? n254 : n256;
  /*# ../../modules/crc/vhdl/crc32Core.vhd:32:15 */
  assign n258 = n257[0]; // extract
  /*# ../../modules/crc/vhdl/crc32Core.vhd:33:18 */
  assign n260 = n257 >> 31'b0000000000000000000000000000001;
  /*# ../../modules/crc/vhdl/crc32Core.vhd:33:38 */
  assign n262 = n260 ^ 32'b11101101101110001000001100100000;
  /*# ../../modules/crc/vhdl/crc32Core.vhd:35:18 */
  assign n264 = n257 >> 31'b0000000000000000000000000000001;
  /*# ../../modules/crc/vhdl/crc32Core.vhd:32:9 */
  assign n265 = n258 ? n262 : n264;
  /*# ../../modules/crc/vhdl/crc32Core.vhd:32:15 */
  assign n266 = n265[0]; // extract
  /*# ../../modules/crc/vhdl/crc32Core.vhd:33:18 */
  assign n268 = n265 >> 31'b0000000000000000000000000000001;
  /*# ../../modules/crc/vhdl/crc32Core.vhd:33:38 */
  assign n270 = n268 ^ 32'b11101101101110001000001100100000;
  /*# ../../modules/crc/vhdl/crc32Core.vhd:35:18 */
  assign n272 = n265 >> 31'b0000000000000000000000000000001;
  /*# ../../modules/crc/vhdl/crc32Core.vhd:32:9 */
  assign n273 = n266 ? n270 : n272;
  /*# ../../modules/crc/vhdl/crc32Core.vhd:32:15 */
  assign n274 = n273[0]; // extract
  /*# ../../modules/crc/vhdl/crc32Core.vhd:33:18 */
  assign n276 = n273 >> 31'b0000000000000000000000000000001;
  /*# ../../modules/crc/vhdl/crc32Core.vhd:33:38 */
  assign n278 = n276 ^ 32'b11101101101110001000001100100000;
  /*# ../../modules/crc/vhdl/crc32Core.vhd:35:18 */
  assign n280 = n273 >> 31'b0000000000000000000000000000001;
  /*# ../../modules/crc/vhdl/crc32Core.vhd:32:9 */
  assign n281 = n274 ? n278 : n280;
  /*# ../../modules/crc/vhdl/crc32Core.vhd:32:15 */
  assign n282 = n281[0]; // extract
  /*# ../../modules/crc/vhdl/crc32Core.vhd:33:18 */
  assign n284 = n281 >> 31'b0000000000000000000000000000001;
  /*# ../../modules/crc/vhdl/crc32Core.vhd:33:38 */
  assign n286 = n284 ^ 32'b11101101101110001000001100100000;
  /*# ../../modules/crc/vhdl/crc32Core.vhd:35:18 */
  assign n288 = n281 >> 31'b0000000000000000000000000000001;
  /*# ../../modules/crc/vhdl/crc32Core.vhd:32:9 */
  assign n289 = n282 ? n286 : n288;
  /*# ../../modules/crc/vhdl/crc32Core.vhd:32:15 */
  assign n290 = n289[0]; // extract
  /*# ../../modules/crc/vhdl/crc32Core.vhd:33:18 */
  assign n292 = n289 >> 31'b0000000000000000000000000000001;
  /*# ../../modules/crc/vhdl/crc32Core.vhd:33:38 */
  assign n294 = n292 ^ 32'b11101101101110001000001100100000;
  /*# ../../modules/crc/vhdl/crc32Core.vhd:35:18 */
  assign n296 = n289 >> 31'b0000000000000000000000000000001;
  /*# ../../modules/crc/vhdl/crc32Core.vhd:32:9 */
  assign n297 = n290 ? n294 : n296;
  /*# ../../modules/crc/vhdl/crc32Core.vhd:49:7 */
  assign n298 = dataValid ? n297 : crcreg;
  /*# ../../modules/crc/vhdl/crc32Core.vhd:47:7 */
  assign n300 = n6 ? 32'b11111111111111111111111111111111 : n298;
  /*# ../../modules/crc/vhdl/crc32Core.vhd:46:5 */
  always @(posedge clock)
    n303 <= n300;
endmodule

