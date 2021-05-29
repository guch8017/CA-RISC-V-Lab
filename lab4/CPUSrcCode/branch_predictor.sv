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


module branch_predictor #(
        parameter PC_CNT = 4
    
    )(
        input wire clk,
        input wire [31:0] PCF,
        input wire [31:0] PCE,
        input wire [31:0] BrNPCE,
        input wire branch_ex,
        input wire branch_hit_ex,
        input wire rst,
        output reg [31:0] pc_predict,
        output reg hit
    );
    /*
        说明：
            1. 当rst有效时，所有有效位置0
            2. 当branch_id有效时，根据pc_id查找buffer判断是否需要跳转，pc_predict输出跳转地址或pc+4
            3. 当branch_hit_ex有效时说明发生了branch命中，根据pc_ex与target_pc_ex更新buffer
            4. 使用类似直接相连的方法
    */

    localparam NUM_PC = 2 << PC_CNT;

    reg[31:0] pc_buffer[NUM_PC];    // Source
    reg[31:0] dst_buffer[NUM_PC];   // Destination
    reg valid[NUM_PC];              // Predictor

    wire [PC_CNT:0] pc_entry_ud;    // Branch指令所在的PC INDEX
    wire [PC_CNT:0] pc_entry_if;    // IF段PC INDEX
    assign pc_entry_ud = PCE[PC_CNT+2:2];
    assign pc_entry_if = PCF[PC_CNT+2:2];


    always @(posedge clk or posedge rst) begin
        if (rst) begin
            for(integer i = 0; i < NUM_PC; ++i) begin
                pc_buffer[i] <= 0;
                dst_buffer[i] <= 0;
                valid[i] <= 0;
            end
        end
        else begin
            // Branch指令到达EX段，更新BTB
            if (branch_ex) begin
                // 分支表不存在表项，清除
                if(pc_buffer[pc_entry_ud] != PCE) begin
                    pc_buffer[pc_entry_ud] <= PCE;
                end
                // Branch HIT，状态更新
                if (branch_hit_ex) begin
                    dst_buffer[pc_entry_ud] <= BrNPCE;
                    valid[pc_entry_ud] <= 1'b1;
                end
                // Branch MISS，状态更新
                else begin
                    valid[pc_entry_ud] <= 1'b0;
                end
            end
        end
    end

    // 此处接管了NPC的PC+4功能
    always @(*) begin
        // 没有表项 或 表项无效，输出PC+4
        if(pc_buffer[pc_entry_if] != PCF || valid[pc_entry_if] != 1'b1) begin
            pc_predict <= PCF + 4;
            hit <= 0;
        end
        // BTB命中，输出BTB值
        else begin
            pc_predict <= dst_buffer[pc_entry_if];
            hit <= 1'b1;
        end
    end
endmodule
