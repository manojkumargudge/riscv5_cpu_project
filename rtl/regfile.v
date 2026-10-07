// 32 x 32 register file. x0 always reads 0.
// Write-through: if a value is being written this cycle to the register
// being read, the new value is returned (fixes the 3-instruction-apart hazard).
module regfile (
    input         clk,
    input         we,
    input  [4:0]  ra1,
    input  [4:0]  ra2,
    input  [4:0]  wa,
    input  [31:0] wd,
    output [31:0] rd1,
    output [31:0] rd2
);
    reg [31:0] r [0:31];
    integer i;
    `ifndef SYNTHESIS
    initial for (i = 0; i < 32; i = i + 1) r[i] = 32'b0;
    `endif

    always @(posedge clk)
        if (we && wa != 5'd0) r[wa] <= wd;

    assign rd1 = (ra1 == 5'd0)       ? 32'b0 :
                 (we && wa == ra1)   ? wd    : r[ra1];
    assign rd2 = (ra2 == 5'd0)       ? 32'b0 :
                 (we && wa == ra2)   ? wd    : r[ra2];
endmodule
