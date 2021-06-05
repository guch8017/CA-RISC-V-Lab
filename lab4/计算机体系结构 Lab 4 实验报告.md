# 计算机体系结构 Lab 4 实验报告

顾超 PB18030825

## 实验目标

* 基于Lab 3的五段流水线式RISC-V CPU，添加动态分支预测器功能
* 实现BTB分支预测表
* 基于BTB实现BHT 2bit分支预测器

## 实验设计

### 数据通路

要实现分支预测器，进行部分数据通路的修改。

* NPCGenerator的PC_In端口接入从PCF改为BranchPredictor的PCPredict端口，实现预测器的功能。同时NPCGenerator在没有发生跳转的情况下直接输出PCPredict的值，原计算PCF+4的功能交由分支预测器来实现。
* Hazard与NPCGenerator的Branch有效信号改为EX段的预测失败信号

```verilog
assign PredictCorrect = (PRD == 1'b1 && BranchE == 1'b1 && PCD == BrNPC) ||     // 预测跳转，且实际跳转，且目标地址一致
                        (PRD == 1'b0 && BranchE == 1'b0);                       // 预测不跳转且实际不跳转
assign BranchFail = (BranchTypeE != `NOBRANCH) && ~PredictCorrect;              // 预测失败，需要交由Hazard处理Branch
```

* NPCGenerator的BrT输入改为BranchPC，其值由预测结果决定

```verilog
assign BranchPC = (PRD == 1'b1 && BranchE == 1'b0) ? (PCE + 4)                  // 预测跳转但实际没有跳转，下一个值为当前PC + 4
                                                    : (BrNPC);                   // 预测不跳转但实际跳转，下一个值为BrNPC
```

### BTB分支预测器

本次实现BTB预测表采用了类似Cache中直接相连的替换策略。

```verilog
    reg[31:0] pc_buffer[NUM_PC];    // Source
    reg[31:0] dst_buffer[NUM_PC];   // Destination
    reg valid[NUM_PC];              // Predictor

    wire [PC_CNT:0] pc_entry_ud;    // Branch指令所在的PC INDEX
    wire [PC_CNT:0] pc_entry_if;    // IF段PC INDEX
    assign pc_entry_ud = PCE[PC_CNT+2:2];
    assign pc_entry_if = PCF[PC_CNT+2:2];
```

每一个entry设置一有效位valid，并记录Source PC与Dst PC值。当IF段PC输入时，根据PC的低位查找对应表项，检查表项是否有效以及Source PC是否等于PCF，若一致则执行预测跳转，否则预测不跳转，输出PC+4

```verilog
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
```

当分支指令到达EX段时可以判断指令是否需要跳转。无论是否需要跳转均通知预测器有分支指令到达，并同时传入EX段PC值以及跳转目的地址，同时还传入分支决策器的计算结果。若发现表项缺失则对entry进行更新。需要注意的是该阶段BTB预测器是1bit的，故实现时直接采用了valid位作为状态机，预测不跳转与Buffer Miss时均预测不跳转。且实现时只存储成功跳转的目标地址而不存储不跳转地址，因为预测不跳转可以通过计算PCF+4来得到，无需额外存储目标地址。

```verilog
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
```

### BHT分支预测器

基于BTB预测器的基础上，对每个表项添加了一个2位的寄存器，实现2位分支预测器功能

```verilog
reg [1:0]bht_buffer[NUM_PC];    // BHT Buffer，当buffer为1x时预测命中，0x时预测不命中
```

当EX段发生分支时，若分支预测表缺失或无效时，将会根据实际执行情况重置BHT状态机，但不会再清除valid位，因为现在使用bht_buffer来作为状态机

```velocity
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
```

若分支命中则根据执行情况更新状态机

```verilog
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
```

而提供NextPC的模块与BTB基本一致，不再在此处说明。

## 实验结果

基于BTB分支预测器在执行256个数的快速排序验证CPU正确性，结果如下

![btb_qs](resources\btb_qs_tb.png)

基于BHT分支预测器在执行256个数的快速排序验证CPU正确性，结果如下

![bht_qs](resources\bht_qs_tb.png)

## 实验结论

为了进行数据统计，添加了对分支次数与预测成功次数的统计，代码如下

```verilog
// Register for statistics
reg [31:0] BranchCounter;
reg [31:0] BranchCorrectCounter;
reg DCacheFlop;

always @(posedge CPU_CLK or posedge CPU_RST) begin
    if(CPU_RST) begin
        BranchCounter <= 0;
        BranchCorrectCounter <= 0;
        DCacheFlop <= 0;
    end
    else begin
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
```

对256个数进行快速排序， 统计结果如下所示

| QuickSort-256    | Branch Count | Predict Correct Count | Correct Rate | Cycle |
| ---------------- | ------------ | --------------------- | ------------ | ----- |
| Static Predictor | 6707         | 5034                  | 0.751        | 69413 |
| BTB              | 6707         | 4792                  | 0.714        | 69899 |
| BHT              | 6707         | 5566                  | 0.830        | 68389 |

