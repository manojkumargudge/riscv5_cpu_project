#!/usr/bin/env python3
"""Random program generator: python3 tools/gen_random.py SEED [N_INSTR] > prog.s
Uses only 8 registers so that dependencies (= hazards) happen all the time."""
import random, sys
seed = int(sys.argv[1]); n = int(sys.argv[2]) if len(sys.argv) > 2 else 200
random.seed(seed)
R  = ['add', 'sub', 'and', 'or', 'xor', 'slt', 'sll', 'srl', 'sra']
I  = ['addi', 'andi', 'ori', 'xori', 'slti']
SH = ['slli', 'srli', 'srai']
rg = lambda: "x%d" % random.randint(1, 8)
def alu_line():
    k = random.random()
    if k < 0.5:  return "%s %s, %s, %s" % (random.choice(R), rg(), rg(), rg())
    if k < 0.8:  return "%s %s, %s, %d" % (random.choice(I), rg(), rg(), random.randint(-60, 60))
    return "%s %s, %s, %d" % (random.choice(SH), rg(), rg(), random.randint(0, 31))
out, lab = [], 0
for r in range(1, 9):
    out.append("addi x%d, x0, %d" % (r, random.randint(-100, 100)))
cnt = 0
while cnt < n:
    k = random.random()
    if   k < 0.40: out.append(alu_line()); cnt += 1
    elif k < 0.55: out.append("lw %s, %d(x0)" % (rg(), 4 * random.randint(0, 15))); cnt += 1
    elif k < 0.70: out.append("sw %s, %d(x0)" % (rg(), 4 * random.randint(0, 15))); cnt += 1
    elif k < 0.80: out.append("lui %s, %d" % (rg(), random.randint(0, 0xFFFFF))); cnt += 1
    else:
        L = "L%d" % lab; lab += 1
        a = rg(); b = a if random.random() < 0.3 else rg()
        if k < 0.95: out.append("%s %s, %s, %s" % (random.choice(['beq', 'bne']), a, b, L))
        else:        out.append("jal %s, %s" % (rg(), L))
        for _ in range(random.randint(1, 3)): out.append(alu_line())
        out.append(L + ":"); cnt += 4
out.append("done: jal x0, done")
print("\n".join(out))
