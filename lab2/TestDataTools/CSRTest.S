.section .text; .align 6; .globl _start; _start: addi zero,zero, 0

# Prepare for data

li t0, 1; li t1, 2; li t2, 3; li t3, 4; li t4, 5;


# CSR RW
test_1:     # 检测CSRRW正确读取
    li gp, 1;
    li a0, 1;
    csrrw a0, 1, t0;
    nop;
    nop;
    nop;
    beq a0, zero, test_2;
    j fail;

test_2:     # Reg Forward 1
    li gp, 2;
    li a0, 1;
    csrrw a0, 2, t0;
    nop;
    nop;
    beq a0, zero, test_3;
    j fail;

test_3:     # Reg Forward 2
    li gp, 3;
    li a0, 1;
    csrrw a0, 3, t0;
    nop;
    beq a0, zero, test_4;
    j fail;

test_4:     # Reg Forward 3
    li gp, 4;
    li a0, 1;
    csrrw a0, 4, t0;
    beq a0, zero, test_5;
    j fail;

test_5:     # 检测CSRRW正确写入
    li gp, 5;
    li a0, 0;
    csrrw a1, 5, t1;
    nop;
    nop;
    nop;
    csrrw a1, 5, t0;
    beq a1, t1, test_6;
    j fail;

test_6:     # CSR Forward 1
    li gp, 6;
    li a0, 0;
    csrrw a1, 6, t1;
    nop;
    nop;
    csrrw a1, 6, t0;
    beq a1, t1, test_7;
    j fail;

test_7:     # CSR Forward 2
    li gp, 7;
    li a0, 0;
    csrrw a1, 7, t1;
    nop;
    csrrw a1, 7, t0;
    beq a1, t1, test_8;
    j fail;

test_8:     # CSR Forward 3
    li gp, 8;
    li a0, 0;
    csrrw a1, 8, t1;
    csrrw a1, 8, t0;
    beq a1, t1, test_9;
    j fail;

# CSR_RWI
test_9:     # 检测CSRRWI正确读取
    li gp, 9;
    li a1, 2;
    csrrwi a1, 9, 0;
    nop;
    nop;
    nop;
    beq a1, zero, test_10;
    j fail;

test_10:    # Forward 4
    li gp, 10;
    li a1, 2;
    csrrwi a1, 10, 0;
    nop;
    nop;
    beq a1, zero, test_11;
    j fail;

test_11:    # Forward 5
    li gp, 11;
    li a1, 2;
    csrrwi a1, 11, 0;
    nop;
    beq a1, zero, test_12;
    j fail;

test_12:    # Forward 6
    li gp, 12;
    li a1, 2;
    csrrwi a1, 12, 0;
    beq a1, zero, test_13;
    j fail;

test_13:    # 检测CSRRWI正确写入
    li gp, 13;
    csrrwi a1, 13, 5;
    nop;
    nop;
    nop;
    nop;
    csrrw a2, 13, t0;
    beq a2, t4, test_14;
    j fail;

test_14:    # Forward
    li gp, 14;
    csrrwi a1, 14, 5;
    nop;
    nop;
    nop;
    csrrw a2, 14, t0;
    beq a2, t4, test_15;
    j fail;

test_15:    # Forward
    li gp, 15;
    csrrwi a1, 15, 5;
    nop;
    nop;
    csrrw a2, 15, t0;
    beq a2, t4, test_16;
    j fail;

test_16:    # Forward
    li gp, 16;
    csrrwi a1, 16, 5;
    nop;
    csrrw a2, 16, t0;
    beq a2, t4, test_17;
    j fail;

test_17:    # Forward
    li gp, 17;
    csrrwi a1, 17, 5;
    csrrw a2, 17, t0;
    beq a2, t4, test_18;
    j fail;

test_18:    # CSRRS
    li gp, 18;
    li a3, 0x10001;
    csrrw a0, 18, a3;           # a0 = 0, csr=0x10001
    li a0, 0x0000000f;          # a0 = 0xf
    csrrs a1, 18, a0;           # a1 = 0x10001, csr = 0x1000f
    li a2, 0x00010001;          # a2 = 0x10001
    beq a1, a2, test_18_2;
    j fail;
test_18_2:
    csrrw a0, 18, a1;           # a0 = 0x1000f
    li a1, 0x1000f;             # a1 = 0x1000f
    beq a0, a1, test_19;
    j fail;

test_19:    # CSRRSI
    li gp, 19
    li a3, 0x10001;
    csrrw a0, 19, a3;  # a0 = 0, csr=0x10001
    csrrsi a1, 19, 0xf;         # a1 = 0x10001, csr=0x1000f
    li a2, 0x10001;
    beq a1, a2, test_19_2;
    j fail;
test_19_2:
    csrrw a1, 19, zero;         # a1 = 0x1000f
    li a2, 0x1000f;
    beq a1, a2, test_20;
    j fail;

test_20:    # CSRRC
    li gp, 20;
    li a3, 0x1000f;
    csrrw a0, 20, a3;  # a0 = 0, csr=0x1000f
    li a0, 0x1;                 # a0 = 0x1
    csrrc a1, 20, a0;           # a1 = 0x1000f, csr = 0x1000e
    li a2, 0x1000f;             # a2 = 0x1000f
    beq a1, a2, test_20_2;
    j fail;
test_20_2:
    csrrw a0, 20, a1;           # a0 = 0x1000e
    li a1, 0x1000e;             # a1 = 0x1000e
    beq a0, a1, test_21;
    j fail;

test_21:    # CSRRCI
    li gp, 21
    li a3, 0x1000f;
    csrrw a0, 21, a3;  # a0 = 0, csr=0x10001
    csrrci a1, 21, 0x1;         # a1 = 0x1000f, csr=0x1000e
    li a2, 0x1000f;
    beq a1, a2, test_21_2;
    j fail;
test_21_2:
    csrrw a1, 21, zero;         # a1 = 0x1000e
    li a2, 0x1000e;
    beq a1, a2, success;
    j fail;


success:
    li gp, 1;
    j success;

fail:
    nop;
    j fail;