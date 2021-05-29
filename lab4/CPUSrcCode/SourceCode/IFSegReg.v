`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////
// Company: USTC ESLAB 
// Engineer: Wu Yuzhang
// 
// Design Name: RISCV-Pipline CPU
// Module Name: IFSegReg
// Target Devices: Nexys4
// Tool Versions: Vivado 2017.4.1
// Description: PC Register
//////////////////////////////////////////////////////////////////////////////////
//功能说明
    //IDSegReg是IF-ID段寄存器
//实验要求  
    //无需修改

module IFSegReg(
    input wire clk,
    input wire en, clear,
    input wire [31:0] PC_In,
    output reg [31:0] PCF,
    input wire PR_In,
    output reg PRF
    );

    initial begin
        PCF = 0;
        PRF = 0;
    end

    always@(posedge clk)
        if(en) begin
            if(clear) begin
                PCF <= 0;
                PRF <= 0;
            end
            else begin
                PCF <= PC_In;
                PRF <= PR_In;
            end
        end
    
endmodule

