# 5-Stage Pipelined RISC-V (RV32I subset) CPU: design, verification, chip layout

One project that shows three skills: **RTL design**, **verification**, **physical design (RTL to layout)**.

## What is already done (tested)

- 5-stage pipeline: Fetch, Decode, Execute, Memory, Write-back
- Handles all 3 hazard types:
  - **Data hazard** : forwarding (EX/MEM and MEM/WB into EX), plus register-file write-through
  - **Load-use hazard** : 1-cycle stall
  - **Branch/jump** : resolved in EX, wrong instructions flushed (2-cycle penalty)
- Instructions: `add sub and or xor slt sll srl sra` `addi andi ori xori slti slli srli srai` `lw sw` `beq bne` `jal` `lui`
- Verification:
  - Directed test (`programs/test1.s`) covering each hazard on purpose
  - Python reference model (`tools/riscv.py`): CPU result must match it exactly
  - Random test generator: 300 random programs passed
  - Bug-injection check: I removed the load-use stall, a forwarding path, the branch flush, and swapped beq/bne. Tests caught all 4.
- Directed test result: 65 instructions in 93 cycles (CPI about 1.43)
- Yosys synthesis runs with no errors

## What is NOT done / not tested by me

- **OpenLane was not run.** `openlane/config.json` is a starting point. You must run it and fix any config errors yourself.
- Not supported: byte/half loads and stores, `sltu`, `auipc`, `jalr`, `blt/bge`, CSRs, interrupts. So it cannot run compiled C code yet.
- Not checked with the official RISC-V compliance suite.
- Unused register fields can cause an extra, harmless stall (e.g. `lui` after a load).

## Folder layout

```
rtl/        alu.v  regfile.v  riscv_core.v     (the design; goes to OpenLane)
tb/         tb_core.v                          (testbench, memories live here)
tools/      riscv.py (assembler + golden model), gen_random.py
programs/   test1.s                            (directed test)
openlane/   config.json
run.sh  run_random.sh
```

## How to run (Linux or WSL on Windows)

```
sudo apt install iverilog gtkwave python3
./run.sh                    # directed test, prints PASS/FAIL and CPI
./run_random.sh 300         # 300 random programs
gtkwave build/wave.vcd      # look at the waveforms
```

## How to get the chip layout (OpenLane)

1. Install OpenLane 2 (needs Docker or Nix; follow its official docs). Use the SKY130 process.
2. `openlane openlane/config.json`
3. Open the result in KLayout. Read the reports for area, timing and power.
4. If timing fails, raise `CLOCK_PERIOD` until it passes. Then find the slowest path and explain it.

## Your work plan (about 4 weeks)

- **Week 1** : Read every line of the RTL. Draw the pipeline diagram yourself. Look at the waveform of each hazard in GTKWave.
- **Week 2** : Break the design on purpose in 5 more ways. Write what the tests do. Add one missing instruction (`blt`, `sltu` or `jalr`) to the RTL, assembler and model.
- **Week 3** : Run OpenLane. Fill in the results table below.
- **Week 4** : Pick ONE improvement and measure before/after: branch predictor, or moving branch resolution to the ID stage, or a small cache.

## Results table (fill this in, do not leave it empty)

| Item | Value |
|---|---|
| Directed test CPI | 1.43 |
| Max clock (from OpenLane) | ? |
| Cell area (um^2) | ? |
| Power (mW) | ? |
| Slowest path (what is it?) | ? |
| Random tests passed | 300 / 300 |

## Questions you must be able to answer (interviewers ask these)

- Why does a load-use hazard need a stall even with forwarding?
- Why does the register file need write-through?
- Why is the branch penalty 2 cycles? How do you make it 1?
- What is the slowest path in your layout and why?
- How do you know your tests are good? (Answer: bug injection, random tests, reference model)
- What would break if two hazards happen at the same time?

## Honest warning

If you submit this as it is and cannot explain it, it is worth nothing. The value comes from your OpenLane results, your own extension, and your ability to explain every design choice.
