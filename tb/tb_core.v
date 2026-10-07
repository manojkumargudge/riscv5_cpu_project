`timescale 1ns/1ps
// Self-contained testbench. Loads build/prog.hex, runs until the halt address is fetched,
// then dumps registers + data memory so tools/riscv.py can compare with the reference model.
module tb_core;
    reg clk = 0, rst = 1;
    wire [31:0] ia, da, dw, ir, dr;
    wire        dwe;
    reg  [31:0] imem [0:1023];
    reg  [31:0] dmem [0:255];
    integer i, cycles, halt_pc, f;

    assign ir = imem[ia[11:2]];
    assign dr = dmem[da[9:2]];
    always @(posedge clk) if (dwe) dmem[da[9:2]] <= dw;

    riscv_core dut (.clk(clk), .rst(rst), .imem_addr(ia), .imem_rdata(ir),
                    .dmem_addr(da), .dmem_wdata(dw), .dmem_we(dwe), .dmem_rdata(dr));

    always #5 clk = ~clk;

    initial begin
        for (i = 0; i < 1024; i = i + 1) imem[i] = 32'h00000013;
        for (i = 0; i < 256;  i = i + 1) dmem[i] = 32'b0;
        $readmemh("build/prog.hex", imem);
        if (!$value$plusargs("halt=%d", halt_pc)) halt_pc = -1;
        $dumpfile("build/wave.vcd");
        $dumpvars(0, tb_core);

        cycles = 0;
        #22 rst = 0;
        while (ia != halt_pc && cycles < 20000) begin
            @(posedge clk);
            cycles = cycles + 1;
        end
        repeat (10) @(posedge clk);   // let the last real instructions finish

        f = $fopen("build/rtl_regs.txt", "w");
        $fdisplay(f, "cycles %0d", cycles);
        for (i = 0; i < 32; i = i + 1) $fdisplay(f, "x%0d %08x", i, dut.rf.r[i]);
        for (i = 0; i < 64; i = i + 1) $fdisplay(f, "m%0d %08x", i, dmem[i]);
        $fclose(f);
        $finish;
    end
endmodule
