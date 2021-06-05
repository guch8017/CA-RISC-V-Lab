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


module bht_predictor #(
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
            2. 当branch_ex有效时，说明EX段出现Branch指令，若branch_hit_ex有效时说明发生了branch命中，更新buffer，否则valid位置0
               由于valid为0时，下一次遇到的分支会返回PC+4，故无需另外将预测不命中的NPC存入BTB中
            3. BTB采用直接相连替换策略

        BHT

    */

    localparam NUM_PC = 2 << PC_CNT;

    reg[31:0] pc_buffer[NUM_PC];    // Source
    reg[31:0] dst_buffer[NUM_PC];   // Destination
    reg valid[NUM_PC];              // Predictor
    reg [1:0]bht_buffer[NUM_PC];    // BHT Buffer，当buffer为1x时预测命中，0x时预测不命中

    wire [PC_CNT:0] pc_entry_ud;    // Branch指令所在的PC INDEX
    wire [PC_CNT:0] pc_entry_if;    // IF段PC INDEX
    assign pc_entry_ud = PCE[PC_CNT+2:2];
    assign pc_entry_if = PCF[PC_CNT+2:2];

    // ======= PHASE 2 - 2'bit BHT Predictor
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
                // 分支表不存在表项，重置BHT状态机
                if(pc_buffer[pc_entry_ud] != PCE || valid[pc_entry_ud] == 1'b0) begin
                    pc_buffer[pc_entry_ud] <= PCE;
                    valid[pc_entry_ud] <= 1'b1;
                    if (branch_hit_ex) begin
                        bht_buffer[pc_entry_ud] <= 2'b10;
                    end
                    else begin
                        bht_buffer[pc_entry_ud] <= 2'b01;
                    end
                end
                // 分支表命中，进行状态更新
                else begin
                    // Branch HIT
                    if (branch_hit_ex) begin
                        dst_buffer[pc_entry_ud] <= BrNPCE;
                        // 状态机更新，防止溢出
                        if (bht_buffer[pc_entry_ud] != 2'b11) begin
                            bht_buffer[pc_entry_ud] <= bht_buffer[pc_entry_ud] + 1;
                        end
                    end
                    // Branch MISS
                    else begin
                        if (bht_buffer[pc_entry_ud] != 2'b00) begin
                            bht_buffer[pc_entry_ud] <= bht_buffer[pc_entry_ud] - 1;
                        end
                    end
                end
            end
        end
    end
    // ======= END OF P2 ==================

    // 此处接管了NPC的PC+4功能
    always @(*) begin
        // 没有表项 或 表项无效 或 BHT预测不命中 输出PC+4
        if(pc_buffer[pc_entry_if] != PCF || valid[pc_entry_if] != 1'b1 || bht_buffer[pc_entry_if][1] == 1'b0) begin
            pc_predict <= PCF + 4;
            hit <= 0;
        end
        // BHT预测命中
        else begin
            pc_predict <= dst_buffer[pc_entry_if];
            hit <= 1'b1;
        end
    end
endmodule
