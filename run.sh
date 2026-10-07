#!/bin/bash
# Usage: ./run.sh [program.s]      (default: programs/test1.s)
set -e
SRC=${1:-programs/test1.s}
mkdir -p build
HALT=$(python3 tools/riscv.py asm "$SRC" build)
iverilog -g2005 -o build/sim rtl/*.v tb/tb_core.v
vvp build/sim +halt=$HALT > build/sim.log
python3 tools/riscv.py compare build/expected.txt build/rtl_regs.txt
