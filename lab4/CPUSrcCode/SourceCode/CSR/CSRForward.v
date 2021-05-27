`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////
// Company: USTC 
// Engineer: guch8017
// 
// Design Name: RISCV-Pipline CPU
// Module Name: CSR Forward Unit
// Target Devices: Nexys4
// Tool Versions: Vivado 2017.4.1
// Description: ALU unit of RISCV CPU
//////////////////////////////////////////////////////////////////////////////////


// 该模块控制CSR寄存器的转发
// 当CSRdE地址与另外W、M阶段时的地址一致且后两者We信号有效时将会进行转发

`ifndef CSR_FW
`define CSR_FW
    `define CFW_REG     2'b00
    `define CFW_MEM     2'b01
    `define CFW_WB      2'b10
`endif

module CSRForward(
    input wire [11:0] CSRdD, CSRdE, CSRdM, CSRdW,
    input wire CSRWeM, CSRWeW,
    output reg [1:0] CSRMux
);

    always @(*) begin
        if(CSRWeM && CSRdE == CSRdM) begin
            CSRMux <= `CFW_MEM;
        end
        else if (CSRWeW && CSRdE == CSRdW) begin
            CSRMux <= `CFW_WB;
        end
        else begin
            CSRMux <= `CFW_REG;
        end
    end

endmodule