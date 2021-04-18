`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////
// Company: USTC
// Engineer: guch8017
// 
// Design Name: RISCV-Pipline CPU
// Module Name: RegisterFile
// Target Devices: Nexys4
// Tool Versions: Vivado 2017.4.1
// Description: 
//////////////////////////////////////////////////////////////////////////////////
//功能说明
    //上升沿写入，异步读的寄存器堆，0号寄存器值始终为32'b0
    //在接入RV32Core时，输入为~clk，因此本模块时钟输入和其他部件始终相反
    //等价于例化本模块时正常接入时钟clk，同时修改代码为always@(negedge clk or negedge rst) 
// CSR寄存器文件，只有一个读端口，4096个寄存器文件
// 这里XLEN与寄存器文件大小一致，不需要零扩展了

module CSRRegisterFile(
    input wire clk,
    input wire rst,
    input wire WE,          // Write enable
    input wire [11:0] RA,   // Read Addr
    input wire [11:0] WA,   // Write Addr
    input wire [31:0] WD,   // Write Data
    output wire [31:0] RD,  // Read Data
    input wire [11:0] DebugRA,
    output wire [31:0] DebugRD
    );

    reg [31:0] RegFile[4095:0];
    integer i;
    //
    always@(negedge clk or posedge rst) 
    begin 
        if(rst)                                 for(i=0;i<4096;i=i+1) RegFile[i][31:0]<=32'b0;
        else if( WE==1'b1 )    RegFile[WA]<=WD;   
    end
    //    
    assign RD = RegFile[RA];
    assign DebugRD = RegFile[DebugRA];
endmodule