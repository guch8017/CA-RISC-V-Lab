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
//功能和接口说明
    //ControlUnit       是本CPU的指令译码器，组合逻辑电路
//输入
    // Op               是指令的操作码部分
    // Fn3              是指令的func3部分
    // Fn7              是指令的func7部分
//输出
    // JalD==1          表示Jal指令到达ID译码阶段
    // JalrD==1         表示Jalr指令到达ID译码阶段
    // RegWriteD        表示ID阶段的指令对应的寄存器写入模式
    // MemToRegD==1     表示ID阶段的指令需要将data memory读取的值写入寄存器,
    // MemWriteD        共4bit，采用独热码格式，对于data memory的32bit字按byte进行写入,MemWriteD=0001表示只写入最低1个byte，和xilinx bram的接口类似
    // LoadNpcD==1      表示将NextPC输出到ResultM
    // RegReadD         表示A1和A2对应的寄存器值是否被使用到了，用于forward的处理
    // BranchTypeD      表示不同的分支类型，所有类型定义在Parameters.v中
    // AluContrlD       表示不同的ALU计算功能，所有类型定义在Parameters.v中
    // AluSrc2D         表示Alu输入源2的选择
    // AluSrc1D         表示Alu输入源1的选择
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

module ControlUnit(
    input wire [6:0] Op,
    input wire [2:0] Fn3,
    input wire [6:0] Fn7,
    output wire JalD,
    output wire JalrD,
    output reg [2:0] RegWriteD,
    output wire MemToRegD,
    output reg [3:0] MemWriteD,
    output wire LoadNpcD,
    output reg [1:0] RegReadD,
    output reg [2:0] BranchTypeD,
    output reg [3:0] AluContrlD,
    output wire [1:0] AluSrc2D,
    output wire AluSrc1D,
    output reg [2:0] ImmType        
    ); 
    
    always @(*) begin
        case (Op)
            `OP_IMM: begin
                RegWriteD <= `LW;
                ImmType <= `ITYPE;
                JalD <= 0;
                JalrD <= 0;
                MemToRegD <= 0;
                LoadNpcD <= 0;
                RegReadD <= 1'b1;
                BranchTypeD <= `NOBRANCH;
                AluSrc1D <= 1'b1;
                AluSrc2D <= 2'd2;
                MemWriteD <= 4'b0;
                if (Fn3 == 3'b001 && Fn7 == 7'b0000000) begin
                    AluContrlD <= `SLL;
                end else if(Fn3 == 3'b101 && Fn7 == 7'b0000000)begin
                    AluContrlD <= `SRL;
                end else begin
                    AluContrlD <= `SRA;
                end
            end

            `OP_REG: begin
                // 通用赋值
                RegWriteD <= `LW;
                ImmType <= `ITYPE;
                JalD <= 0;
                JalrD <= 0;
                MemToRegD <= 0;
                LoadNpcD <= 0;
                RegReadD <= 1'b1;
                BranchTypeD <= `NOBRANCH;
                AluSrc1D <= 1'b1;
                AluSrc2D <= 2'b0;
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
                // 通用赋值
                RegWriteD <= `LW;
                ImmType <= `ITYPE;
                JalD <= 0;
                JalrD <= 0;
                MemToRegD <= 0;
                LoadNpcD <= 0;
                RegReadD <= 1'b1;
                BranchTypeD <= `NOBRANCH;
                AluSrc1D <= 1'b1;
                AluSrc2D <= 2'd2;
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
                AluSrc1D <= 0;  // 无所谓
                AluSrc2D <= 2'd2;
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
                AluSrc1D <= 0;      // PcE
                AluSrc2D <= 2'd2;   // ImmE
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
                RegReadD <= 1'b1;   // Read
                BranchTypeD <= `NOBRANCH;
                AluSrc1D <= 0;      // PcE
                AluSrc2D <= 2'd2;   // ImmE
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
                RegReadD <= 1'b1;   // Read          
                AluSrc1D <= 0;      // 随意
                AluSrc2D <= 2'd2;   // 随意
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
                RegReadD <= 1'b1;   // Read
                BranchTypeD <= `NOBRANCH;
                AluSrc1D <= 1'b1;   // From Reg
                AluSrc2D <= 2'd2;   // From Imme
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
                RegReadD <= 1'b1;   // Read
                BranchTypeD <= `NOBRANCH;
                AluSrc1D <= 1'b1;   // From Reg
                AluSrc2D <= 2'd2;   // From Imme
                AluContrlD <= `ADD; // Reg + Imme
                RegWriteD <= `NOREGWRITE;
                
                case (Fn3)
                    `F3_SB: MemWriteD <= 4'b0001;
                    `F3_SH: MemWriteD <= 4'b0011;
                    `F3_SW: MemWriteD <= 4'b1111;
                    default: MemWriteD <= 4'b0;
                endcase
                
            end

            default: 
        endcase
    end

endmodule

