`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////
// Company: 
// Engineer: 
// 
// Create Date: 2021/05/27 21:03:05
// Design Name: 
// Module Name: branch_predictor
// Project Name: 
// Target Devices: 
// Tool Versions: 
// Description: 
// 
// Dependencies: 
// 
// Revision:
// Revision 0.01 - File Created
// Additional Comments:
// 
//////////////////////////////////////////////////////////////////////////////////


module static_predictor #(
        parameter PC_CNT = 4
    
    )(
        input wire clk,
        input wire [31:0] PCF,
        input wire [31:0] PCE,
        input wire [31:0] BrNPCE,
        input wire branch_ex,
        input wire branch_hit_ex,
        input wire rst,
        output wire [31:0] pc_predict,
        output wire hit
    );
    /*
        模拟的静态预测器
        只会输出PC+4和hit=0
    */

    assign pc_predict = PCF + 4;
    assign hit = 1'b0;
    
endmodule
