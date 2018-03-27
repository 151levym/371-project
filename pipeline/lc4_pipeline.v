/* TODO: name and PennKeys of all group members here */

`timescale 1ns / 1ps

// disable implicit wire declaration
`default_nettype none

module lc4_processor
   (input  wire        clk,                // main clock
    input wire         rst, // global reset
    input wire         gwe, // global we for single-step clock
                                    
    output wire [15:0] o_cur_pc, // Address to read from instruction memory
    input wire [15:0]  i_cur_insn, // Output of instruction memory
    output wire [15:0] o_dmem_addr, // Address to read/write from/to data memory
    input wire [15:0]  i_cur_dmem_data, // Output of data memory
    output wire        o_dmem_we, // Data memory write enable
    output wire [15:0] o_dmem_towrite, // Value to write to data memory
   
    output wire [1:0]  test_stall, // Testbench: is this is stall cycle? (don't compare the test values)
    output wire [15:0] test_cur_pc, // Testbench: program counter
    output wire [15:0] test_cur_insn, // Testbench: instruction bits
    output wire        test_regfile_we, // Testbench: register file write enable
    output wire [2:0]  test_regfile_wsel, // Testbench: which register to write in the register file 
    output wire [15:0] test_regfile_data, // Testbench: value to write into the register file
    output wire        test_nzp_we, // Testbench: NZP condition codes write enable
    output wire [2:0]  test_nzp_new_bits, // Testbench: value to write to NZP bits
    output wire        test_dmem_we, // Testbench: data memory write enable
    output wire [15:0] test_dmem_addr, // Testbench: address to read/write memory
    output wire [15:0] test_dmem_data, // Testbench: value read/writen from/to memory

    input wire [7:0]   switch_data, // Current settings of the Zedboard switches
    output wire [7:0]  led_data // Which Zedboard LEDs should be turned on?
    );
    
   assign stall = ({2{stall_3 == 1}} & 2'b11) | ({2{stall_2 == 1}} & 2'b10);
   assign stall_3 = (x_insn[15:12] == 4'b0110) & !(is_store & (x_insn[11:9] == r2sel) & (x_insn[11:9] != r1sel)) & (x_stall == 0) & (is_branch | (x_insn[11:9] == r1sel & r1re) | (x_insn[11:9] == r2sel & r2re));
   assign stall_2 = branch || x_is_control_insn & (x_stall == 0);;

   assign mx_1 = (r1sel == x_insn[11:9]) & !x_select_pc_plus_one & r1re & x_regfile_we & (x_insn[15:12] != 4'b0110)  & (x_stall != 3);
   assign wx_1 = (r1sel == m_insn[11:9]) & !m_select_pc_plus_one & m_regfile_we & (m_stall!=3);
   assign mx_2 = (r2sel == x_insn[11:9]) & !x_select_pc_plus_one & r2re & x_regfile_we & (x_insn[15:12] != 4'b0110)  & (x_stall != 3);
   assign wx_2 = (r2sel == m_insn[11:9]) & !m_select_pc_plus_one & m_regfile_we & (m_stall!=3);
   
   assign pb_1 = (((r1sel == w_insn[11:9]) & !w_select_pc_plus_one) || ((r1sel == 7) & w_select_pc_plus_one))  & r1re & w_regfile_we;
   assign pb_2 = (((r2sel == w_insn[11:9]) & !w_select_pc_plus_one) || ((r2sel == 7) & w_select_pc_plus_one))  & r2re & w_regfile_we;
   
   assign wm = (m_insn[11:9] == x_insn[11:9]) & (m_insn[15:12] == 4'b0110) & (x_insn[15:12] == 4'b0111);
   
   assign nzp_pb = (w_insn[15:12] == 4'b0110) & x_is_branch & !m_nzp_we;

   // pc wires attached to the PC register's ports
   wire [15:0]   pc;      // Current program counter (read out from pc_reg)
   wire [15:0]   next_pc; // Next program counter (you compute this and feed it into next_pc)

    // NZP REGISTERS INITIALIZATION
    Nbit_reg #(1, 0) n_reg (.in(next_n), .out(n), .clk(clk), .we(cur_nzp_we), .gwe(gwe), .rst(rst));
    Nbit_reg #(1, 0) z_reg (.in(next_z), .out(z), .clk(clk), .we(cur_nzp_we), .gwe(gwe), .rst(rst));
    Nbit_reg #(1, 0) p_reg (.in(next_p), .out(p), .clk(clk), .we(cur_nzp_we), .gwe(gwe), .rst(rst));
    
    // INITIALIZE THE TIMING REGISTERS HERE THAT TELL A STEP IN THE PIPELINE WHEN TO OPERATE
    // Program counter register, starts at 8200h at bootup
    Nbit_reg #(16, 16'h8200) PC_reg (.in(next_pc), .out(pc), .clk(clk), .we(1'b1), .gwe(gwe), .rst(rst));
    
    Nbit_reg #(16, 16'd0) D_insn (.in((i_cur_insn & {16{stall == 0}}) | (d_insn & {16{stall ==3}})), .out(d_insn), .clk(clk), .we(1), .gwe(gwe), .rst(rst));
    Nbit_reg #(16, 16'd0) D_pc (.in((pc & {16{stall == 0}}) | (d_pc & {16{stall ==3}})), .out(d_pc), .clk(clk), .we(1), .gwe(gwe), .rst(rst));
    Nbit_reg #(2, 2'b10) D_stall (.in((stall & {2{stall != 3}}) | (d_stall & {2{stall == 3}})), .out(d_stall), .clk(clk), .we(1), .gwe(gwe), .rst(rst));
    
    Nbit_reg #(16, 16'd0) X_insn (.in(d_insn & {16{(stall == 0)}}), .out(x_insn), .clk(clk), .we(1), .gwe(gwe), .rst(rst));
    Nbit_reg #(1, 1'd0) X_select_pc_plus_one (.in(select_pc_plus_one & (stall == 0)), .out(x_select_pc_plus_one), .clk(clk), .we(1), .gwe(gwe), .rst(rst));
    Nbit_reg #(16, 16'd0) X_pc (.in(d_pc & {16{(stall == 0)}}), .out(x_pc), .clk(clk), .we(1), .gwe(gwe), .rst(rst));
    Nbit_reg #(2, 2'b10) X_stall (.in((d_stall & {2{stall == 0}}) | (stall & {2{stall != 0}})), .out(x_stall), .clk(clk), .we(1), .gwe(gwe), .rst(rst));
    Nbit_reg #(16, 16'd0) X_r1_data (.in(((r1_data & {16{!mx_1 & !wx_1 & !pb_1}}) | (alu_and_pc_plus_one & {16{mx_1}}) | (m_dmem_addr & {16{wx_1 & !mx_1}} & {16{m_insn[15:12] != 4'b0110}}) | (i_cur_dmem_data & {16{wx_1 & !mx_1}} & {16{m_insn[15:12] == 4'b0110}}) | (to_write & {16{pb_1 & !wx_1 & !mx_1}}))), .out(x_r1_data), .clk(clk), .we(1), .gwe(gwe), .rst(rst));
    Nbit_reg #(16, 16'd0) X_r2_data (.in(((r2_data & {16{!mx_2 & !wx_2 & !pb_2}}) | (alu_and_pc_plus_one & {16{mx_2}}) | (m_dmem_addr & {16{wx_2 & !mx_2}} & {16{m_insn[15:12] != 4'b0110}}) | (i_cur_dmem_data & {16{wx_2 & !mx_2}} & {16{m_insn[15:12] == 4'b0110}}) | (to_write & {16{pb_2 & !wx_2 & !mx_2}}))), .out(x_r2_data), .clk(clk), .we(1), .gwe(gwe), .rst(rst));
    Nbit_reg #(1, 1'd0) X_regfile_we (.in(regfile_we & (stall == 0)), .out(x_regfile_we), .clk(clk), .we(1), .gwe(gwe), .rst(rst));
    Nbit_reg #(1, 1'd0) X_nzp_we (.in(nzp_we & (stall == 0)), .out(x_nzp_we), .clk(clk), .we(1), .gwe(gwe), .rst(rst));
    Nbit_reg #(1, 1'd0) X_is_control (.in(is_control_insn & (stall == 0)), .out(x_is_control_insn), .clk(clk), .we(1), .gwe(gwe), .rst(rst));
    Nbit_reg #(1, 1'd0) X_is_branch (.in(is_branch & (stall == 0)), .out(x_is_branch), .clk(clk), .we(1), .gwe(gwe), .rst(rst));
    
    Nbit_reg #(16, 16'd0) M_insn (.in(x_insn), .out(m_insn), .clk(clk), .we(1), .gwe(gwe), .rst(rst));
    Nbit_reg #(16, 16'd0) M_towrite (.in((x_r2_data & {16{!wm}}) | (i_cur_dmem_data & {16{wm}})), .out(o_dmem_towrite), .clk(clk), .we(1), .gwe(gwe), .rst(rst));
    Nbit_reg #(16, 16'd0) M_addr (.in(alu_and_pc_plus_one), .out(m_dmem_addr), .clk(clk), .we(1), .gwe(gwe), .rst(rst));
    Nbit_reg #(16, 16'd0) M_pc (.in(x_pc), .out(m_pc), .clk(clk), .we(1), .gwe(gwe), .rst(rst));
    Nbit_reg #(2, 2'b10) M_stall (.in(x_stall), .out(m_stall), .clk(clk), .we(1), .gwe(gwe), .rst(rst));
    Nbit_reg #(1, 1'd0) M_regfile_we (.in(x_regfile_we), .out(m_regfile_we), .clk(clk), .we(1), .gwe(gwe), .rst(rst));
    Nbit_reg #(1, 1'd0) M_nzp_we (.in(x_nzp_we), .out(m_nzp_we), .clk(clk), .we(1), .gwe(gwe), .rst(rst));
    Nbit_reg #(1, 1'd0) M_select_pc_plus_one (.in(x_select_pc_plus_one), .out(m_select_pc_plus_one), .clk(clk), .we(1), .gwe(gwe), .rst(rst));
    
    Nbit_reg #(16, 16'd0) W_insn (.in(m_insn), .out(w_insn), .clk(clk), .we(1), .gwe(gwe), .rst(rst));
    Nbit_reg #(16, 16'd0) W_alu_output (.in(m_dmem_addr), .out(w_towrite), .clk(clk), .we(1), .gwe(gwe), .rst(rst));
    Nbit_reg #(16, 16'd0) W_pc (.in(m_pc), .out(w_pc), .clk(clk), .we(1), .gwe(gwe), .rst(rst));
    Nbit_reg #(16, 16'd0) W_dmem_towrite (.in(o_dmem_towrite), .out(w_dmem_towrite), .clk(clk), .we(1), .gwe(gwe), .rst(rst));
    Nbit_reg #(2, 2'b10) W_stall (.in(m_stall), .out(w_stall), .clk(clk), .we(1), .gwe(gwe), .rst(rst));
    Nbit_reg #(1, 1'd0) W_regfile_we (.in(m_regfile_we), .out(w_regfile_we), .clk(clk), .we(1), .gwe(gwe), .rst(rst));
    Nbit_reg #(1, 1'd0) W_nzp_we (.in(m_nzp_we), .out(w_nzp_we), .clk(clk), .we(1), .gwe(gwe), .rst(rst));
    Nbit_reg #(16, 16'd0) W_dmem (.in(i_cur_dmem_data), .out(w_dmem_data), .clk(clk), .we(1), .gwe(gwe), .rst(rst));
    Nbit_reg #(1, 1'd0) W_select_pc_plus_one (.in(m_select_pc_plus_one), .out(w_select_pc_plus_one), .clk(clk), .we(1), .gwe(gwe), .rst(rst));

    wire [15:0] alu_output, r1_data, r2_data, to_write, load_data1, load_data2, load_data3, add_to_pc, x_insn, x_pc, x_r1_data, x_r2_data, d_insn,
                d_pc, m_insn, w_insn, w_towrite, m_dmem_addr, m_dmem_towrite, counter, m_pc, w_pc, alu_and_pc_plus_one,
                w_dmem_data, w_dmem_towrite, check_nzp;
    wire [1:0] stall, d_stall, x_stall, m_stall, w_stall;
    wire [2:0] r1sel, r2sel, wsel, w_wsel;
    wire r1re, r2re, regfile_we, nzp_we, select_pc_plus_one, is_load, is_store, is_branch, is_control_insn, n, z, p, next_n, next_z, next_p, branch,
          w_regfile_we, m_regfile_we, x_regfile_we, mx_1, mx_2, wx_1, wx_2, pb_1, pb_2, x_nzp_we, w_nzp_we, m_nzp_we, wm, cur_nzp_we, nzp_pb,
          curr_n, curr_z, curr_p,
          x_select_pc_plus_one, m_select_pc_plus_one, w_select_pc_plus_one, next_n_test, next_z_test, next_p_test, stall_2, stall_3, x_is_control_insn, x_is_branch;
    
    lc4_decoder h0(.insn(d_insn), .r1sel(r1sel), .r1re(r1re), .r2sel(r2sel), .r2re(r2re), 
                  .wsel(wsel), .regfile_we(regfile_we), .nzp_we(nzp_we), .select_pc_plus_one(select_pc_plus_one), 
                  .is_load(is_load), .is_store(is_store), .is_branch(is_branch), .is_control_insn(is_control_insn));
    
    lc4_regfile h1(.clk(clk), .gwe(gwe), .rst(rst), .i_rs(r1sel), .o_rs_data(r1_data), .i_rt(r2sel), .o_rt_data(r2_data),
                   .i_rd(w_wsel), .i_wdata(to_write), .i_rd_we(w_regfile_we));
    
    lc4_alu h2(.i_insn(x_insn), .i_pc(x_pc), .i_r1data(x_r1_data), .i_r2data(x_r2_data), .o_result(alu_output));
    
    assign load_data1 = w_towrite & {16{w_insn[15:12] != 4'b0110}};
    assign load_data2 = w_dmem_data & {16{w_insn[15:12] == 4'b0110}};
    assign to_write = load_data1 | load_data2;
    assign alu_and_pc_plus_one = (alu_output & {16{!x_select_pc_plus_one}}) | ((x_pc + 1) & {16{x_select_pc_plus_one}});
    assign w_wsel = (w_insn[11:9] & {3{!w_select_pc_plus_one}}) | (3'b111 & {3{w_select_pc_plus_one}});
    
    assign curr_n = (n & !nzp_pb) | (next_n & nzp_pb);
    assign curr_p = (p & !nzp_pb) | (next_p & nzp_pb);
    assign curr_z = (z & !nzp_pb) | (next_z & nzp_pb);
    
    assign branch = ((x_insn[11:9] == 1 && curr_p) | (x_insn[11:9] == 2 && curr_z) | 
    (x_insn[11:9] == 3 && (curr_z | curr_p)) | (x_insn[11:9] == 4 && curr_n) |
    (x_insn[11:9] == 5 && (curr_n | curr_p)) | (x_insn[11:9] == 6 && (curr_n | curr_z)) |
    (x_insn[11:9] == 7 && (curr_n | curr_p | curr_z))) && x_is_branch;
    
    assign next_pc = (pc & {16{stall == 3}}) | ((pc + 1) & {16{stall == 0}}) | (alu_output & {16{stall == 2}});
    assign o_cur_pc = pc;
    assign o_dmem_addr = (m_dmem_addr & {16{(m_insn[15:13] == 3'b011) & (m_stall != 3)}});
    assign o_dmem_we = (m_insn[15:12] == 4'b0111)  & (m_stall != 3);
    
    assign check_nzp = (alu_and_pc_plus_one & {16{x_nzp_we}}) | (to_write & {16{!x_nzp_we & !m_nzp_we}});
    assign cur_nzp_we = x_nzp_we | ((w_insn[15:12] == 4'b0110) & !m_nzp_we);
    
    assign next_n = $signed(check_nzp) < 0;
    assign next_z = $signed(check_nzp) == 0;
    assign next_p = $signed(check_nzp) > 0;
    
    assign next_n_test = $signed(test_regfile_data) < 0;
    assign next_z_test = $signed(test_regfile_data) == 0;
    assign next_p_test = $signed(test_regfile_data) > 0;
    
    assign test_stall = w_stall;
    assign test_cur_pc = w_pc;
    assign test_cur_insn = w_insn;
    assign test_regfile_we = w_regfile_we;
    assign test_regfile_wsel = w_wsel;
    assign test_regfile_data = (to_write);
    assign test_nzp_we = w_nzp_we;
    assign test_nzp_new_bits = {next_n_test,next_z_test,next_p_test};
    assign test_dmem_we = (w_insn[15:12] == 4'b0111) & (w_stall != 3);
    assign test_dmem_addr = (w_towrite & {16{(w_insn[15:13] == 3'b011)  & (w_stall != 3)}});
    assign test_dmem_data = (w_dmem_towrite & {16{test_dmem_we}}) | (w_dmem_data & {16{w_insn[15:12] == 4'b0110}});
   
   /*** YOUR CODE HERE ***/

   /* Add $display(...) calls in the always block below to
    * print out debug information at the end of every cycle.
    * 
    * You may also use if statements inside the always block
    * to conditionally print out information.
    *
    * You do not need to resynthesize and re-implement if this is all you change;
    * just restart the simulation.
    */
`ifndef NDEBUG
   always @(posedge gwe) begin
      // $display("%d %h %h %h %h %h", $time, pc, d_pc, x_pc, m_pc, test_cur_pc);
      // $display("%h %b", nzp_pb, w_insn);
      // $display("%h %h %h %h %h", m_dmem_addr, alu_and_pc_plus_one, o_dmem_addr, w_dmem_data, stall_3);
      // if (o_dmem_we)
      //   $display("%d STORE %h <= %h", $time, o_dmem_addr, w_dmem_data);

      // Start each $display() format string with a %d argument for time
      // it will make the output easier to read.  Use %b, %h, and %d
      // for binary, hex, and decimal output of additional variables.
      // You do not need to add a \n at the end of your format string.
      // $display("%d ...", $time);

      // Try adding a $display() call that prints out the PCs of
      // each pipeline stage in hex.  Then you can easily look up the
      // instructions in the .asm files in test_data.

      // basic if syntax:
      // if (cond) begin
      //    ...;
      //    ...;
      // end

      // Set a breakpoint on the empty $display() below
      // to step through your pipeline cycle-by-cycle.
      // You'll need to rewind the simulation to start
      // stepping from the beginning.

      // You can also simulate for XXX ns, then set the
      // breakpoint to start stepping midway through the
      // testbench.  Use the $time printouts you added above (!)
      // to figure out when your problem instruction first
      // enters the fetch stage.  Rewind your simulation,
      // run it for that many nano-seconds, then set
      // the breakpoint.

      // In the objects view, you can change the values to
      // hexadecimal by selecting all signals (Ctrl-A),
      // then right-click, and select Radix->Hexadecimal.

      // To see the values of wires within a module, select
      // the module in the hierarchy in the "Scopes" pane.
      // The Objects pane will update to display the wires
      // in that module.

      //$display(); 
   end
`endif
endmodule
