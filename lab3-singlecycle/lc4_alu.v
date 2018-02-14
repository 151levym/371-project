/* Mara Levy
   maralevy*/

`timescale 1ns / 1ps

`default_nettype none
`include "lc4_divider.v"

module lc4_alu(input  wire [15:0] i_insn,
               input wire [15:0]  i_pc,
               input wire [15:0]  i_r1data,
               input wire [15:0]  i_r2data,
               output wire [15:0] o_result);


      wire [15:0] o_br, o_operation, o_cmp, o_jsr, o_logic, o_ldr_str, o_rti, o_const, o_shift, o_jump, o_hiconst, o_trap;
      br h0(.operation_type(i_insn[15:12]), .br_type(i_insn[11:9]), 
            .adder(i_insn[8:0]), .pc(i_pc), .o(o_br));
      operation h1(.operation_type(i_insn[15:12]), .op_type(i_insn[5:3]), 
                   .adder(i_insn[4:0]), .r1_data(i_r1data), .r2_data(i_r2data), .o(o_operation));
      compare h2(.operation_type(i_insn[15:12]), .cmp_type(i_insn[8:7]), 
                 .adder(i_insn[6:0]), .r1_data(i_r1data), .r2_data(i_r2data), .o(o_cmp));
      jsr h3(.operation_type(i_insn[15:12]), .jsr_type(i_insn[11]), 
                 .adder(i_insn[10:0]), .r1_data(i_r1data), .pc(i_pc), .o(o_jsr));
      logic h4(.operation_type(i_insn[15:12]), .logic_type(i_insn[5:3]), 
                 .adder(i_insn[4:0]), .r1_data(i_r1data), .r2_data(i_r2data), .o(o_logic));
      ldr_str h5(.operation_type(i_insn[15:12]), .adder(i_insn[5:0]), 
                 .r1_data(i_r1data), .o(o_ldr_str));
      rti h6(.operation_type(i_insn[15:12]), .r1_data(i_r1data), .o(o_rti));
      const h7(.operation_type(i_insn[15:12]), .i_const(i_insn[8:0]), .o(o_const));
      shift h8(.operation_type(i_insn[15:12]), .shift_type(i_insn[5:4]), 
               .shift_amount(i_insn[3:0]), .r1_data(i_r1data), .r2_data(i_r2data), .o(o_shift));
      jump h9(.operation_type(i_insn[15:12]), .jump_type(i_insn[11]), 
               .jump_amount(i_insn[10:0]), .r1_data(i_r1data), .pc(i_pc), .o(o_jump));
      hiconst h10(.operation_type(i_insn[15:12]), .i_hiconst(i_insn[7:0]), 
                  .r1_data(i_r1data), .o(o_hiconst));
      trap h11(.operation_type(i_insn[15:12]), .trap_amount(i_insn[8:0]), .o(o_trap));
      assign o_result = o_br | o_operation | o_cmp | o_jsr | o_logic | o_ldr_str | o_rti | o_const | o_shift | o_jump | o_hiconst | o_trap;
      //o_result = o_br | o_operation | o_cmp | o_jsr | o_logic | o_ldr_str | o_rti | o_const | o_shift | o_jump | o_hiconst | o_trap;

endmodule

module br(input wire [3:0] operation_type,
            input wire[2:0] br_type,
            input wire[8:0] adder,
            input wire[15:0] pc,
            output wire[15:0] o);
      
      wire[15:0] pc_plus_one, pc_plus_adder;
      assign pc_plus_one = pc + 1;
      assign pc_plus_adder = (pc_plus_one + {{7{adder[8]}}, adder});
      assign o = {16{(operation_type == 0)}} & pc_plus_adder;
endmodule

module operation(input wire [3:0] operation_type,
            input wire[2:0] op_type,
            input wire[4:0] adder,
            input wire[15:0] r1_data,
            input wire[15:0] r2_data,
            output wire[15:0] o);
      
      wire[15:0] plus, times, minus, div, plus_adder, remainder, quotient;
      assign plus = (r1_data + r2_data) & {16{(op_type == 0)}};
      assign times = (r1_data * r2_data) & {16{(op_type == 1)}};
      assign minus = (r1_data - r2_data) & {16{(op_type == 2)}};
      assign plus_adder = (r1_data + {{11{adder[4]}}, adder}) & {16{(op_type >= 4)}};
      
      lc4_divider h0(.i_dividend(r1_data), .i_divisor(r2_data), .o_remainder(remainder), .o_quotient(quotient));
      assign div = quotient & {16{(op_type == 3)}};
      
      assign o = (plus | times | minus | plus_adder | div) & {16{(operation_type == 1)}}; 
endmodule

module compare(input wire [3:0] operation_type,
            input wire[1:0] cmp_type,
            input wire[6:0] adder,
            input wire[15:0] r1_data,
            input wire[15:0] r2_data,
            output wire[15:0] o);
      
      wire[15:0] signed_reg, usigned_reg, signed_input, unsigned_input;
      assign signed_reg = (($signed(r1_data) > $signed(r2_data)) | 
                            {16{($signed(r1_data) < $signed(r2_data))}}) 
                          & {16{(cmp_type == 0)}};
                          
      assign usigned_reg = ((r1_data > r2_data) | 
                            {16{(r1_data < r2_data)}}) 
                          & {16{(cmp_type == 1)}};
                          
      assign signed_input = (($signed(r1_data) > $signed(adder)) | 
                            {16{($signed(r1_data) < $signed(adder))}}) 
                          & {16{(cmp_type == 2)}};
                          
      assign unsigned_input = ((r1_data > adder) | 
                            {16{(r1_data < adder)}}) 
                          & {16{(cmp_type == 3)}};
      
      assign o = (signed_reg | usigned_reg | signed_input | unsigned_input) & {16{(operation_type == 2)}}; 
endmodule

module jsr(input wire [3:0] operation_type,
            input wire[0:0] jsr_type,
            input wire[10:0] adder,
            input wire[15:0] r1_data,
            input wire[15:0] pc,
            output wire[15:0] o);
      
      wire[15:0] o_jsr, o_jsrr;
      assign o_jsrr = (r1_data) & {16{(jsr_type == 0)}};
      assign o_jsr = ((pc & 16'd32768) | (adder << 4)) & {16{(jsr_type == 1)}};
      assign o = (o_jsr | o_jsrr) & {16{(operation_type == 4)}}; 
endmodule

module logic(input wire [3:0] operation_type,
            input wire[2:0] logic_type,
            input wire[4:0] adder,
            input wire[15:0] r1_data,
            input wire[15:0] r2_data,
            output wire[15:0] o);
      
      wire[15:0] andd, nott, orr, xorr, and_with_input;
      assign andd = (r1_data & r2_data) & {16{(logic_type == 0)}};
      assign nott = ~r1_data & {16{(logic_type == 1)}};
      assign orr = (r1_data | r2_data) & {16{(logic_type == 2)}};
      assign xorr = (r1_data ^ r2_data) & {16{(logic_type == 3)}};
      assign and_with_input = (r1_data & {{11{adder[4]}}, adder}) & {16{(logic_type >= 4)}};
      assign o = (andd | orr | xorr | nott | and_with_input) & {16{(operation_type == 5)}}; 
endmodule

module ldr_str(input wire [3:0] operation_type,
            input wire[5:0] adder,
            input wire[15:0] r1_data,
            output wire[15:0] o);
      assign o = (r1_data + {{10{adder[5]}}, adder}) & {16{((operation_type == 6) || (operation_type == 7))}}; 
endmodule

module rti(input wire [3:0] operation_type,
            input wire[15:0] r1_data,
            output wire[15:0] o);
      assign o = r1_data & {16{(operation_type == 8)}}; 
endmodule

module const(input wire [3:0] operation_type,
            input wire[8:0] i_const,
            output wire[15:0] o);
      assign o = {{7{i_const[8]}}, i_const} & {16{(operation_type == 9)}}; 
endmodule

module shift(input wire [3:0] operation_type,
            input wire[1:0] shift_type,
            input wire[3:0] shift_amount,
            input wire[15:0] r1_data,
            input wire[15:0] r2_data,
            output wire[15:0] o);
      wire[15:0] sll, sra, srl, mod, remainder, quotient;
      assign sll = (r1_data << shift_amount) & {16{(shift_type == 0)}};
      assign sra = $signed(($signed(r1_data)) >>> shift_amount) & {16{(shift_type == 1)}};
      assign srl = (r1_data >> shift_amount) & {16{(shift_type == 2)}};
      
      lc4_divider h0(.i_dividend(r1_data), .i_divisor(r2_data), .o_remainder(remainder), .o_quotient(quotient));
      assign mod = remainder & {16{(shift_type == 3)}};
      
      assign o = (sll | sra | srl | mod) & {16{(operation_type == 10)}}; 
endmodule

module jump(input wire [3:0] operation_type,
            input wire[0:0] jump_type,
            input wire[10:0] jump_amount,
            input wire[15:0] r1_data,
            input wire[15:0] pc,
            output wire[15:0] o);
      wire[15:0] jmp, jmpr;
      assign jmp = r1_data & {16{(jump_type == 0)}};
      assign jmpr = (pc + 1 + {{5{jump_amount[10]}}, jump_amount}) & {16{(jump_type== 1)}};
      assign o = (jmp | jmpr) & {16{(operation_type == 12)}}; 
endmodule

module hiconst(input wire [3:0] operation_type,
            input wire[7:0] i_hiconst,
            input wire[15:0] r1_data,
            output wire[15:0] o);
      assign o = ((16'd255 & r1_data) | (i_hiconst << 8)) & {16{(operation_type == 13)}}; 
endmodule

module trap(input wire [3:0] operation_type,
            input wire[7:0] trap_amount,
            output wire[15:0] o);
      assign o = (trap_amount | 16'd32768) & {16{(operation_type == 15)}}; 
endmodule
