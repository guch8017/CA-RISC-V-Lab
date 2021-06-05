`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////
// Company: USTC ESLAB 
// Engineer: Wu Yuzhang
// 
// Design Name: RISCV-Pipline CPU
// Module Name: RV32Core
// Target Devices: Nexys4
// Tool Versions: Vivado 2017.4.1
// Description: Top level of our CPU Core
//////////////////////////////////////////////////////////////////////////////////
//功能说明
    //RV32I 指令集CPU的顶层模块
//实验要求  
    //无需修改
`include "Parameters.v"

module RV32Core(
    input wire CPU_CLK,
    input wire CPU_RST,
    output wire [31:0] DCacheMissCounter
    );
	//wire values definitions
    wire StallF, FlushF, StallD, FlushD, StallE, FlushE, StallM, FlushM, StallW, FlushW;
    wire [31:0] PC_In;
    wire [31:0] PCF;
    wire [31:0] Instr, PCD;
    wire JalD, JalrD, LoadNpcD;
    wire [2:0] RegWriteD;
    wire [3:0] MemWriteD;
    wire [1:0] RegReadD;
    wire [2:0] BranchTypeD;
    wire [3:0] AluContrlD;
    wire [1:0] AluSrc2D, AluSrc1D;
    wire [2:0] RegWriteW;
    wire [4:0] RdW;
    wire [31:0] RegWriteData;
    wire [31:0] DM_RD_Ext;
    wire [2:0] ImmType;
    wire [31:0] ImmD;
    wire [31:0] JalNPC;
    wire [31:0] BrNPC; 
    wire [31:0] ImmE;
    wire [6:0] OpCodeD, Funct7D;
    wire [2:0] Funct3D;
    wire [4:0] Rs1D, Rs2D, RdD;
    wire [4:0] Rs1E, Rs2E, RdE;
    wire [31:0] RegOut1D;
    wire [31:0] RegOut1E;
    wire [31:0] RegOut2D;
    wire [31:0] RegOut2E;
    wire JalrE;
    wire [2:0] RegWriteE;
    wire [3:0] MemWriteE;
    wire LoadNpcE;
    wire [1:0] RegReadE;
    wire [2:0] BranchTypeE;
    wire [3:0] AluContrlE;
    wire [1:0] AluSrc1E;
    wire [1:0] AluSrc2E;
    wire [31:0] Operand1;
    wire [31:0] Operand2;
    wire BranchE;
    wire [31:0] AluOutE;
    wire [31:0] AluOutM; 
    wire [31:0] ForwardData1;
    wire [31:0] ForwardData2;
    wire [31:0] PCE;
    wire [31:0] StoreDataM; 
    wire [4:0] RdM;
    wire [31:0] PCM;
    wire [2:0] RegWriteM;
    wire [3:0] MemWriteM;
    wire LoadNpcM;
    wire [31:0] DM_RD;
    wire [31:0] ResultM;
    wire [31:0] ResultW;
    wire [1:0] Forward1E;
    wire [1:0] Forward2E;
    wire [1:0] LoadedBytesSelect;
    // Add CSR datapath
    wire [11:0] CSRdD, CSRdE, CSRdM, CSRdW;
    wire CSRWeD, CSRWeE, CSRWeM, CSRWeW;
    wire [31:0] CSROutD, CSROutE, CSROutM, CSROutW;
    wire [31:0] CSRFwE; // 数据相关转发
    wire [1:0] CSR_FW;
    wire [1:0] MemToRegD, MemToRegE, MemToRegM, MemToRegW;
    // Add DCache
    wire DCacheMiss;

    //wire values assignments
    assign {Funct7D, Rs2D, Rs1D, Funct3D, RdD, OpCodeD} = Instr;
    assign JalNPC=ImmD+PCD;
    assign ForwardData1 = Forward1E[1]?((Forward1E[0])?CSROutM:AluOutM):( Forward1E[0]?RegWriteData:RegOut1E );
    assign Operand1 = AluSrc1E[1]?(CSRFwE):((AluSrc1E[0])?PCE:ForwardData1);
    assign ForwardData2 = Forward2E[1]?((Forward2E[0])?CSROutM:AluOutM):( Forward2E[0]?RegWriteData:RegOut2E );
    assign Operand2 = AluSrc2E[1]?((AluSrc2E[0])?CSRFwE:ImmE):((AluSrc2E[0])?Rs2E:ForwardData2 );
    assign ResultM = LoadNpcM ? (PCM+4) : AluOutM;
    assign RegWriteData = MemToRegW[1] ? CSROutW : (MemToRegW[0] ? DM_RD_Ext : ResultW);
    assign CSRFwE = (CSR_FW[1]) ? (ResultW) : ((CSR_FW[0]) ? (AluOutM) : (CSROutE));
    assign CSRdD = Instr[31:20];

    // ============= Branch Predict ==============

    wire [31:0] PCPredict, BranchPC;
    wire PR_IN, PRF, PRD;                                 // 若BTB命中则置1，否则输出PC+4，该信号置0
    wire PredictCorrect;
    wire BranchFail;

    assign PredictCorrect = (PRD == 1'b1 && BranchE == 1'b1 && PCD == BrNPC) ||     // 预测跳转，且实际跳转，且目标地址一致
                            (PRD == 1'b0 && BranchE == 1'b0);                       // 预测不跳转且实际不跳转
    assign BranchFail = (BranchTypeE != `NOBRANCH) && ~PredictCorrect;              // 预测失败，需要交由Hazard处理Branch
    assign BranchPC = (PRD == 1'b1 && BranchE == 1'b0) ? (PCE + 4)                  // 预测跳转但实际没有跳转，下一个值为当前PC + 4
                                                       : (BrNPC);                   // 预测不跳转但实际跳转，下一个值为BrNPC

    bht_predictor BPInstance(
        .clk(CPU_CLK),
        .rst(CPU_RST),
        .PCF(PCF),
        .PCE(PCE),
        .BrNPCE(BrNPC),
        .branch_ex(BranchTypeE != `NOBRANCH),
        .branch_hit_ex(BranchE),
        .pc_predict(PCPredict),
        .hit(PR_IN)
    );

    // Register for statistics
    reg [31:0] BranchCounter;
    reg [31:0] BranchCorrectCounter;
    reg [31:0] CycleCounter;
    reg DCacheFlop;

    always @(posedge CPU_CLK or posedge CPU_RST) begin
        if(CPU_RST) begin
            BranchCounter <= 0;
            BranchCorrectCounter <= 0;
            DCacheFlop <= 0;
            CycleCounter <= 0;
        end
        else begin
            CycleCounter <= CycleCounter + 1;
            if(BranchTypeE != `NOBRANCH) begin
                if(DCacheMiss) begin
                    // 防止Stall导致的统计错误
                    if(!DCacheFlop) begin
                        DCacheFlop <= 1'b1;
                        BranchCounter <= BranchCounter + 1;
                        if(PredictCorrect) begin
                            BranchCorrectCounter <= BranchCorrectCounter + 1;
                        end
                    end
                end
                else begin
                    DCacheFlop <= 1'b0;
                    BranchCounter <= BranchCounter + 1;
                    if(PredictCorrect) begin
                        BranchCorrectCounter <= BranchCorrectCounter + 1;
                    end
                end
            end
        end
    end


    // ============= END BRANCH PRED =============

    //Module connections
    // ---------------------------------------------
    // PC-IF
    // ---------------------------------------------
    NPC_Generator NPC_Generator1(
        .PCPredict(PCPredict),
        .JalrTarget(AluOutE), 
        .BranchTarget(BranchPC), 
        .JalTarget(JalNPC),
        .BranchE(BranchFail),
        .JalD(JalD),
        .JalrE(JalrE),
        .PC_In(PC_In)
    );

    IFSegReg IFSegReg1(
        .clk(CPU_CLK),
        .en(~StallF),
        .clear(FlushF), 
        .PC_In(PC_In),
        .PCF(PCF),
        .PR_In(PR_IN),
        .PRF(PRF)
    );

    // ---------------------------------------------
    // ID stage
    // ---------------------------------------------
    IDSegReg IDSegReg1(
        .clk(CPU_CLK),
        .clear(FlushD),
        .en(~StallD),
        .A(PCF),
        .RD(Instr),
        .PCF(PCF),
        .PCD(PCD),
        .PRF(PRF),
        .PRD(PRD)
    );

    ControlUnit ControlUnit1(
        .Op(OpCodeD),
        .Fn3(Funct3D),
        .Fn7(Funct7D),
        .JalD(JalD),
        .JalrD(JalrD),
        .RegWriteD(RegWriteD),
        .MemToRegD(MemToRegD),
        .MemWriteD(MemWriteD),
        .LoadNpcD(LoadNpcD),
        .RegReadD(RegReadD),
        .BranchTypeD(BranchTypeD),
        .AluContrlD(AluContrlD),
        .AluSrc1D(AluSrc1D),
        .AluSrc2D(AluSrc2D),
        .ImmType(ImmType),
        .CSRWriteD(CSRWeD)
    );

    ImmOperandUnit ImmOperandUnit1(
        .In(Instr[31:7]),
        .Type(ImmType),
        .Out(ImmD)
    );

    RegisterFile RegisterFile1(
        .clk(CPU_CLK),
        .rst(CPU_RST),
        .WE3(|RegWriteW),
        .A1(Rs1D),
        .A2(Rs2D),
        .A3(RdW),
        .WD3(RegWriteData),
        .RD1(RegOut1D),
        .RD2(RegOut2D)
    );

    // ---------------------------------------------
    // EX stage
    // ---------------------------------------------
    EXSegReg EXSegReg1(
        .clk(CPU_CLK),
        .en(~StallE),
        .clear(FlushE),
        .PCD(PCD),
        .PCE(PCE), 
        .JalNPC(JalNPC),
        .BrNPC(BrNPC), 
        .ImmD(ImmD),
        .ImmE(ImmE),
        .RdD(RdD),
        .RdE(RdE),
        .Rs1D(Rs1D),
        .Rs1E(Rs1E),
        .Rs2D(Rs2D),
        .Rs2E(Rs2E),
        .RegOut1D(RegOut1D),
        .RegOut1E(RegOut1E),
        .RegOut2D(RegOut2D),
        .RegOut2E(RegOut2E),
        .JalrD(JalrD),
        .JalrE(JalrE),
        .RegWriteD(RegWriteD),
        .RegWriteE(RegWriteE),
        .MemToRegD(MemToRegD),
        .MemToRegE(MemToRegE),
        .MemWriteD(MemWriteD),
        .MemWriteE(MemWriteE),
        .LoadNpcD(LoadNpcD),
        .LoadNpcE(LoadNpcE),
        .RegReadD(RegReadD),
        .RegReadE(RegReadE),
        .BranchTypeD(BranchTypeD),
        .BranchTypeE(BranchTypeE),
        .AluContrlD(AluContrlD),
        .AluContrlE(AluContrlE),
        .AluSrc1D(AluSrc1D),
        .AluSrc1E(AluSrc1E),
        .AluSrc2D(AluSrc2D),
        .AluSrc2E(AluSrc2E),
        .CSROutD(CSROutD),
        .CSROutE(CSROutE),
        .CSRWeD(CSRWeD),
        .CSRWeE(CSRWeE),
        .CSRdD(CSRdD),
        .CSRdE(CSRdE)
    	); 

    ALU ALU1(
        .Operand1(Operand1),
        .Operand2(Operand2),
        .AluContrl(AluContrlE),
        .AluOut(AluOutE)
    	);

    BranchDecisionMaking BranchDecisionMaking1(
        .BranchTypeE(BranchTypeE),
        .Operand1(Operand1),
        .Operand2(Operand2),
        .BranchE(BranchE)
        );

    // ---------------------------------------------
    // MEM stage
    // ---------------------------------------------
    MEMSegReg MEMSegReg1(
        .clk(CPU_CLK),
        .en(~StallM),
        .clear(FlushM),
        .AluOutE(AluOutE),
        .AluOutM(AluOutM), 
        .ForwardData2(ForwardData2),
        .StoreDataM(StoreDataM), 
        .RdE(RdE),
        .RdM(RdM),
        .PCE(PCE),
        .PCM(PCM),
        .RegWriteE(RegWriteE),
        .RegWriteM(RegWriteM),
        .MemToRegE(MemToRegE),
        .MemToRegM(MemToRegM),
        .MemWriteE(MemWriteE),
        .MemWriteM(MemWriteM),
        .LoadNpcE(LoadNpcE),
        .LoadNpcM(LoadNpcM),
        .CSROutE(CSRFwE),
        .CSROutM(CSROutM),
        .CSRWeE(CSRWeE),
        .CSRWeM(CSRWeM),
        .CSRdE(CSRdE),
        .CSRdM(CSRdM)
    );

    // ---------------------------------------------
    // WB stage
    // ---------------------------------------------
    WBSegReg WBSegReg1(
        .clk(CPU_CLK),
        .en(~StallW),
        .clear(FlushW),
        .A(AluOutM),
        .WD(StoreDataM),
        .WE(MemWriteM),
        .RD(DM_RD),
        .LoadedBytesSelect(LoadedBytesSelect),
        .ResultM(ResultM),
        .ResultW(ResultW), 
        .RdM(RdM),
        .RdW(RdW),
        .RegWriteM(RegWriteM),
        .RegWriteW(RegWriteW),
        .MemToRegM(MemToRegM),
        .MemToRegW(MemToRegW),
        .CSROutM(CSROutM),
        .CSROutW(CSROutW),
        .CSRWeM(CSRWeM),
        .CSRWeW(CSRWeW),
        .CSRdM(CSRdM),
        .CSRdW(CSRdW),
        .rst(CPU_RST),  // BRAM 复位
        .MemReadM(MemToRegM == 2'b01),
        .DCacheMiss(DCacheMiss),
        .DCacheMissCounter(DCacheMissCounter)
    );
    
    DataExt DataExt1(
        .IN(DM_RD),
        .LoadedBytesSelect(LoadedBytesSelect),
        .RegWriteW(RegWriteW),
        .OUT(DM_RD_Ext)
    );
    // ---------------------------------------------
    // Harzard Unit
    // ---------------------------------------------
    HarzardUnit HarzardUnit1(
        .CpuRst(CPU_RST),
        .BranchE(BranchFail),
        .JalrE(JalrE),
        .JalD(JalD),
        .Rs1D(Rs1D),
        .Rs2D(Rs2D),
        .Rs1E(Rs1E),
        .Rs2E(Rs2E),
        .RegReadE(RegReadE),
        .MemToRegE(MemToRegE),
        .RdE(RdE),
        .RdM(RdM),
        .RegWriteM(RegWriteM),
        .RdW(RdW),
        .RegWriteW(RegWriteW),
        .ICacheMiss(1'b0),
        .DCacheMiss(DCacheMiss),
        .StallF(StallF),
        .FlushF(FlushF),
        .StallD(StallD),
        .FlushD(FlushD),
        .StallE(StallE),
        .FlushE(FlushE),
        .StallM(StallM),
        .FlushM(FlushM),
        .StallW(StallW),
        .FlushW(FlushW),
        .Forward1E(Forward1E),
        .Forward2E(Forward2E),
        .CSRWeM(CSRWeM)
    	);    
    	         
    // ---------------------------------------------
    // CSR Register File
    // ---------------------------------------------
    CSRRegisterFile CSRRegisterFile1(
        .clk(CPU_CLK),
        .rst(CPU_RST),
        .WE(CSRWeW),
        .RA(CSRdD),
        .WA(CSRdW),
        .WD(ResultW),
        .RD(CSROutD),
        .DebugRA(),
        .DebugRD()
    );

    // ---------------------------------------------
    // CSR Forward Unit
    // ---------------------------------------------
    CSRForward CSRForward1(
        .CSRdD(CSRdD), 
        .CSRdE(CSRdE), 
        .CSRdM(CSRdM), 
        .CSRdW(CSRdW),
        .CSRWeM(CSRWeM), 
        .CSRWeW(CSRWeW),
        .CSRMux(CSR_FW)
    );
endmodule

