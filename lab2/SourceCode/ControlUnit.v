`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////
// Company: USTC ESLAB 
// Engineer: Wu Yuzhang
// 
// Design Name: RISCV-Pipline CPU
// Module Name: ControlUnit
// Target Devices: Nexys4
// Tool Versions: Vivado 2017.4.1
// Description: RISC-V Instruction Decoder
//////////////////////////////////////////////////////////////////////////////////
//功能和接口说�?
    //ControlUnit       是本CPU的指令译码器，组合�?�辑电路
//输入
    // Op               是指令的操作码部�?
    // Fn3              是指令的func3部分
    // Fn7              是指令的func7部分
//输出
    // JalD==1          表示Jal指令到达ID译码阶段
    // JalrD==1         表示Jalr指令到达ID译码阶段
    // RegWriteD        表示ID阶段的指令对应的寄存器写入模�?
    // MemToRegD==1     表示ID阶段的指令需要将data memory读取的�?�写入寄存器,
    // MemWriteD        �?4bit，采用独热码格式，对于data memory�?32bit字按byte进行写入,MemWriteD=0001表示只写入最�?1个byte，和xilinx bram的接口类�?
    // LoadNpcD==1      表示将NextPC输出到ResultM
    // RegReadD         表示A1和A2对应的寄存器值是否被使用到了，用于forward的处�?
    // RegReadD[0] ~ RS1，RegReadD[1] ~ RS2
    // BranchTypeD      表示不同的分支类型，�?有类型定义在Parameters.v�?
    // AluContrlD       表示不同的ALU计算功能，所有类型定义在Parameters.v�?
    // AluSrc2D         表示Alu输入�?2的�?�择
    // AluSrc1D         表示Alu输入�?1的�?�择
    // ImmType          表示指令的立即数格式
//实验要求  
    //补全模块  

`include "Parameters.v"

// OpCode
    `define OP_IMM      7'b0010011  //  SLLI/SRLI/SRAI
    `define OP_REG      7'b0110011  //  ADD/SUB...
    `define OP_REGI     7'b0010011  //  ADDI/SLTI...
    `define OP_LUI      7'b0110111  //  LUI
    `define OP_AUI      7'b0010111  //  AUIPC
    `define OP_JALR     7'b1100111  //  JalR
    `define OP_JAL      7'b1101111  //  Jal             
    `define OP_BR       7'b1100011  //  条件分支
    `define OP_LOAD     7'b0000011  //  Load
    `define OP_STORE    7'b0100011  //  Store
    `define OP_SYS      0           //  CSR相关指令
// Funtc 3 ALU
    `define F3_ADD      3'b000
    `define F3_SLL      3'b001
    `define F3_SLT      3'b010
    `define F3_SLTU     3'b011
    `define F3_XOR      3'b100
    `define F3_SRLA     3'b101
    `define F3_OR       3'b110
    `define F3_AND      3'b111
// Funct 3 Branch
    `define F3_BEQ      3'b000
    `define F3_BNE      3'b001
    `define F3_BLT      3'b100
    `define F3_BGE      3'b101
    `define F3_BLTU     3'b110
    `define F3_BGEU     3'b111
// Funct 3 Load
    `define F3_LB       3'b000
    `define F3_LH       3'b001
    `define F3_LW       3'b010
    `define F3_LBU      3'b100
    `define F3_LHU      3'b101
// Funct 3 Store
    `define F3_SB       3'b000
    `define F3_SH       3'b001
    `define F3_SW       3'b010
// ALUSrc1，坑，和图片上的不一样、、
    `define SRC1_PCE    1'b1
    `define SRC1_FD1    1'b0
// ALUSrc2
    `define SRC2_IMM    2'b10
    `define SRC2_RS2    2'b01
    `define SRC2_FD2    2'b00

module ControlUnit(
    input wire [6:0] Op,
    input wire [2:0] Fn3,
    input wire [6:0] Fn7,
    output reg JalD,
    output reg JalrD,
    output reg [2:0] RegWriteD,
    output reg MemToRegD,
    output reg [3:0] MemWriteD,
    output reg LoadNpcD,
    output reg [1:0] RegReadD,
    output reg [2:0] BranchTypeD,
    output reg [3:0] AluContrlD,
    output reg [1:0] AluSrc2D,
    output reg AluSrc1D,
    output reg [2:0] ImmType        
    ); 
    
    always @(*) begin
        case (Op)
            `OP_IMM: begin
                // 坑 ，LI也在这里但是文档没写、、、
                RegWriteD <= `LW;
                ImmType <= `ITYPE;
                JalD = 0;
                JalrD <= 0;
                MemToRegD <= 0;
                LoadNpcD <= 0;
                RegReadD <= 2'b01;
                BranchTypeD <= `NOBRANCH;
                AluSrc1D <= `SRC1_FD1;
                AluSrc2D <= `SRC2_IMM;
                MemWriteD <= 4'b0;
                if (Fn3 == 3'b001 && Fn7 == 7'b0000000) begin
                    AluContrlD <= `SLL;
                end else if(Fn3 == 3'b101 && Fn7 == 7'b0000000) begin
                    AluContrlD <= `SRL;
                end else if(Fn3 == 3'b101 && Fn7 == 7'b0100000) begin
                    AluContrlD <= `SRA;
                end else begin
                    AluContrlD <= `LUI;
                end
            end

            `OP_REG: begin
                // 通用赋�??
                RegWriteD <= `LW;
                ImmType <= `ITYPE;
                JalD <= 0;
                JalrD <= 0;
                MemToRegD <= 0;
                LoadNpcD <= 0;
                RegReadD <= 2'b11;
                BranchTypeD <= `NOBRANCH;
                AluSrc1D <= `SRC1_FD1;
                AluSrc2D <= `SRC2_FD2;
                MemWriteD <= 4'b0;
                // Funct 特异
                case (Fn3)
                    `F3_ADD: AluContrlD <= (Fn7 == 7'b0100000) ? `SUB : `ADD;
                    `F3_SLL: AluContrlD <= `SLL;
                    `F3_SLT: AluContrlD <= `SLT;
                    `F3_SLTU: AluContrlD <= `SLTU;
                    `F3_XOR: AluContrlD <= `XOR;
                    `F3_SRLA: AluContrlD <= (Fn7 == 7'b0100000) ? `SRA : `SRL;
                    `F3_OR:  AluContrlD <= `OR;
                    `F3_AND: AluContrlD <= `AND;
                    default: AluContrlD <= 0;
                endcase
            end

            `OP_REGI: begin
                // 通用赋�??
                RegWriteD <= `LW;
                ImmType <= `ITYPE;
                JalD <= 0;
                JalrD <= 0;
                MemToRegD <= 0;
                LoadNpcD <= 0;
                RegReadD <= 2'b01;
                BranchTypeD <= `NOBRANCH;
                AluSrc1D <= `SRC1_FD1;
                AluSrc2D <= `SRC2_IMM;
                MemWriteD <= 4'b0;
                // Funct 特异
                case (Fn3)
                    `F3_ADD: AluContrlD <= `ADD;
                    `F3_SLT: AluContrlD <= `SLT;
                    `F3_SLTU: AluContrlD <= `SLTU;
                    `F3_XOR: AluContrlD <= `XOR;
                    `F3_OR: AluContrlD <= `OR;
                    `F3_AND: AluContrlD <= `AND; 
                    default: AluContrlD <= 0;
                endcase
            end

            `OP_LUI: begin
                RegWriteD <= `LW;
                ImmType <= `UTYPE;
                JalD <= 0;
                JalrD <= 0;
                MemToRegD <= 0;
                LoadNpcD <= 0;
                RegReadD <= 0;
                BranchTypeD <= `NOBRANCH;
                AluSrc1D <= 0;  // 无所�?
                AluSrc2D <= `SRC2_IMM;
                AluContrlD <= `LUI;
                MemWriteD <= 4'b0;
            end

            `OP_AUI: begin
                RegWriteD <= `LW;
                ImmType <= `UTYPE;
                JalD <= 0;
                JalrD <= 0;
                MemToRegD <= 0;
                LoadNpcD <= 0;
                RegReadD <= 0;
                BranchTypeD <= `NOBRANCH;
                AluSrc1D <= `SRC1_PCE;      // PcE
                AluSrc2D <= `SRC2_IMM;   // ImmE
                AluContrlD <= `ADD;
                MemWriteD <= 4'b0;
            end

            `OP_JALR: begin
                RegWriteD <= `LW;
                ImmType <= `UTYPE;
                JalD <= 0;
                JalrD <= 1'b1;      // Jalr
                MemToRegD <= 0;     // FromALU
                LoadNpcD <= 1'b1;   // PC
                RegReadD <= 2'b01;  // Read
                BranchTypeD <= `NOBRANCH;
                AluSrc1D <= `SRC1_PCE;      // PcE
                AluSrc2D <= `SRC2_IMM;   // ImmE
                AluContrlD <= `ADD;
                MemWriteD <= 4'b0;
            end

            `OP_JAL: begin
                RegWriteD <= `LW;
                ImmType <= `JTYPE;
                JalD <= 1'b1;       // Jal
                JalrD <= 0;
                MemToRegD <= 0;     // FromALU
                LoadNpcD <= 1'b1;   // PC
                RegReadD <= 0;
                BranchTypeD <= `NOBRANCH;
                AluSrc1D <= 0;      // 随意
                AluSrc2D <= 2'd2;   // 随意
                AluContrlD <= `ADD; // 随意
                MemWriteD <= 4'b0;
            end

            `OP_BR: begin
                RegWriteD <= `NOREGWRITE;
                ImmType <= `BTYPE;
                JalD <= 0;
                JalrD <= 0;
                MemToRegD <= 0;     // 随意
                LoadNpcD <= 1'b1;   // 随意
                RegReadD <= 2'b11;  // Read          
                AluSrc1D <= `SRC1_FD1;      // 随意
                AluSrc2D <= `SRC2_FD2;   // 随意
                AluContrlD <= `ADD; // 随意
                MemWriteD <= 4'b0;

                case (Fn3)
                    `F3_BEQ: BranchTypeD <= `BEQ;
                    `F3_BNE: BranchTypeD <= `BNE;
                    `F3_BLT: BranchTypeD <= `BLT;
                    `F3_BGE: BranchTypeD <= `BGE;
                    `F3_BLTU: BranchTypeD <= `BLTU;
                    `F3_BGEU: BranchTypeD <= `BGEU;
                    default: BranchTypeD <= `NOBRANCH;
                endcase
            end

            `OP_LOAD: begin
                ImmType <= `ITYPE;
                JalD <= 0;
                JalrD <= 0;
                MemToRegD <= 1'b1;  // FromMem
                LoadNpcD <= 0;
                RegReadD <= 2'b01;  // Read
                BranchTypeD <= `NOBRANCH;
                AluSrc1D <= `SRC1_FD1;   // From Reg
                AluSrc2D <= `SRC2_IMM;   // From Imme
                AluContrlD <= `ADD; // Reg + Imme
                MemWriteD <= 4'b0;

                case (Fn3)
                    `F3_LB: RegWriteD <= `LB;
                    `F3_LH: RegWriteD <= `LH;
                    `F3_LW: RegWriteD <= `LW;
                    `F3_LBU: RegWriteD <= `LBU;
                    `F3_LHU: RegWriteD <= `LHU;
                    default: RegWriteD <= `NOREGWRITE;
                endcase
            end

            `OP_STORE: begin
                ImmType <= `STYPE;
                JalD <= 0;
                JalrD <= 0;
                MemToRegD <= 0;     // 随意
                LoadNpcD <= 0;
                RegReadD <= 2'b11;  // Read
                BranchTypeD <= `NOBRANCH;
                AluSrc1D <= `SRC1_FD1;   // From Reg
                AluSrc2D <= `SRC2_IMM;   // From Imme
                AluContrlD <= `ADD; // Reg + Imme
                RegWriteD <= `NOREGWRITE;
                
                case (Fn3)
                    `F3_SB: MemWriteD <= 4'b0001;
                    `F3_SH: MemWriteD <= 4'b0011;
                    `F3_SW: MemWriteD <= 4'b1111;
                    default: MemWriteD <= 4'b0;
                endcase
                
            end

            default: begin
            // DO NOTHING
                ImmType <= `ITYPE;
                JalD <= 0;
                JalrD <= 0;
                MemToRegD <= 0;
                LoadNpcD <= 0;
                RegReadD <= 0;
                BranchTypeD <= `NOBRANCH;
                AluSrc1D <= 0;
                AluSrc2D <= 0;
                AluContrlD <= `ADD;
                RegWriteD <= `NOREGWRITE;
                MemWriteD <= 0;
            end
        endcase
    end

endmodule

