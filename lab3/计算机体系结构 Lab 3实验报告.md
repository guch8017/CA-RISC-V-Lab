# 计算机体系结构 Lab 3实验报告

PB18030825 顾超

## 实验目标

* 理解提供的直接相连的Cache文件代码
* 根据直接相连的Cache，更改部分代码实现基于FIFO以及LRU替换算法的组相连Cache
* 利用Cache替换Lab 2中CPU的DataRam，并对验证CPU执行的正确性
* 对比不同替换策略实现的Cache执行代码的Cache miss率以及耗费硬件资源

## 实验环境

Vivado 2020.1

##  实验过程

### Phase 1

#### Hit并行判断

利用System Verilog for循环语句与级联或运算实现并行判断是否命中

```verilog
// 修改：
//   并行判断是否在组内
wire cache_hit;
reg [WAY_CNT - 1:0]hit;  // 将所有比较数据存入此处，用于判断命中
always @(*) begin
    for (integer i = 0; i < WAY_CNT; i++) begin
        hit[i] <= valid[set_addr][i] && cache_tags[set_addr][i] == tag_addr;
    end
end
```

#### FIFO

采用一个锁存器组存储每个组中的缓存替换顺序，每个锁存器中存储的是待替换的Cache编号，位于`WAY_CNT - 1`处的Cache将在下一次miss时被替换。

```verilog
reg [31:0]fifo_buffer[SET_SIZE][WAY_CNT]; 
assign fifo_queue_tail = fifo_buffer[set_addr][WAY_CNT - 1];
```

当Cache初始化时，对FIFO队列进行如下初始化

```verilog
for(integer i = 0; i < SET_SIZE; i++) begin
  for(integer j = 0; j < WAY_CNT; j++) begin  // 添加对WAY的RST
    dirty[i][j] = 1'b0;
    valid[i][j] = 1'b0;
    fifo_buffer[i][j] <= j;         // 初始化FIFO队列
  end
end
```

而后每当发生块替换时，对FIFO队列进行一次循环移动

```verilog
// ===== BEGIN OF FIFO UPDATE =====
// 整体循环移动一次
for(integer i=1; i<WAY_CNT; i++) begin
  fifo_buffer[set_addr][i] <= fifo_buffer[set_addr][i- 1];
end
fifo_buffer[set_addr][0] <= fifo_buffer[set_addr][WAY_CNT - 1];
// ===== END OF FIFO UPDATE ======
```

从而实现FIFO队列

#### LRU

每个组中的Cache均拥有一个记录最近访问时间的寄存器，以独热码形式记录访问时间，最低位为1的寄存器将在下一次miss时被替换

```verilog
reg [WAY_CNT - 1:0]lru_buffer[SET_SIZE][WAY_CNT];   // 独热码编码的LRU结构
reg [31:0]lru_tail;
// ====== LRU TARGET BLOCK =====
always @(*) begin
    for(integer i = 0; i < WAY_CNT; i++) begin
        if(lru_buffer[set_addr][i][0] == 1'b1) begin
            lru_tail <= i;
        end
    end
end
// ===== END OF LRU TARGET BLOCK =====
```

初始化时对LRU队列作如下初始化，保证一个组内同一位为1的有且只有一个寄存器。

```verilog
for(integer i = 0; i < SET_SIZE; i++) begin
    for(integer j = 0; j < WAY_CNT; j++) begin  // 添加对WAY的RST
        dirty[i][j] = 1'b0;
        valid[i][j] = 1'b0;
        lru_buffer[i][j] <= (1 << j);   // 初始化LRU队列
    end
end
```

与FIFO不同的是，当Cache HIT时也要对LRU队列进行更新。将原先访问时间比当前访问Cache晚的全部右移一位，比当前Cache早的不移动，命中的Cache置最高位为1，从而实现LRU策略。

```verilog
// Cache HIT 情况， 直接在IDLE状态更新LRU队列
// BEGIN OF LRU UPDATE
if(rd_req || wr_req) begin
    for (integer j = 0; j < WAY_CNT; j++) begin
        if (j != i) begin
            // 比该Cache晚访问过的Cache全部右移一位，其余不变
            if(lru_buffer[set_addr][j] > lru_buffer[set_addr][i]) begin
                lru_buffer[set_addr][j] <= lru_buffer[set_addr][j] >> 1;
            end
        end
        else begin
            // 置最新访问的数据为 WAY_CNT'b1000...0
            lru_buffer[set_addr][j] <= (1 << (WAY_CNT - 1));
        end
    end
end
// END OF LRU UPDATE
```

而当Cache miss情况，做法与FIFO类似

```verilog
// ===== BEGIN OF LRU UPDATE =====
// 按位循环右移
for(integer i=1; i<WAY_CNT; i++) begin
    if (i != lru_tail) begin  // 避免线路多赋值
        lru_buffer[set_addr][i] <= lru_buffer[set_addr][i] >> 1;
    end
    else begin
        lru_buffer[set_addr][lru_tail] <= 1 << (WAY_CNT - 1);
    end
end
// ===== END OF LRU UPDATE ======
```

#### 仿真实验验证

采用`cache_tb.v`文件进行仿真测试，当`validation_count=ffffffff`时说明验证通过。利用生成脚本生成了64个测试点的testbench文件，结果截图如下。

LRU算法：

![lru_cache_tb.png](ReportResources\LRUCacheTB.png)

FIFO 算法：

![fifo_cache_tb.png](ReportResources\FIFOCacheTB.png)

### Phase 2

修改如下代码将Cache接入到CPU中

WBSegReg.v中修改接入方式如下（由于不考虑非对齐访问此处较简易）

```verilog
cache cacheInst(
    .clk(clk),
    .rst(rst),
    .miss(DCacheMiss),               // 对CPU发出的miss信号
    .addr(A),        // 读写请求地址
    .rd_req(MemReadM),             // 读请求信号
    .rd_data(RD_raw), // 读出的数据，一次读一个word
    .wr_req(|WE),             // 写请求信号
    .wr_data(WD)      // 要写入的数据，一次写一个word
);
```

Hazard.v中添加对CacheMiss情况的Stall

```verilog
else if(DCacheMiss) begin
    {StallF, StallD, StallE, StallM, StallW} <= 5'b11111;
    {FlushF, FlushD, FlushE, FlushM, FlushW} <= 5'b00000;
end
```

Hazard.v中修改访存数据被后续指令利用的判断条件（不再区分寄存器端口）

```verilog
if((RegReadE != 0 && Rs1D == RdE && MemToRegE == 2'b01) || // 寄存器端口1 Hazard
   (RegReadE != 0 && Rs2D == RdE && MemToRegE == 2'b01))   // 寄存器端口2 Hazard
    begin
        StallF <= 1;
        StallD <= 1;
        FlushE <= 1;
        {FlushF, FlushD, StallE, StallM, FlushM, StallW, FlushW} <= 8'b0;
    end
```

#### 仿真实验验证

##### 快速排序

基于随机生成的快速排序测试数据，执行结果如下所示（从上到下对应直接相连，FIFO算法，LRU算法）

* 注：LRU算法测试时，低位块的更改未被写回到ram_cell中，故展示了从地址40开始的部分

**Direct**

![qs_direct_cpu.png](ReportResources\DirectCPUQSort.png)

**FIFO**

![qs_fifo_cpu.png](ReportResources\FIFOCPUQSort.png)

**LRU**

![qs_lru_cpu.png](ReportResources\LRUCPUQSort.png) 

##### 矩阵乘法

基于程序生成的，大小为64($8\times8$)的两个矩阵进行相乘，对结果进行对比，从上到下为FIFO算法及LRU算法，其中FIFO算法由于写入时恰好全部命中，没有块被写回主存中，故截图展示了Cache中的数据与正确数据的对比情况。

**FIFO**

![mat_fifo_cpu.png](ReportResources\FIFOCPUMat.png)

**LRU**

![mat_lru_cpu.png](ReportResources\LRUCPUMat.png)

根据仿真结果，实验结果全部正确。

## 实验结论

利用Vivado程序，我们可以查看实现我们所写的Cache共需要利用多少电路资源，对Cache部分执行仿真如下

**电路资源消耗**（所有Cache的大小均固定为$2^3\times2^3\times4=256$个WORD，数值格式为LUT/FF）：

| 算法       | 1路       | 2路       | 4路       | 8路       |
| ---------- | --------- | --------- | --------- | --------- |
| 直接相连   | 4208/9334 |           |           |           |
| FIFO组相连 | 3301/9329 | 4677/9394 | 3858/9455 | 7736/9524 |
| LRU组相连  | 3899/9335 | 3397/9434 | 4182/9525 | 7695/9705 |

根据数据可见缓存大小一致的情况下，随着组相连度的上升，资源利用率也呈现上升趋势，而LRU整体利用资源大于FIFO算法（8路时出现反常是由于Verilog无法根据组相连度直接确定需要的编码位数，故FIFO队列全部采用了32位编码，实际上完全不需要这么多，从而造成了一定的资源浪费）。

**Cache Miss率**

为统计Cache Miss率，在`WBSegReg.v`中添加如下计数器代码，并引出信号到TestBench顶层

```verilog
reg [31:0] counter = 0;
reg miss_ff = 1'b0;
always @ (posedge clk) begin
    if(miss_ff && !DCacheMiss) begin
        miss_ff <= 0;
    end
    else if(DCacheMiss) begin
        miss_ff <= 1'b1;
        counter <= counter + 1;
    end
end
```

对256个数字的快速排序统计缺失次数信息如下

| QS256   |              |              |      |       |            |             |
| ------- | ------------ | ------------ | ---- | ----- | ---------- | ----------- |
| WAY_CNT | SET_ADDR_LEN | TAG_ADDR_LEN | FIFO | LRU   | DIRECT SET | DIRECT MISS |
| 8       | 2            | 7            | 0x44 | 0x58  | 5          | 0x64        |
| 8       | 3            | 6            | 0x27 | 0x27  | 6          | 0x27        |
| 8       | 4            | 5            | 0x27 | 0x27  | 7          | 0x27        |
| 4       | 2            | 7            | 0x8a | 0xe5  | 4          | 0xd9        |
| 4       | 3            | 6            | 0x41 | 0x73  | 5          | 0x64        |
| 4       | 4            | 5            | 0x27 | 0x27  | 6          | 0x27        |
| 2       | 2            | 7            | 0xde | 0x1df | 3          | 0x14b       |
| 2       | 3            | 6            | 0x84 | 0x106 | 4          | 0xd9        |
| 2       | 4            | 5            | 0x35 | 0x74  | 5          | 0x64        |

通过对比可知，在可见范围内，快速排序FIFO替换策略普遍较LRU策略好。在保持Cache一致的情况下，性能比较为`FIFO组相连替换>直接相连>LRU组相连替换`，且该规律对于各大小的Cache以及不同的组相连度-组数组合均成立。可以认为在快速排序中采用FIFO算法是效率上最优的，且FIFO使用的硬件资源也小于LRU算法。在该规模的快排程序下，使用FIFO算法的情况下，可见当Cache大小大于$2^6\times2^3$的情况下缺失次数达到最小值$0\times27$，此时再增加Cache大小对缺失次数没有优化。而权衡电路资源，在保证Cache大小一致的情况下，降低相连度而提升组数是更好的选择，采用2路组相连，共$2^4$组是权衡两者的一个较好选择。
