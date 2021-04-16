`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////
// Company: USTC ESLAB 
// Engineer: Wu Yuzhang
// 
// Design Name: RISCV-Pipline CPU
// Module Name: HarzardUnit
// Target Devices: Nexys4
// Tool Versions: Vivado 2017.4.1
// Description: Deal with harzards in pipline
//////////////////////////////////////////////////////////////////////////////////
//功能说明
    //HarzardUnit用来处理流水线冲突，通过插入气泡，forward以及冲刷流水段解决数据相关和控制相关，组合�?�辑电路
    //可以�?后实现�?�前期测试CPU正确性时，可以在每两条指令间插入四条空指令，然后直接把本模块输出定为，不forward，不stall，不flush 
//输入
    //CpuRst                                    外部信号，用来初始化CPU，当CpuRst==1时CPU全局复位清零（所有段寄存器flush），Cpu_Rst==0时cpu�?始执行指�?
    //ICacheMiss, DCacheMiss                    为后续实验预留信号，暂时可以无视，用来处理cache miss
    //BranchE, JalrE, JalD                      用来处理控制相关
    //Rs1D, Rs2D, Rs1E, Rs2E, RdE, RdM, RdW     用来处理数据相关，分别表示源寄存�?1号码，源寄存�?2号码，目标寄存器号码
    //RegReadE RegReadD[1]==1                   表示A1对应的寄存器值被使用到了，RegReadD[0]==1表示A2对应的寄存器值被使用到了，用于forward的处�?
    //RegWriteM, RegWriteW                      用来处理数据相关，RegWrite!=3'b0说明对目标寄存器有写入操�?
    //MemToRegE                                 表示Ex段当前指�? 从Data Memory中加载数据到寄存器中
//输出
    //StallF, FlushF, StallD, FlushD, StallE, FlushE, StallM, FlushM, StallW, FlushW    控制五个段寄存器进行stall（维持状态不变）和flush（清零）
    //Forward1E, Forward2E                                                              控制forward
//实验要求  
    //补全模块  
`ifndef FORWARD_MUX_ID
`define FORWARD_MUX_ID

    `define FW1_ALU_MEM 2'b10
    `define FW1_REG_WB  2'b01
    `define FW1_REG_EX  2'b00

    `define FW2_ALU_MEM 2'b10
    `define FW2_REG_WB  2'b01
    `define FW2_REG_EX  2'b00

`endif
    
module HarzardUnit(
    input wire CpuRst, ICacheMiss, DCacheMiss, 
    input wire BranchE, JalrE, JalD, 
    input wire [4:0] Rs1D, Rs2D, Rs1E, Rs2E, RdE, RdM, RdW,
    input wire [1:0] RegReadE,
    input wire MemToRegE,
    input wire [2:0] RegWriteM, RegWriteW,
    output reg StallF, FlushF, StallD, FlushD, StallE, FlushE, StallM, FlushM, StallW, FlushW,
    output reg [1:0] Forward1E, Forward2E
    );
    
    
    // 大概和COD实验差不多吧
    // Stall
    always @(*) begin
        if(CpuRst) begin
            {StallF, StallD, StallE, StallM, StallW} <= 5'b0;
            {FlushF, FlushD, FlushE, FlushM, FlushW} <= 5'b11111;
        end
        else if((RegReadE[0] && Rs1D == RdE && MemToRegE) || // 寄存器端�?1 Hazard
           (RegReadE[1] && Rs2D == RdE && MemToRegE))   // 寄存器端�?2 Hazard
           begin
               StallF <= 1;
               StallD <= 1;
               FlushE <= 1;
               {StallW, StallD, StallM, FlushF, FlushD, FlushE, FlushM, FlushW} <= 8'b0;
           end
        else if(BranchE != `NOBRANCH || JalrE != 0) begin
            FlushE <= 1'b1;
            FlushD <= 1'b1;
            {FlushF, FlushM, FlushW} <= 3'b0;
            {StallE, StallF, StallD, StallW, StallM} <= 5'b0;
        end
        else if (JalrE != 0) begin
            FlushE <= 1'b1;
            FlushD <= 1'b1;
            {FlushF, FlushM, FlushW} <= 3'b0;
            {StallE, StallF, StallD, StallW, StallM} <= 5'b0;
        end
        else if (JalD != 0) begin
           FlushD <= 1'b1; 
           {FlushF, FlushE, FlushM, FlushW} <= 3'b0;
           {StallE, StallF, StallD, StallW, StallM} <= 5'b0;
        end
        else begin
            {StallF, StallD, StallE, StallM, StallW} <= 5'b0;
            {FlushF, FlushD, FlushE, FlushM, FlushW} <= 5'b0;
        end
    end 

    // Forward
    always @(*) begin
        if(RegWriteM && (RdM != 0) && (RdM == Rs1E))
            Forward1E <= `FW1_ALU_MEM;
        else if(RegWriteW && (RdW != 0) && !(RegWriteM && (RdM != 0) && (RdM != Rs2E)) && (RdW == Rs1E))
            Forward1E <= `FW1_REG_WB;
        else
            Forward1E <= `FW1_REG_EX;
        if(RegWriteM && (RdM != 0) && (RdM == Rs2E))
            Forward2E <= `FW2_ALU_MEM;
        else if(RegWriteW && (RdW != 0) && !(RegWriteM && (RdM != 0) && (RdM != Rs2E)) && (RdW == Rs2E))
            Forward2E <= `FW2_REG_WB;
        else
            Forward2E <= `FW2_REG_EX;
    end

endmodule

  