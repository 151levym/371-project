/* Mara Levy - maralevy
 * Gabby Schwartz - schwg
 *
 * lc4_single.v
 * Implements a single-cycle data path
 *
 */

`timescale 1ns / 1ps

// disable implicit wire declaration
`default_nettype none

module lc4_processor
   (input  wire        clk,                // Main clock
    input  wire        rst,                // Global reset
    input  wire        gwe,                // Global we for single-step clock
   
    output wire [15:0] o_cur_pc,           // Address to read from instruction memory
    input  wire [15:0] i_cur_insn,         // Output of instruction memory
    output wire [15:0] o_dmem_addr,        // Address to read/write from/to data memory; SET TO 0x0000 FOR NON LOAD/STORE INSNS
    input  wire [15:0] i_cur_dmem_data,    // Output of data memory
    output wire        o_dmem_we,          // Data memory write enable
    output wire [15:0] o_dmem_towrite,     // Value to write to data memory

    // Testbench signals are used by the testbench to verify the correctness of your datapath.
    // Many of these signals simply export internal processor state for verification (such as the PC).
    // Some signals are duplicate output signals for clarity of purpose.
    //
    // Don't forget to include these in your schematic!

    output wire [1:0]  test_stall,         // Testbench: is this a stall cycle? (don't compare the test values)
    output wire [15:0] test_cur_pc,        // Testbench: program counter
    output wire [15:0] test_cur_insn,      // Testbench: instruction bits
    output wire        test_regfile_we,    // Testbench: register file write enable
    output wire [2:0]  test_regfile_wsel,  // Testbench: which register to write in the register file 
    output wire [15:0] test_regfile_data,  // Testbench: value to write into the register file
    output wire        test_nzp_we,        // Testbench: NZP condition codes write enable
    output wire [2:0]  test_nzp_new_bits,  // Testbench: value to write to NZP bits
    output wire        test_dmem_we,       // Testbench: data memory write enable
    output wire [15:0] test_dmem_addr,     // Testbench: address to read/write memory
    output wire [15:0] test_dmem_data,     // Testbench: value read/writen from/to memory
   
    // State of the zedboard switches, LCD and LEDs
    // You are welcome to use the Zedboard's LCD number display and LEDs
    // for debugging purposes, but it isn't terribly useful.  Ditto for
    // reading the switch positions from the Zedboard

    input  wire [7:0]  switch_data,        // Current settings of the Zedboard switches
    output wire [15:0] seven_segment_data, // Data to display to the Zedboard LCD
    output wire [7:0]  led_data            // Which Zedboard LEDs should be turned on?
    );
   

   /* DO NOT MODIFY THIS CODE */
   // Always execute one instruction each cycle (test_stall will get used in your pipelined processor)
   assign test_stall = 2'b0; 

   // pc wires attached to the PC register's ports
   wire [15:0]   pc;      // Current program counter (read out from pc_reg)
   wire [15:0]   next_pc; // Next program counter (you compute this and feed it into next_pc)

   // Program counter register, starts at 8200h at bootup
   Nbit_reg #(16, 16'h8200) pc_reg (.in(next_pc), .out(pc), .clk(clk), .we(1'b1), .gwe(gwe), .rst(rst));

   /* END DO NOT MODIFY THIS CODE */
   
    Nbit_reg #(1, 0) n_reg (.in(next_n), .out(n), .clk(clk), .we(nzp_we), .gwe(gwe), .rst(rst));
    Nbit_reg #(1, 0) z_reg (.in(next_z), .out(z), .clk(clk), .we(nzp_we), .gwe(gwe), .rst(rst));
    Nbit_reg #(1, 0) p_reg (.in(next_p), .out(p), .clk(clk), .we(nzp_we), .gwe(gwe), .rst(rst));
   
    wire [15:0] alu_output, r1_data, r2_data, to_write, load_data1, load_data2, load_data3, add_to_pc;
    wire [2:0] r1sel, r2sel, wsel;
    wire r1re, r2re, regfile_we, nzp_we, select_pc_plus_one, is_load, is_store, is_branch, is_control_insn, n, z, p, next_n, next_z, next_p, branch;
    
    lc4_decoder h0(.insn(i_cur_insn), .r1sel(r1sel), .r1re(r1re), .r2sel(r2sel), .r2re(r2re), 
                  .wsel(wsel), .regfile_we(regfile_we), .nzp_we(nzp_we), .select_pc_plus_one(select_pc_plus_one), 
                  .is_load(is_load), .is_store(is_store), .is_branch(is_branch), .is_control_insn(is_control_insn));
    
    lc4_regfile h1(.clk(clk), .gwe(gwe), .rst(rst), .i_rs(r1sel), .o_rs_data(r1_data), .i_rt(r2sel), .o_rt_data(r2_data),
                   .i_rd(wsel), .i_wdata(to_write), .i_rd_we(regfile_we));
    
    lc4_alu h2(.i_insn(i_cur_insn), .i_pc(pc), .i_r1data(r1_data), .i_r2data(r2_data), .o_result(alu_output));
    
    assign load_data1 = alu_output & {16{!is_load}} & {16{!select_pc_plus_one}};
    assign load_data2 = i_cur_dmem_data & {16{is_load}};
    assign load_data3 = (pc + 1) & {16{select_pc_plus_one}};
    assign to_write = load_data1 | load_data2 | load_data3;
    assign branch = ((i_cur_insn[11:9] == 1 && p) | (i_cur_insn[11:9] == 2 && z) | 
    (i_cur_insn[11:9] == 3 && (z | p)) | (i_cur_insn[11:9] == 4 && n) |
    (i_cur_insn[11:9] == 5 && (n | p)) | (i_cur_insn[11:9] == 6 && (n | z)) |
    (i_cur_insn[11:9] == 7 && (n | p | z))) && is_branch;
    assign next_pc = ((pc + 1) & {16{!is_control_insn && !branch}}) | ((alu_output) & {16{is_control_insn || branch}});
    assign o_cur_pc = clk ? 0 : pc;
    assign o_dmem_addr = (alu_output & {16{is_load}}) | (alu_output & {16{is_store}}) ;
    assign o_dmem_we = is_store;
    assign o_dmem_towrite = r2_data;
    
    assign next_n = $signed(to_write) < 0;
    assign next_z = $signed(to_write) == 0;
    assign next_p = $signed(to_write) > 0;
    
    assign test_cur_pc = pc;
    assign test_cur_insn = i_cur_insn;
    assign test_regfile_we = regfile_we;
    assign test_regfile_wsel = wsel;
    assign test_regfile_data = to_write;
    assign test_nzp_we = nzp_we;
    assign test_nzp_new_bits = {next_n,next_z,next_p};
    assign test_dmem_we = o_dmem_we;
    assign test_dmem_addr = o_dmem_addr;
    assign test_dmem_data = (r2_data & {16{is_store}}) | (i_cur_dmem_data & {16{is_load}});



   /* Add $display(...) calls in the always block below to
    * print out debug information at the end of every cycle.
    *
    * You may also use if statements inside the always block
    * to conditionally print out information.
    *
    * You do not need to resynthesize and re-implement if this is all you change;
    * just restart the simulation.
    * 
    * To disable the entire block add the statement
    * `define NDEBUG
    * to the top of your file.  We also define this symbol
    * when we run the grading scripts.
    */
`ifndef NDEBUG
   always @(posedge gwe) begin
      // $display("%d %h %h %h %h %h", $time, f_pc, d_pc, e_pc, m_pc, test_cur_pc);
      // if (o_dmem_we)
      //   $display("%d STORE %h <= %h", $time, o_dmem_addr, o_dmem_towrite);

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
      // then right-click, and select Radix->Hexadecial.

      // To see the values of wires within a module, select
      // the module in the hierarchy in the "Scopes" pane.
      // The Objects pane will update to display the wires
      // in that module.

      $display();
   end
`endif
endmodule
