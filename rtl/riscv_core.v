// 5-stage pipelined RV32I (subset) core: IF -> ID -> EX -> MEM -> WB
// Hazards:
//   * data hazards      : forwarding from EX/MEM and MEM/WB into EX
//   * load-use hazard   : 1-cycle stall (bubble inserted into EX)
//   * control hazards   : branch/jump resolved in EX, wrong-path instrs flushed (2-cycle penalty)
// Memories are OUTSIDE the core (async read, sync write) so the core alone goes through OpenLane.
module riscv_core (
    input         clk,
    input         rst,
    output [31:0] imem_addr,
    input  [31:0] imem_rdata,
    output [31:0] dmem_addr,
    output [31:0] dmem_wdata,
    output        dmem_we,
    input  [31:0] dmem_rdata
);
    localparam [31:0] NOP = 32'h00000013;   // addi x0, x0, 0

    wire        stall;
    wire        take_branch;
    wire [31:0] branch_target;

    // ---------------------------------------------------------------- IF
    reg [31:0] pc;
    assign imem_addr = pc;

    always @(posedge clk) begin
        if (rst)              pc <= 32'b0;
        else if (take_branch) pc <= branch_target;
        else if (!stall)      pc <= pc + 32'd4;
    end

    reg [31:0] id_pc, id_instr;
    always @(posedge clk) begin
        if (rst || take_branch) begin
            id_instr <= NOP;
            id_pc    <= 32'b0;
        end else if (!stall) begin
            id_instr <= imem_rdata;
            id_pc    <= pc;
        end
    end

    // ---------------------------------------------------------------- ID
    wire [6:0] opcode = id_instr[6:0];
    wire [4:0] rd     = id_instr[11:7];
    wire [2:0] f3     = id_instr[14:12];
    wire [4:0] rs1    = id_instr[19:15];
    wire [4:0] rs2    = id_instr[24:20];
    wire       f7b5   = id_instr[30];

    wire is_r   = (opcode == 7'b0110011);
    wire is_i   = (opcode == 7'b0010011);
    wire is_lw  = (opcode == 7'b0000011);
    wire is_sw  = (opcode == 7'b0100011);
    wire is_b   = (opcode == 7'b1100011);
    wire is_jal = (opcode == 7'b1101111);
    wire is_lui = (opcode == 7'b0110111);

    wire [31:0] imm_i = {{20{id_instr[31]}}, id_instr[31:20]};
    wire [31:0] imm_s = {{20{id_instr[31]}}, id_instr[31:25], id_instr[11:7]};
    wire [31:0] imm_b = {{19{id_instr[31]}}, id_instr[31], id_instr[7], id_instr[30:25], id_instr[11:8], 1'b0};
    wire [31:0] imm_u = {id_instr[31:12], 12'b0};
    wire [31:0] imm_j = {{11{id_instr[31]}}, id_instr[31], id_instr[19:12], id_instr[20], id_instr[30:21], 1'b0};

    reg [31:0] imm;
    always @* begin
        if      (is_sw)  imm = imm_s;
        else if (is_b)   imm = imm_b;
        else if (is_lui) imm = imm_u;
        else if (is_jal) imm = imm_j;
        else             imm = imm_i;
    end

    reg [3:0] actrl;
    always @* begin
        actrl = 4'd0;
        if (is_lui) actrl = 4'd6;
        else if (is_r || is_i) begin
            case (f3)
                3'b000: actrl = (is_r && f7b5) ? 4'd1 : 4'd0;
                3'b111: actrl = 4'd2;
                3'b110: actrl = 4'd3;
                3'b100: actrl = 4'd4;
                3'b010: actrl = 4'd5;
                3'b001: actrl = 4'd7;
                3'b101: actrl = f7b5 ? 4'd9 : 4'd8;
                default: actrl = 4'd0;
            endcase
        end
    end

    wire c_reg_write = is_r | is_i | is_lw | is_jal | is_lui;
    wire c_mem_read  = is_lw;
    wire c_mem_write = is_sw;
    wire c_alu_imm   = is_i | is_lw | is_sw | is_lui;

    wire [31:0] rf_rd1, rf_rd2;
    wire        wb_reg_write;
    wire [4:0]  wb_rd;
    wire [31:0] wb_data;

    regfile rf (.clk(clk), .we(wb_reg_write), .ra1(rs1), .ra2(rs2),
                .wa(wb_rd), .wd(wb_data), .rd1(rf_rd1), .rd2(rf_rd2));

    // ID/EX register
    reg [31:0] ex_pc, ex_rv1, ex_rv2, ex_imm;
    reg [4:0]  ex_rs1, ex_rs2, ex_rd;
    reg [3:0]  ex_actrl;
    reg        ex_reg_write, ex_mem_read, ex_mem_write, ex_alu_imm, ex_branch, ex_bne, ex_jal;

    // load-use hazard: instruction in EX is a load whose rd is needed by the instruction in ID
    assign stall = ex_mem_read && (ex_rd != 5'd0) && (ex_rd == rs1 || ex_rd == rs2);

    always @(posedge clk) begin
        if (rst || take_branch || stall) begin   // insert a bubble
            ex_reg_write <= 1'b0;
            ex_mem_read  <= 1'b0;
            ex_mem_write <= 1'b0;
            ex_branch    <= 1'b0;
            ex_jal       <= 1'b0;
            ex_rd        <= 5'd0;
            ex_rs1       <= 5'd0;
            ex_rs2       <= 5'd0;
        end else begin
            ex_pc        <= id_pc;
            ex_rv1       <= rf_rd1;
            ex_rv2       <= rf_rd2;
            ex_imm       <= imm;
            ex_rs1       <= rs1;
            ex_rs2       <= rs2;
            ex_rd        <= rd;
            ex_actrl     <= actrl;
            ex_reg_write <= c_reg_write;
            ex_mem_read  <= c_mem_read;
            ex_mem_write <= c_mem_write;
            ex_alu_imm   <= c_alu_imm;
            ex_branch    <= is_b;
            ex_bne       <= f3[0];
            ex_jal       <= is_jal;
        end
    end

    // ---------------------------------------------------------------- EX
    reg        mem_reg_write, mem_read, mem_write;
    reg [4:0]  mem_rd;
    reg [31:0] mem_alu, mem_store;

    reg [31:0] fa, fb;   // forwarded operands
    always @* begin
        fa = ex_rv1;
        if      (mem_reg_write && mem_rd != 5'd0 && mem_rd == ex_rs1) fa = mem_alu;
        else if (wb_reg_write  && wb_rd  != 5'd0 && wb_rd  == ex_rs1) fa = wb_data;
        fb = ex_rv2;
        if      (mem_reg_write && mem_rd != 5'd0 && mem_rd == ex_rs2) fb = mem_alu;
        else if (wb_reg_write  && wb_rd  != 5'd0 && wb_rd  == ex_rs2) fb = wb_data;
    end

    wire [31:0] alu_b = ex_alu_imm ? ex_imm : fb;
    wire [31:0] alu_y;
    alu u_alu (.a(fa), .b(alu_b), .ctrl(ex_actrl), .y(alu_y));

    wire [31:0] ex_result = ex_jal ? (ex_pc + 32'd4) : alu_y;
    wire        eq        = (fa == fb);

    assign take_branch   = ex_jal | (ex_branch & (ex_bne ? ~eq : eq));
    assign branch_target = ex_pc + ex_imm;

    // EX/MEM register
    always @(posedge clk) begin
        if (rst) begin
            mem_reg_write <= 1'b0;
            mem_read      <= 1'b0;
            mem_write     <= 1'b0;
            mem_rd        <= 5'd0;
        end else begin
            mem_reg_write <= ex_reg_write;
            mem_read      <= ex_mem_read;
            mem_write     <= ex_mem_write;
            mem_rd        <= ex_rd;
            mem_alu       <= ex_result;
            mem_store     <= fb;
        end
    end

    // ---------------------------------------------------------------- MEM
    assign dmem_addr  = mem_alu;
    assign dmem_wdata = mem_store;
    assign dmem_we    = mem_write;

    reg        wbr_reg_write;
    reg [4:0]  wbr_rd;
    reg [31:0] wbr_data;
    always @(posedge clk) begin
        if (rst) begin
            wbr_reg_write <= 1'b0;
            wbr_rd        <= 5'd0;
        end else begin
            wbr_reg_write <= mem_reg_write;
            wbr_rd        <= mem_rd;
            wbr_data      <= mem_read ? dmem_rdata : mem_alu;
        end
    end

    // ---------------------------------------------------------------- WB
    assign wb_reg_write = wbr_reg_write;
    assign wb_rd        = wbr_rd;
    assign wb_data      = wbr_data;
endmodule
