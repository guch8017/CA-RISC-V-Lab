`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////
// Company: USTC ESLAB 
// Engineer: Wu Yuzhang
// 
// Design Name: RISCV-Pipline CPU
// Module Name: 
// Target Devices: Nexys4
// Tool Versions: Vivado 2017.4.1
// Description: Define some constant values
//////////////////////////////////////////////////////////////////////////////////
//功能说明
    //为了代码可读性，定义了常量值
//实验要求  
    //无需修改

`ifndef CONST_VALUES
`define CONST_VALUES
//ALUContrl[3:0]
    `define SLL  4'd0   // 4'b0000
    `define SRL  4'd1   // 4'b0001
    `define SRA  4'd2   // 4'b0010
    `define ADD  4'd3   // 4'b0011
    `define SUB  4'd4   // 4'b0100
    `define XOR  4'd5   // 4'b0101
    `define OR  4'd6    // 4'b0110
    `define AND  4'd7   // 4'b0111
    `define SLT  4'd8   // 4'b1000
    `define SLTU  4'd9  // 4'b1001
    `define LUI  4'd10  // 4'b1010
    `define CLR  4'd11  // 4'b1011
    `define CLR2 4'd12  // 4'b1100
    `define LUI2 4'd13  // 4'b1101
//BranchType[2:0]
    `define NOBRANCH  3'd0
    `define BEQ  3'd1
    `define BNE  3'd2
    `define BLT  3'd3
    `define BLTU  3'd4
    `define BGE  3'd5
    `define BGEU  3'd6
//ImmType[2:0]
    `define RTYPE  3'd0
    `define ITYPE  3'd1
    `define STYPE  3'd2
    `define BTYPE  3'd3
    `define UTYPE  3'd4
    `define JTYPE  3'd5 
    `define CTYPE  3'd6 
//RegWrite[2:0]  six kind of ways to save values to Register
    `define NOREGWRITE  3'b0	//	Do not write Register
    `define LB  3'd1			//	load 8bit from Mem then signed extended to 32bit
    `define LH  3'd2			//	load 16bit from Mem then signed extended to 32bit
    `define LW  3'd3			//	write 32bit to Register
    `define LBU  3'd4			//	load 8bit from Mem then unsigned extended to 32bit
    `define LHU  3'd5			//	load 16bit from Mem then unsigned extended to 32bit


`endif
