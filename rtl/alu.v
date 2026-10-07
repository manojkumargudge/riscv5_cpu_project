// ALU. ctrl: 0 add, 1 sub, 2 and, 3 or, 4 xor, 5 slt, 6 pass-b (LUI), 7 sll, 8 srl, 9 sra
module alu (
    input      [31:0] a,
    input      [31:0] b,
    input      [3:0]  ctrl,
    output reg [31:0] y
);
    always @* begin
        case (ctrl)
            4'd0:    y = a + b;
            4'd1:    y = a - b;
            4'd2:    y = a & b;
            4'd3:    y = a | b;
            4'd4:    y = a ^ b;
            4'd5:    y = {31'b0, ($signed(a) < $signed(b))};
            4'd6:    y = b;
            4'd7:    y = a << b[4:0];
            4'd8:    y = a >> b[4:0];
            4'd9:    y = $signed(a) >>> b[4:0];
            default: y = 32'b0;
        endcase
    end
endmodule
