# 5-Stage Pipelined RISC-V (RV32I subset) CPU

I designed and verified a 5-stage pipelined RISC-V CPU in Verilog. This project covers RTL design and verification, and the design is set up for the RTL-to-layout flow.

## What I built

- A 5-stage pipeline: Fetch, Decode, Execute, Memory, Write-back
- Hazard handling for all 3 hazard types:
  - **Data hazard**: forwarding from EX/MEM and MEM/WB into EX, plus register-file write-through
  - **Load-use hazard**: a 1-cycle stall
  - **Branch/jump**: resolved in EX, with wrong-path instructions flushed (2-cycle penalty)
- Supported instructions: `add sub and or xor slt sll srl sra` `addi andi ori xori slti slli srli srai` `lw sw` `beq bne` `jal` `lui`
- Yosys synthesis runs with no errors

## How I verified it

- I wrote a directed test (`programs/test1.s`) that triggers each hazard on purpose.
- I wrote a Python reference model (`tools/riscv.py`). The CPU result must match it exactly.
- I wrote a random test generator and ran 300 random programs. All passed.
- I checked that my tests catch real bugs: I removed the load-use stall, removed a forwarding path, removed the branch flush, and swapped beq/bne. The tests caught all 4 bugs.

## Results

| Item | Value |
|---|---|
| Directed test CPI | 1.43 (65 instructions in 93 cycles) |
| Random tests passed | 300 / 300 |

## Limitations

- I have not run OpenLane yet. `openlane/config.json` is a starting point and may need fixes.
- I have not added byte/half loads and stores, `sltu`, `auipc`, `jalr`, `blt/bge`, CSRs, or interrupts. So the CPU cannot run compiled C code yet.
- I have not checked the design with the official RISC-V compliance suite.
- Unused register fields can cause an extra, harmless stall (for example, `lui` after a load).

## Next steps

- Run OpenLane on the SKY130 process and report area, timing, and power.
- Add `blt`, `sltu`, and `jalr` to the RTL, assembler, and reference model.

## Folder layout

```
rtl/        alu.v  regfile.v  riscv_core.v     (the design)
tb/         tb_core.v                          (testbench, memories live here)
tools/      riscv.py (assembler + reference model), gen_random.py
programs/   test1.s                            (directed test)
openlane/   config.json
run.sh  run_random.sh
```

## How to run (Linux or WSL on Windows)

```
sudo apt install iverilog gtkwave python3
./run.sh                    # directed test, prints PASS/FAIL and CPI
./run_random.sh 300         # 300 random programs
gtkwave build/wave.vcd      # view the waveforms
```
