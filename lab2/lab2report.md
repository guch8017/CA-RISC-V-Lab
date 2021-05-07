# 计算机体系结构 Lab 2实验报告

PB18030825 顾超 

## 实验目标

* 利用TA提供的RISC-V流水线CPU代码框架，填充相应位置的缺失代码，实现RV32I指令集中的功能。
* 实现CPU流水线中的数据转发与冒险检测
* 添加适当部件与数据通路，修改控制单元信号，使CPU支持CSR Access系列指令

## 实验环境

* VLAB 虚拟机(Ubuntu 20.04 LTS)
* Vivado 2019.1

## 实验内容及过程

### Phase 1

#### Control Unit

控制单元为本次实验CPU中最为复杂的部分。在本次实现中采用case语句，先判别OpCode字段，而后对该OpCode下统一信号进行赋值，最后再利用case语句块判断Funct3字段，从而最终决定控制信号输出内容，以下为其中一种OpCode的例子

```verilog
always @(*) begin
  case (Op)
    `OP_REG: begin
      // 通用
      RegWriteD <= `LW;
      ImmType <= `ITYPE;
      JalD <= 0;
      JalrD <= 0;
      MemToRegD <= `MTR_ALU;
      LoadNpcD <= 0;
      RegReadD <= 2'b11;
      BranchTypeD <= `NOBRANCH;
      AluSrc1D <= `SRC1_FD1;
      AluSrc2D <= `SRC2_FD2;
      MemWriteD <= 4'b0;
      CSRWriteD <= 1'b0;
      // Funct 特异
      case (Fn3)
        `F3_ADD: AluContrlD <= (Fn7 == 7'b0100000) ? `SUB : `ADD;
        `F3_SLL: AluContrlD <= `SLL;
        `F3_SLT: AluContrlD <= `SLT;
        `F3_SLTU: AluContrlD <= `SLTU;
        `F3_XOR: AluContrlD <= `XOR;
        `F3_SRLA: AluContrlD <= (Fn7 == 7'b0100000) ? `SRA : `SRL;
        `F3_OR:  AluContrlD <= `OR;
        `F3_AND: AluContrlD <= `AND;
        default: AluContrlD <= 0;
      endcase
    end
  // Other cases
  // ...
  endcase
end
```

#### ALU

ALU涉及到有符号数的运算与比较，故定义新的有符号wire并将输入信号与其直接相连，当涉及到有符号数操作时使用有符号wire进行处理。使用一case语句块，根据输入的AluControl信号决定对输入数据做何种运算，实现如下

```verilog
wire signed [31:0] SignedOperand1, SignedOperand2;
assign SignedOperand1 = Operand1;
assign SignedOperand2 = Operand2;

always @(*) begin
  case (AluContrl)
    `ADD: AluOut <= Operand1 + Operand2;
    `SUB: AluOut <= Operand1 - Operand2;
    `SLL: AluOut <= Operand1 << Operand2[4:0];
    `SRL: AluOut <= Operand1 >> Operand2[4:0];
    `SRA: AluOut <= SignedOperand1 >>> Operand2[4:0];
    `SLT: AluOut <= (SignedOperand1 < SignedOperand2) ? 1 : 0;
    `SLTU: AluOut <= (Operand1 < Operand2) ? 1 : 0;
    `XOR: AluOut <= Operand1 ^ Operand2;
    `OR: AluOut <= Operand1 | Operand2;
    `AND: AluOut <= Operand1 & Operand2;
    `LUI: AluOut <= Operand2;
    `LUI2: AluOut <= Operand1;
    `CLR: AluOut <= (~Operand1) & Operand2;
    `CLR2: AluOut <= Operand1 & (~Operand2);
    default: AluOut <= 0;
  endcase
end
```

#### BranchDecision

实现思路与ALU类似，仅涉及的操作类型不一样，具体实现如下

```verilog
wire signed [31:0] SignedOperand1, SignedOperand2;
assign SignedOperand1 = Operand1;
assign SignedOperand2 = Operand2;

always @(*) begin
  case (BranchTypeE)
    `NOBRANCH: BranchE <= 1'b0;
    `BEQ: BranchE <= (Operand1 == Operand2) ? 1'b1 : 1'b0;
    `BNE: BranchE <= (Operand1 != Operand2) ? 1'b1 : 1'b0;
    `BLT: BranchE <= (SignedOperand1 < SignedOperand2) ? 1'b1 : 1'b0;
    `BLTU: BranchE <= (Operand1 < Operand2) ? 1'b1 : 1'b0;
    `BGE: BranchE <= (SignedOperand1 >= SignedOperand2) ? 1'b1 : 1'b0;
    `BGEU: BranchE <= (Operand1 >= Operand2) ? 1'b1 : 1'b0;
    default: BranchE <= 1'b0;
  endcase
end
```

