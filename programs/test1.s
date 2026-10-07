# ---- 1. back-to-back dependences (forwarding) ----
addi x1, x0, 5
addi x2, x0, 7
add  x3, x1, x2        # 12  : x2 from EX/MEM, x1 from MEM/WB
sub  x4, x3, x1        # 7
and  x5, x3, x4
or   x6, x3, x4
xor  x7, x3, x4
slt  x8, x1, x2
# ---- 2. load-use hazard (stall) ----
sw   x3, 0(x0)
lw   x9, 0(x0)
add  x10, x9, x9       # needs x9 right after lw -> 1 stall
sw   x10, 4(x0)
lw   x11, 4(x0)
sw   x11, 8(x0)
# ---- 3. loop: sum 1..10, branch uses a just-computed value ----
addi x12, x0, 0
addi x13, x0, 1
addi x14, x0, 11
loop:
add  x12, x12, x13
addi x13, x13, 1
bne  x13, x14, loop    # taken 9 times, wrong-path instrs must be flushed
# ---- 4. jal + flush: x16 must stay 0 ----
jal  x15, skip
addi x16, x0, 99
addi x16, x0, 98
skip:
addi x17, x0, 1
# ---- 5. lui and shifts ----
lui  x18, 0x12345
addi x18, x18, 0x678
slli x19, x1, 4
srli x20, x18, 8
addi x21, x0, -16
srai x22, x21, 2
sra  x23, x21, x1
slti x24, x21, 0
# ---- 6. beq taken / not taken ----
beq  x1, x2, bad
beq  x1, x1, good
bad:  addi x25, x0, 111
good: addi x26, x0, 1
# ---- 7. load followed by branch that uses it ----
lw   x28, 0(x0)
beq  x28, x3, hit
addi x29, x0, 77
hit: addi x29, x29, 1
# ---- 8. writes to x0 must be ignored ----
addi x0, x0, 55
add  x27, x0, x1
done: jal x0, done
