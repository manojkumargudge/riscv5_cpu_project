#!/usr/bin/env python3
"""Tiny assembler + reference model (golden model) for the RV32I subset used by this core.

  python3 tools/riscv.py asm  prog.s build     -> build/prog.hex, build/expected.txt, build/info.txt
  python3 tools/riscv.py compare build/expected.txt build/rtl_regs.txt
"""
import sys, re, os
M = 0xFFFFFFFF
def s32(x):
    x &= M
    return x - (1 << 32) if x >> 31 else x

RR = {'add': (0, 0), 'sub': (0x20, 0), 'sll': (0, 1), 'slt': (0, 2), 'xor': (0, 4),
      'srl': (0, 5), 'sra': (0x20, 5), 'or': (0, 6), 'and': (0, 7)}
II = {'addi': 0, 'slti': 2, 'xori': 4, 'ori': 6, 'andi': 7}
SH = {'slli': (0, 1), 'srli': (0, 5), 'srai': (0x20, 5)}
BR = {'beq': 0, 'bne': 1}

def reg(s):
    m = re.fullmatch(r'x(\d+)', s.strip())
    n = int(m.group(1)) if m else -1
    if not 0 <= n < 32:
        raise ValueError("bad register: " + s)
    return n

def enc_i(imm, rs1, f3, rd, op):
    return ((imm & 0xFFF) << 20) | (rs1 << 15) | (f3 << 12) | (rd << 7) | op

def assemble(text):
    lines, labels, pc = [], {}, 0
    for raw in text.splitlines():
        l = raw.split('#')[0].strip()
        while ':' in l:
            lab, l = l.split(':', 1)
            labels[lab.strip()] = pc
            l = l.strip()
        if l:
            lines.append((pc, l)); pc += 4
    words = []
    for pc, l in lines:
        m, _, rest = l.partition(' ')
        a = [x.strip() for x in rest.replace('(', ',').replace(')', '').split(',')] if rest.strip() else []
        if m == 'nop':   w = enc_i(0, 0, 0, 0, 0x13)
        elif m in RR:    w = (RR[m][0] << 25) | (reg(a[2]) << 20) | (reg(a[1]) << 15) | (RR[m][1] << 12) | (reg(a[0]) << 7) | 0x33
        elif m in II:    w = enc_i(int(a[2], 0), reg(a[1]), II[m], reg(a[0]), 0x13)
        elif m in SH:    w = enc_i((SH[m][0] << 5) | (int(a[2], 0) & 31), reg(a[1]), SH[m][1], reg(a[0]), 0x13)
        elif m == 'lw':  w = enc_i(int(a[1], 0), reg(a[2]), 2, reg(a[0]), 0x03)
        elif m == 'sw':
            imm = int(a[1], 0) & 0xFFF
            w = ((imm >> 5) << 25) | (reg(a[0]) << 20) | (reg(a[2]) << 15) | (2 << 12) | ((imm & 31) << 7) | 0x23
        elif m in BR:
            o = (labels[a[2]] - pc) & 0x1FFF
            w = ((o >> 12 & 1) << 31) | ((o >> 5 & 0x3F) << 25) | (reg(a[1]) << 20) | (reg(a[0]) << 15) | \
                (BR[m] << 12) | ((o >> 1 & 0xF) << 8) | ((o >> 11 & 1) << 7) | 0x63
        elif m == 'jal':
            o = (labels[a[1]] - pc) & 0x1FFFFF
            w = ((o >> 20 & 1) << 31) | ((o >> 1 & 0x3FF) << 21) | ((o >> 11 & 1) << 20) | \
                ((o >> 12 & 0xFF) << 12) | (reg(a[0]) << 7) | 0x6F
        elif m == 'lui': w = ((int(a[1], 0) & 0xFFFFF) << 12) | (reg(a[0]) << 7) | 0x37
        else: raise ValueError("unsupported instruction: " + l)
        words.append(w & M)
    return words

def alu(f3, sub, sra, a, b):
    if f3 == 0: return a - b if sub else a + b
    if f3 == 1: return a << (b & 31)
    if f3 == 2: return int(s32(a) < s32(b))
    if f3 == 4: return a ^ b
    if f3 == 5: return (s32(a) >> (b & 31)) if sra else (a & M) >> (b & 31)
    if f3 == 6: return a | b
    if f3 == 7: return a & b
    raise ValueError("unsupported funct3")

def run(words):
    regs, mem, pc, n = [0] * 32, {}, 0, 0
    while n < 100000:
        w = words[pc >> 2]
        if w == 0x6F: break                       # jal x0, 0  == halt
        op, rd, f3 = w & 0x7F, w >> 7 & 31, w >> 12 & 7
        rs1, rs2, f7b = w >> 15 & 31, w >> 20 & 31, w >> 30 & 1
        a, b, npc, res = regs[rs1], regs[rs2], pc + 4, None
        imm_i = s32(w) >> 20
        imm_s = ((s32(w) >> 25) << 5) | (w >> 7 & 31)
        imm_b = ((s32(w) >> 31) << 12) | ((w >> 7 & 1) << 11) | ((w >> 25 & 0x3F) << 5) | ((w >> 8 & 0xF) << 1)
        imm_j = ((s32(w) >> 31) << 20) | ((w >> 12 & 0xFF) << 12) | ((w >> 20 & 1) << 11) | ((w >> 21 & 0x3FF) << 1)
        if   op == 0x33: res = alu(f3, f7b, f7b, a, b)
        elif op == 0x13: res = alu(f3, 0, f7b, a, imm_i & M)
        elif op == 0x03: res = mem.get(((a + imm_i) & M) >> 2, 0)
        elif op == 0x23: mem[((a + imm_s) & M) >> 2] = b
        elif op == 0x63:
            if (a == b) == (f3 == 0): npc = (pc + imm_b) & M
        elif op == 0x6F: res, npc = pc + 4, (pc + imm_j) & M
        elif op == 0x37: res = w & 0xFFFFF000
        else: raise ValueError("unknown opcode at pc=%d" % pc)
        if res is not None and rd: regs[rd] = res & M
        pc, n = npc, n + 1
    return regs, mem, pc, n

def cmd_asm(src, out):
    os.makedirs(out, exist_ok=True)
    words = assemble(open(src).read())
    regs, mem, halt_pc, n = run(words)
    open(f"{out}/prog.hex", "w").write("".join("%08x\n" % w for w in words))
    with open(f"{out}/expected.txt", "w") as f:
        for i in range(32): f.write("x%d %08x\n" % (i, regs[i]))
        for i in range(64): f.write("m%d %08x\n" % (i, mem.get(i, 0)))
    open(f"{out}/info.txt", "w").write("%d %d\n" % (halt_pc, n))
    print(halt_pc)

def cmd_compare(exp, got):
    rd = lambda p: dict(l.split() for l in open(p) if l.strip())
    e, g = rd(exp), rd(got)
    bad = [(k, e[k], g.get(k)) for k in e if k != 'cycles' and e[k] != g.get(k)]
    for k, a, b in bad: print("MISMATCH %s: expected %s, rtl %s" % (k, a, b))
    n = int(open(os.path.join(os.path.dirname(exp), "info.txt")).read().split()[1])
    cyc = int(g.get('cycles', 0))
    print("%s  (%d checks)  instrs=%d cycles=%d  CPI=%.2f" %
          ("FAIL" if bad else "PASS", len(e), n, cyc, cyc / n if n else 0))
    sys.exit(1 if bad else 0)

if __name__ == "__main__":
    if sys.argv[1] == "asm": cmd_asm(sys.argv[2], sys.argv[3])
    else: cmd_compare(sys.argv[2], sys.argv[3])
