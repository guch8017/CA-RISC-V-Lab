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
        parameter PC_CNT = 4;
    
    )(
        input wire clk,
        input wire [31:0] pc_id,
        input wire [31:0] target_pc_ex,
        input wire [31:0] pc_ex,
        input wire branch_ex,
        input wire branch_hit_ex,
        input wire branch_id
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

    parameter NUM_PC = 1 << PC_CNT;

    reg[31:0] pc_buffer[NUM_PC];    // Source
    reg[31:0] dst_buffer[NUM_PC];   // Destination
    reg valid[NUM_PC];              // Predictor

    wire [PC_CNT:0] pc_entry_ex;
    wire [PC_CNT:0] pc_entry_id;
    assign pc_entry_ex = pc_ex[PC_CNT:0];
    assign pc_entry_id = pc_id[PC_CNT:0];


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
                if(pc_buffer[pc_entry_ex] == pc_ex) begin
                    pc_buffer[pc_entry_ex] <= pc_ex;
                end
                // Branch HIT，状态更新
                if (branch_hit_ex) begin
                    dst_buffer[pc_entry_ex] <= target_pc_ex;
                    valid[pc_entry_ex] <= 1'b1;
                end
                else begin
                    valid[pc_entry_ex] <= 1'b0;
                end
            end
            // Branch指令到达ID段，执行预测动作
            if (branch_id) begin
                // 没有表项 或 表项无效，输出PC+4
                if(pc_buffer[pc_entry_id] != pc_id || valid[pc_entry_id] != 1'b1) begin
                    pc_predict <= pc_id + 4;
                    hit <= 0;
                end
                // BTB命中，输出BTB值
                else begin
                    pc_predict <= dst_buffer[pc_entry_id];
                    hit <= 1'b1;
                end
            end
        end
    end
endmodule
