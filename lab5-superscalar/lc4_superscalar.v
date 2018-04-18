`timescale 1ns / 1ps

// Prevent implicit wire declaration
`default_nettype none

module lc4_processor(input wire         clk,             // main clock
                     input wire         rst,             // global reset
                     input wire         gwe,             // global we for single-step clock

                     output wire [15:0] o_cur_pc,        // address to read from instruction memory
                     input wire [15:0]  i_cur_insn_A,    // output of instruction memory (pipe A)
                     input wire [15:0]  i_cur_insn_B,    // output of instruction memory (pipe B)

                     output wire [15:0] o_dmem_addr,     // address to read/write from/to data memory
                     input wire [15:0]  i_cur_dmem_data, // contents of o_dmem_addr
                     output wire        o_dmem_we,       // data memory write enable
                     output wire [15:0] o_dmem_towrite,  // data to write to o_dmem_addr if we is set

                     // testbench signals (always emitted from the WB stage)
                     output wire [ 1:0] test_stall_A,        // is this a stall cycle?  (0: no stall,
                     output wire [ 1:0] test_stall_B,        // 1: pipeline stall, 2: branch stall, 3: load stall)

                     output wire [15:0] test_cur_pc_A,       // program counter
                     output wire [15:0] test_cur_pc_B,
                     output wire [15:0] test_cur_insn_A,     // instruction bits
                     output wire [15:0] test_cur_insn_B,
                     output wire        test_regfile_we_A,   // register file write-enable
                     output wire        test_regfile_we_B,
                     output wire [ 2:0] test_regfile_wsel_A, // which register to write
                     output wire [ 2:0] test_regfile_wsel_B,
                     output wire [15:0] test_regfile_data_A, // data to write to register file
                     output wire [15:0] test_regfile_data_B,
                     output wire        test_nzp_we_A,       // nzp register write enable
                     output wire        test_nzp_we_B,
                     output wire [ 2:0] test_nzp_new_bits_A, // new nzp bits
                     output wire [ 2:0] test_nzp_new_bits_B,
                     output wire        test_dmem_we_A,      // data memory write enable
                     output wire        test_dmem_we_B,
                     output wire [15:0] test_dmem_addr_A,    // address to read/write from/to memory
                     output wire [15:0] test_dmem_addr_B,
                     output wire [15:0] test_dmem_data_A,    // data to read/write from/to memory
                     output wire [15:0] test_dmem_data_B,

                     // zedboard switches/display/leds (ignore if you don't want to control these)
                     input  wire [ 7:0] switch_data,         // read on/off status of zedboard's 8 switches
                     output wire [ 7:0] led_data             // set on/off status of zedboard's 8 leds
                     );
    wire [15:0] pc, next_pc, fetch_pc_A, fetch_pc_B, fetch_insn_A, fetch_insn_B,
    decode_pc_A, decode_pc_B, decode_insn_A, decode_insn_B,
    d_r1data_A, d_r2data_A, d_r1data_B, d_r2data_B,
    execute_insn_A, execute_insn_B, execute_pc_A, execute_pc_B,
    x_r1data_A, x_r2data_A, x_r1data_B, x_r2data_B,
    x_alu_output_A, x_alu_output_B,
    memory_insn_A, memory_insn_B, memory_pc_A, memory_pc_B,
    write_insn_A, write_insn_B, write_pc_A, write_pc_B,
    to_write_A, to_write_B, m_alu_output_A, m_alu_output_B, 
    w_alu_output_A, w_alu_output_B, x_next_insn_A, x_next_insn_B,
    x_next_pc_A, x_next_pc_B, x_next_r1data_A, x_next_r1data_B,
    x_next_r2data_A, x_next_r2data_B,
    next_execute_insn_B, next_execute_pc_B, w_r2data_A, w_r2data_B,
    next_x_alu_output_B, m_r2data_A, m_r2data_B, w_dmem_data,
    next_x_r2data_A,next_x_r2data_B, next_x_r1data_A, next_x_r1data_B,
    m_r1data_A, m_r1data_B;
    
    wire [1:0] d_stall_A, d_stall_B, x_stall_A, x_stall_B, m_stall_A, m_stall_B, w_stall_A, w_stall_B,
    fetch_stall_A, fetch_stall_B, next_x_stall_B;
    
    wire [2:0] d_r1sel_A, d_r2sel_A, d_wsel_A, d_r1sel_B, d_r2sel_B, d_wsel_B, 
               x_wsel_A, x_wsel_B, m_wsel_A, m_wsel_B, w_wsel_A, w_wsel_B,
               x_next_wsel_A, x_next_wsel_B, x_next_stall_A, x_next_stall_B, write_nzp_from,
               next_x_wsel_B, x_r1sel_A, x_r1sel_B, x_r2sel_A, x_r2sel_B, m_r1sel_A, m_r1sel_B,
               m_r2sel_A, m_r2sel_B;
    
    wire next_n, next_z, next_p, n, z, p, cur_nzp_we, stall_1,
         d_r1re_A, d_r2re_A, d_r1re_B, d_r2re_B, d_is_control_insn_A, d_is_control_insn_B,
         d_regfile_we_A, d_regfile_we_B, d_nzp_we_A, d_nzp_we_B, x_nzp_we_A, x_nzp_we_B, m_nzp_we_A, m_nzp_we_B,
         d_select_pc_plus_one_A, d_select_pc_plus_one_B, d_is_branch_A, d_is_branch_B, w_nzp_we_A, w_nzp_we_B,
         d_is_load_A, d_is_load_B, d_is_store_A, d_is_store_B,
         x_regfile_we_A, x_regfile_we_B, w_regfile_we_A, w_regfile_we_B, m_regfile_we_A, m_regfile_we_B,
         x_next_regfile_we_A, x_next_regfile_we_B, x_is_control_insn_A, x_is_control_insn_B,
        x_next_nzp_we_A, x_next_nzp_we_B,mx_1_A_B, mx_2_A_B, mx_1_B_A,
        mx_2_B_A, mx_1_A_A, mx_2_A_A, mx_1_B_B, mx_2_B_B, wx_1_A_B, wx_2_A_B, wx_1_B_A,
        wx_2_B_A, wx_1_A_A, wx_2_A_A, wx_1_B_B, wx_2_B_B, pb_2_A_B, pb_1_B_A,
        pb_2_B_A, pb_1_A_A, pb_2_A_A, pb_1_B_B, pb_2_B_B, pb_1_A_B,
        next_n_test_A, next_z_test_A, next_p_test_A, x_is_branch_A, x_is_branch_B,
        next_n_test_B, next_z_test_B, next_p_test_B, branch_A, branch_B,
        x_is_load_A, x_is_load_B, m_is_load_A, m_is_load_B, w_is_load_A, w_is_load_B,
        next_x_regfile_we_B, next_x_nzp_we_B, next_x_is_load_B, stall_2_A, stall_2_B,
        curr_n, curr_p, curr_z, x_select_pc_plus_one_A, x_select_pc_plus_one_B,
        m_select_pc_plus_one_A, w_select_pc_plus_one_A, w_select_pc_plus_one_B,
        m_select_pc_plus_one_B, stall_3_B, stall_3_A, m_is_store_A, m_is_store_B,
        x_is_store_A, x_is_store_B, w_is_store_A, w_is_store_B, next_x_is_store_B,
        wm_A_A, wm_B_B, wm_B_A, wm_A_B, within;
    

    // NZP REGISTERS INITIALIZATION
    Nbit_reg #(1, 0) n_reg (.in(next_n), .out(n), .clk(clk), .we(write_nzp_from != 0), .gwe(gwe), .rst(rst));
    Nbit_reg #(1, 0) z_reg (.in(next_z), .out(z), .clk(clk), .we(write_nzp_from != 0), .gwe(gwe), .rst(rst));
    Nbit_reg #(1, 0) p_reg (.in(next_p), .out(p), .clk(clk), .we(write_nzp_from != 0), .gwe(gwe), .rst(rst));
    
    //We have to pick where to write to the nzp from here
    // 0 = Don't write, 1 = M_A, 2 = M_B, 3 = X_A, 4 = X_B
    assign write_nzp_from = (3'b001 & {3{m_nzp_we_A & !m_nzp_we_B & !x_nzp_we_A &!x_nzp_we_B & m_is_load_A}}) |
                            (3'b10 & {3{m_nzp_we_B & !x_nzp_we_A & !x_nzp_we_B & m_is_load_B}}) |
                            (3'b11 & {3{x_nzp_we_A & !x_nzp_we_B}}) |
                            (3'b100 & {3{x_nzp_we_B & !stall_2_A}});
    assign next_n = (($signed(i_cur_dmem_data) < 0) & ((write_nzp_from == 1) | (write_nzp_from == 2))) |
                    (($signed(x_alu_output_A) < 0) & (write_nzp_from == 3)) |
                    (($signed(x_alu_output_B) < 0) & (write_nzp_from == 4));
    assign next_z = (($signed(i_cur_dmem_data) == 0) & ((write_nzp_from == 1) | (write_nzp_from == 2))) |
                    (($signed(x_alu_output_A) == 0) & (write_nzp_from == 3)) |
                    (($signed(x_alu_output_B) == 0) & (write_nzp_from == 4));
    assign next_p = (($signed(i_cur_dmem_data) > 0) & ((write_nzp_from == 1) | (write_nzp_from == 2))) |
                    (($signed(x_alu_output_A) > 0) & (write_nzp_from == 3)) |
                    (($signed(x_alu_output_B) > 0) & (write_nzp_from == 4));
    
    // Program counter register, starts at 8200h at bootup
    Nbit_reg #(16, 16'h8200) PC_reg (.in(next_pc), .out(pc), .clk(clk), .we(1'b1), .gwe(gwe), .rst(rst));
    assign next_pc = ((pc + 2) & {16{!stall_1 & (stall_2_A == 0) & (stall_2_B == 0) & (stall_3_A == 0) & (stall_3_B == 0)}}) |
                     ((pc + 1)  & {16{(stall_1 | stall_3_B) & (stall_2_A == 0) & (stall_2_B == 0) & (stall_3_A == 0)}}) |
                     ((pc)  & {16{(stall_3_A == 1) & (stall_2_A == 0) & (stall_2_B == 0)}}) |
    									(x_alu_output_A & {16{stall_2_A == 1}}) | (x_alu_output_B & {16{(stall_2_B == 1) &
    									(stall_2_A == 0)}});
    assign o_cur_pc = pc;
    
    // FETCH STAGE
    // For ALU we will just set the values to curr, but may have to change when steall are implemented
    assign fetch_insn_A = (i_cur_insn_A & {16{!stall_1 & !stall_2_A & !stall_2_B & !stall_3_A & !stall_3_B}})  
                           | (decode_insn_B & {16{(stall_1 | stall_3_B) & !stall_3_A}}) | (decode_insn_A & {16{stall_3_A}});
    assign fetch_insn_B = (i_cur_insn_B & {16{!stall_1 & !stall_2_A & !stall_2_B & !stall_3_A & !stall_3_B}})  
                           | (i_cur_insn_A & {16{(stall_1 | stall_3_B) & !stall_3_A}}) | (decode_insn_B & {16{(stall_3_A)}});
    assign fetch_pc_A = (pc & {16{!stall_1 & !stall_2_A & !stall_2_B & !stall_3_A & !stall_3_B}}) 
                         | (decode_pc_B & {16{(stall_1 | stall_3_B) & !stall_3_A}}) | (decode_pc_A & {16{stall_3_A}});
    assign fetch_pc_B = ((pc + 1) & {16{!stall_1 & !stall_2_A & !stall_2_B & !stall_3_A & !stall_3_B}}) 
                        | (pc & {16{(stall_1 | stall_3_B) & !stall_3_A}}) | (decode_pc_B & {16{(stall_3_A)}});
    
    // DECODE Registers
    Nbit_reg #(16, 16'd0) D_insn_A (.in(fetch_insn_A), .out(decode_insn_A), .clk(clk), .we(1), .gwe(gwe), .rst(rst));
    Nbit_reg #(16, 16'd0) D_insn_B (.in(fetch_insn_B), .out(decode_insn_B), .clk(clk), .we(1), .gwe(gwe), .rst(rst));
    Nbit_reg #(16, 16'd0) D_pc_A (.in(fetch_pc_A), .out(decode_pc_A), .clk(clk), .we(1), .gwe(gwe), .rst(rst));
    Nbit_reg #(16, 16'd0) D_pc_B (.in(fetch_pc_B), .out(decode_pc_B), .clk(clk), .we(1), .gwe(gwe), .rst(rst));
    Nbit_reg #(2, 2'b10) D_stall_A (.in(fetch_stall_A), .out(d_stall_A), .clk(clk), .we(1), .gwe(gwe), .rst(rst));
    Nbit_reg #(2, 2'b10) D_stall_B (.in(fetch_stall_B), .out(d_stall_B), .clk(clk), .we(1), .gwe(gwe), .rst(rst));

    // DECODE Stage
    lc4_decoder d_A(.insn(decode_insn_A), .r1sel(d_r1sel_A), .r1re(d_r1re_A), .r2sel(d_r2sel_A), .r2re(d_r2re_A), 
                     .wsel(d_wsel_A), .regfile_we(d_regfile_we_A), .nzp_we(d_nzp_we_A), 
                     .select_pc_plus_one(d_select_pc_plus_one_A), .is_load(d_is_load_A), 
                     .is_store(d_is_store_A), .is_branch(d_is_branch_A), .is_control_insn(d_is_control_insn_A));
    lc4_decoder d_B(.insn(decode_insn_B), .r1sel(d_r1sel_B), .r1re(d_r1re_B), .r2sel(d_r2sel_B), .r2re(d_r2re_B), 
                     .wsel(d_wsel_B), .regfile_we(d_regfile_we_B), .nzp_we(d_nzp_we_B), 
                     .select_pc_plus_one(d_select_pc_plus_one_B), .is_load(d_is_load_B), 
                     .is_store(d_is_store_B), .is_branch(d_is_branch_B), .is_control_insn(d_is_control_insn_B));
    
    //Implement stalls here
    assign stall_1 = (((((d_wsel_A == d_r1sel_B) & d_r1re_B) || ((d_wsel_A == d_r2sel_B) & d_r2re_B & (!d_is_store_B))) & d_regfile_we_A) ||
    								 (d_is_branch_B & d_nzp_we_A) || ((d_is_load_A | d_is_store_A) & (d_is_load_B | d_is_store_B)) ||
    								 (d_is_load_A & d_is_branch_B)) && 
    								 ((d_stall_A == 0) && (d_stall_B == 0) && (stall_2_A == 0) && (stall_2_B == 0));
    assign stall_2_A = (branch_A || x_is_control_insn_A) && (x_stall_A == 0);
    assign stall_2_B = (branch_B || x_is_control_insn_B) && (x_stall_B == 0);
    assign stall_3_B = (((((x_wsel_A == d_r1sel_B) & d_r1re_B) || ((x_wsel_A == d_r2sel_B) & d_r2re_B & !d_is_store_B)) & x_is_load_A & (x_stall_A == 0)) ||
                       ((((x_wsel_B == d_r1sel_B) & d_r1re_B) || ((x_wsel_B == d_r2sel_B) & d_r2re_B & !d_is_store_B)) & x_is_load_B & (x_stall_B == 0)) ||
                       (d_is_branch_B & !d_nzp_we_A & ((x_is_load_B & (x_stall_B==0)) | (x_is_load_A & (x_stall_A==0) & ((x_nzp_we_B == 0) | (x_stall_B != 0)))))) &&
                       !stall_1;
    assign stall_3_A = (((((x_wsel_A == d_r1sel_A) & d_r1re_A) || ((x_wsel_A == d_r2sel_A) & d_r2re_A & !d_is_store_A)) & x_is_load_A & (x_stall_A == 0)) ||
                       ((((x_wsel_B == d_r1sel_A) & d_r1re_A) || ((x_wsel_B == d_r2sel_A) & d_r2re_A & !d_is_store_A)) & x_is_load_B & (x_stall_B == 0)) ||
                       (d_is_branch_A & ((x_is_load_B & (x_stall_B==0)) | (x_is_load_A & (x_stall_A==0) & ((x_nzp_we_B == 0) | (x_stall_B != 0))))));
    assign fetch_stall_A = ((stall_2_A | stall_2_B) ? 2'b10 : 2'b00);
    assign fetch_stall_B = ((stall_2_A | stall_2_B) ? 2'b10 : 2'b00);
    
    
    //So many bypasses here, first letter = earlier stage in bypass
    assign mx_1_A_B = (d_r1sel_A == x_wsel_B) & d_r1re_A & x_regfile_we_B & (x_stall_B == 0) & (stall_3_A == 0);
    assign mx_2_A_B = (d_r2sel_A == x_wsel_B) & d_r2re_A & x_regfile_we_B & (x_stall_B == 0) & (stall_3_A == 0);
    assign mx_1_B_A = (d_r1sel_B == x_wsel_A) & d_r1re_B & x_regfile_we_A & (x_stall_A == 0) & (stall_3_B == 0) & (stall_3_A == 0);
    assign mx_2_B_A = (d_r2sel_B == x_wsel_A) & d_r2re_B & x_regfile_we_A & (x_stall_A == 0) & (stall_3_B == 0) & (stall_3_A == 0);
    assign mx_1_A_A = (d_r1sel_A == x_wsel_A) & d_r1re_A & x_regfile_we_A & (x_stall_A == 0) & (stall_3_A == 0);
    assign mx_2_A_A = (d_r2sel_A == x_wsel_A) & d_r2re_A & x_regfile_we_A & (x_stall_A == 0) & (stall_3_A == 0);
    assign mx_1_B_B = (d_r1sel_B == x_wsel_B) & d_r1re_B & x_regfile_we_B & (x_stall_B == 0) & (stall_3_B == 0) & (stall_3_A == 0);
    assign mx_2_B_B = (d_r2sel_B == x_wsel_B) & d_r2re_B & x_regfile_we_B & (x_stall_B == 0) & (stall_3_B == 0) & (stall_3_A == 0);
    
    assign wx_1_A_B = (d_r1sel_A == m_wsel_B) & d_r1re_A & m_regfile_we_B & (m_stall_B == 0);
    assign wx_2_A_B = (d_r2sel_A == m_wsel_B) & d_r2re_A & m_regfile_we_B & (m_stall_B == 0);
    assign wx_1_B_A = (d_r1sel_B == m_wsel_A) & d_r1re_B & m_regfile_we_A & (m_stall_A == 0);
    assign wx_2_B_A = (d_r2sel_B == m_wsel_A) & d_r2re_B & m_regfile_we_A & (m_stall_A == 0);
    assign wx_1_A_A = (d_r1sel_A == m_wsel_A) & d_r1re_A & m_regfile_we_A & (m_stall_A == 0);
    assign wx_2_A_A = (d_r2sel_A == m_wsel_A) & d_r2re_A & m_regfile_we_A & (m_stall_A == 0);
    assign wx_1_B_B = (d_r1sel_B == m_wsel_B) & d_r1re_B & m_regfile_we_B & (m_stall_B == 0);
    assign wx_2_B_B = (d_r2sel_B == m_wsel_B) & d_r2re_B & m_regfile_we_B & (m_stall_B == 0);
    
    assign pb_1_A_B = (d_r1sel_A == w_wsel_B) & d_r1re_A & w_regfile_we_B & (w_stall_B == 0);
    assign pb_2_A_B = (d_r2sel_A == w_wsel_B) & d_r2re_A & w_regfile_we_B & (w_stall_B == 0);
    assign pb_1_B_A = (d_r1sel_B == w_wsel_A) & d_r1re_B & w_regfile_we_A & (w_stall_A == 0);
    assign pb_2_B_A = (d_r2sel_B == w_wsel_A) & d_r2re_B & w_regfile_we_A & (w_stall_A == 0);
    assign pb_1_A_A = (d_r1sel_A == w_wsel_A) & d_r1re_A & w_regfile_we_A & (w_stall_A == 0);
    assign pb_2_A_A = (d_r2sel_A == w_wsel_A) & d_r2re_A & w_regfile_we_A & (w_stall_A == 0);
    assign pb_1_B_B = (d_r1sel_B == w_wsel_B) & d_r1re_B & w_regfile_we_B & (w_stall_B == 0);
    assign pb_2_B_B = (d_r2sel_B == w_wsel_B) & d_r2re_B & w_regfile_we_B & (w_stall_B == 0);
    
    assign wm_A_A = x_is_store_A & m_is_load_A & (m_wsel_A == x_r2sel_A) & ((m_wsel_B != x_r2sel_A) | (m_stall_B != 0)) & (m_stall_A == 0);
    assign wm_B_B = x_is_store_B & m_is_load_B & (m_wsel_B == x_r2sel_B) & ((x_wsel_A != x_r2sel_B) | (x_stall_A != 0)) & (m_stall_B == 0);
    assign wm_A_B = x_is_store_A & m_is_load_B & (m_wsel_B == x_r2sel_A) & (m_stall_B == 0);
    assign wm_B_A = x_is_store_B & m_is_load_A & (m_wsel_A == x_r2sel_B) & ((x_wsel_A != x_r2sel_B) | (x_stall_A != 0)) & ((m_wsel_B != x_r2sel_B) | (m_stall_B != 0)) & (m_stall_A == 0);
    
    assign within = (m_r2sel_B == m_wsel_A) & m_is_store_B & m_regfile_we_A;
   
    //Register Initialization
    lc4_regfile_ss h1    (.clk(clk) , .gwe(gwe) , .rst(rst), .i_rs_A(d_r1sel_A), 
                          .o_rs_data_A(d_r1data_A), .i_rt_A(d_r2sel_A), .o_rt_data_A(d_r2data_A),
                          .i_rs_B(d_r1sel_B), .o_rs_data_B(d_r1data_B), .i_rt_B(d_r2sel_B), 
                          .o_rt_data_B(d_r2data_B), .i_rd_A(w_wsel_A),
                          .i_wdata_A(to_write_A), .i_rd_we_A(w_regfile_we_A), .i_rd_B(w_wsel_B), 
                          .i_wdata_B(to_write_B), .i_rd_we_B(w_regfile_we_B));
                          
    //Input to execute registers - so it doesn't get complicated with stalls and bypasses
    assign x_next_insn_A = decode_insn_A & {16{!stall_2_A & !stall_2_B}} & {16{!stall_3_A}};
    assign x_next_insn_B = decode_insn_B & {16{!stall_1}} & {16{!stall_2_A & !stall_2_B}} & {16{!stall_3_A & !stall_3_B}};
    assign x_next_pc_A = decode_pc_A;
    assign x_next_pc_B = decode_pc_B;
    assign x_next_r1data_A = ((d_r1data_A & {16{!(mx_1_A_B | mx_1_A_A | wx_1_A_B | wx_1_A_A | pb_1_A_B | pb_1_A_A)}}) |
                              (x_alu_output_B & {16{mx_1_A_B}}) |
                              (x_alu_output_A & {16{mx_1_A_A & !mx_1_A_B}}) |
                              (m_alu_output_B & {16{wx_1_A_B & !mx_1_A_A & !mx_1_A_B & !m_is_load_B}}) |
                              (m_alu_output_A & {16{wx_1_A_A & !wx_1_A_B & !mx_1_A_A & !mx_1_A_B & !m_is_load_A}}) |
                              (i_cur_dmem_data & {16{wx_1_A_B & !mx_1_A_A & !mx_1_A_B & m_is_load_B}}) |
                              (i_cur_dmem_data & {16{wx_1_A_A & !wx_1_A_B & !mx_1_A_A & !mx_1_A_B & m_is_load_A}}) |
                              (to_write_B & {16{pb_1_A_B & !wx_1_A_A & !wx_1_A_B & !mx_1_A_A & !mx_1_A_B}}) |
                              (to_write_A & {16{pb_1_A_A & !pb_1_A_B & !wx_1_A_A & !wx_1_A_B & !mx_1_A_A & !mx_1_A_B}}));
    assign x_next_r1data_B = ((d_r1data_B & {16{!(mx_1_B_A | mx_1_B_B | wx_1_B_A | wx_1_B_B | pb_1_B_A | pb_1_B_B)}}) |
                              (x_alu_output_B & {16{mx_1_B_B}}) |
                              (x_alu_output_A & {16{mx_1_B_A & !mx_1_B_B}}) |
                              (m_alu_output_B & {16{wx_1_B_B & !mx_1_B_A & !mx_1_B_B & !m_is_load_B}}) |
                              (m_alu_output_A & {16{wx_1_B_A & !wx_1_B_B & !mx_1_B_B & !mx_1_B_A & !m_is_load_A}}) |
                              (i_cur_dmem_data & {16{wx_1_B_B & !mx_1_B_A & !mx_1_B_B & m_is_load_B}}) |
                              (i_cur_dmem_data & {16{wx_1_B_A & !wx_1_B_B & !mx_1_B_B & !mx_1_B_A & m_is_load_A}}) |
                              (to_write_B & {16{pb_1_B_B & !wx_1_B_A & !wx_1_B_B & !mx_1_B_B & !mx_1_B_A}}) |
                              (to_write_A & {16{pb_1_B_A & !pb_1_B_B & !wx_1_B_B & !wx_1_B_A & !mx_1_B_B & !mx_1_B_A}}));
    assign x_next_r2data_A = ((d_r2data_A & {16{!(mx_2_A_B | mx_2_A_A | wx_2_A_B | wx_2_A_A | pb_2_A_B | pb_2_A_A)}}) |
                              (x_alu_output_B & {16{mx_2_A_B}}) |
                              (x_alu_output_A & {16{mx_2_A_A & !mx_2_A_B}}) |
                              (m_alu_output_B & {16{wx_2_A_B & !mx_2_A_A & !mx_2_A_B & !m_is_load_B}}) |
                              (m_alu_output_A & {16{wx_2_A_A & !wx_2_A_B & !mx_2_A_A & !mx_2_A_B & !m_is_load_A}}) |
                              (i_cur_dmem_data & {16{wx_2_A_B & !mx_2_A_A & !mx_2_A_B &  m_is_load_B}}) |
                              (i_cur_dmem_data & {16{wx_2_A_A & !wx_2_A_B & !mx_2_A_A & !mx_2_A_B & m_is_load_A}}) |
                              (to_write_B & {16{pb_2_A_B & !wx_2_A_A & !wx_2_A_B & !mx_2_A_A & !mx_2_A_B}}) |
                              (to_write_A & {16{pb_2_A_A & !pb_2_A_B & !wx_2_A_A & !wx_2_A_B & !mx_2_A_A & !mx_2_A_B}}));
    assign x_next_r2data_B = ((d_r2data_B & {16{!(mx_2_B_A | mx_2_B_B | wx_2_B_A | wx_2_B_B | pb_2_B_A | pb_2_B_B)}}) |
                              (x_alu_output_B & {16{mx_2_B_B}}) |
                              (x_alu_output_A & {16{mx_2_B_A & !mx_2_B_B}}) |
                              (m_alu_output_B & {16{wx_2_B_B & !mx_2_B_A & !mx_2_B_B & !m_is_load_B}}) |
                              (m_alu_output_A & {16{wx_2_B_A & !wx_2_B_B & !mx_2_B_B & !mx_2_B_A & !m_is_load_A}}) |
                              (i_cur_dmem_data & {16{wx_2_B_B & !mx_2_B_A & !mx_2_B_B & m_is_load_B}}) |
                              (i_cur_dmem_data & {16{wx_2_B_A & !wx_2_B_B & !mx_2_B_B & !mx_2_B_A & m_is_load_A}}) |
                              (to_write_B & {16{pb_2_B_B & !wx_2_B_A & !wx_2_B_B & !mx_2_B_B & !mx_2_B_A}}) |
                              (to_write_A & {16{pb_2_B_A & !pb_2_B_B & !wx_2_B_B & !wx_2_B_A & !mx_2_B_B & !mx_2_B_A}}));
    assign x_next_regfile_we_A = d_regfile_we_A & (stall_2_A == 0) & (stall_2_B == 0) & (d_stall_A == 0) & !stall_3_A;
    assign x_next_regfile_we_B = d_regfile_we_B & !stall_1 & !stall_2_A & !stall_2_B & (d_stall_B == 0) & !stall_3_A & !stall_3_B;
    assign x_next_nzp_we_A = d_nzp_we_A & !stall_2_A & !stall_2_B & (d_stall_A == 0) & !stall_3_A;
    assign x_next_nzp_we_B = d_nzp_we_B & !stall_1 & (stall_2_A == 0) & !stall_2_B & (d_stall_B == 0) & !stall_3_A & !stall_3_B;
    assign x_next_wsel_A = d_wsel_A;
    assign x_next_wsel_B = d_wsel_B;
    assign x_next_stall_A = ({2{stall_3_A & !stall_2_A & !stall_2_B}} & 2'b11) | ({2{(stall_2_A | stall_2_B)}} & 2'b10) 
                            | ({2{!(stall_2_A | stall_2_B | stall_3_A)}} & d_stall_A);
    assign x_next_stall_B = ({2{(stall_3_B) & !stall_1 & !stall_2_A & !stall_2_B & !stall_3_A}} & 2'b11) | ({2{(stall_2_A | stall_2_B)}} & 2'b10) 
                            | ((!(stall_2_A | stall_2_B) & (stall_3_A | stall_1)) ? 2'b01 : d_stall_B);
   
    //EXECUTE Registers
    Nbit_reg #(16, 16'd0) X_insn_A (.in(x_next_insn_A), .out(execute_insn_A), .clk(clk), .we(1), .gwe(gwe), .rst(rst));
    Nbit_reg #(16, 16'd0) X_insn_B (.in(x_next_insn_B), .out(execute_insn_B), .clk(clk), .we(1), .gwe(gwe), .rst(rst));
    Nbit_reg #(16, 16'd0) X_pc_A (.in(x_next_pc_A), .out(execute_pc_A), .clk(clk), .we(1), .gwe(gwe), .rst(rst));
    Nbit_reg #(16, 16'd0) X_pc_B (.in(x_next_pc_B), .out(execute_pc_B), .clk(clk), .we(1), .gwe(gwe), .rst(rst));
    Nbit_reg #(16, 1'd0) X_r1data_A (.in(x_next_r1data_A), .out(x_r1data_A), .clk(clk), .we(1), .gwe(gwe), .rst(rst));
    Nbit_reg #(16, 1'd0) X_r1data_B (.in(x_next_r1data_B), .out(x_r1data_B), .clk(clk), .we(1), .gwe(gwe), .rst(rst));
    Nbit_reg #(16, 1'd0) X_r2data_A (.in(x_next_r2data_A), .out(x_r2data_A), .clk(clk), .we(1), .gwe(gwe), .rst(rst));
    Nbit_reg #(16, 1'd0) X_r2data_B (.in(x_next_r2data_B), .out(x_r2data_B), .clk(clk), .we(1), .gwe(gwe), .rst(rst));
    Nbit_reg #(1, 1'd0) X_regfile_we_A (.in(x_next_regfile_we_A), .out(x_regfile_we_A), .clk(clk), .we(1), .gwe(gwe), .rst(rst));
    Nbit_reg #(1, 1'd0) X_regfile_we_B (.in(x_next_regfile_we_B), .out(x_regfile_we_B), .clk(clk), .we(1), .gwe(gwe), .rst(rst));
    Nbit_reg #(1, 1'd0) X_nzp_we_A (.in(x_next_nzp_we_A), .out(x_nzp_we_A), .clk(clk), .we(1), .gwe(gwe), .rst(rst));
    Nbit_reg #(1, 1'd0) X_nzp_we_B (.in(x_next_nzp_we_B), .out(x_nzp_we_B), .clk(clk), .we(1), .gwe(gwe), .rst(rst));
    Nbit_reg #(1, 1'd0) X_ld_A (.in(d_is_load_A), .out(x_is_load_A), .clk(clk), .we(1), .gwe(gwe), .rst(rst));
    Nbit_reg #(1, 1'd0) X_ld_B (.in(d_is_load_B & !stall_1), .out(x_is_load_B), .clk(clk), .we(1), .gwe(gwe), .rst(rst));
    Nbit_reg #(1, 1'd0) X_str_A (.in(d_is_store_A), .out(x_is_store_A), .clk(clk), .we(1), .gwe(gwe), .rst(rst));
    Nbit_reg #(1, 1'd0) X_str_B (.in(d_is_store_B & !stall_1), .out(x_is_store_B), .clk(clk), .we(1), .gwe(gwe), .rst(rst));
    Nbit_reg #(1, 1'd0) X_branch_A (.in(d_is_branch_A), .out(x_is_branch_A), .clk(clk), .we(1), .gwe(gwe), .rst(rst));
    Nbit_reg #(1, 1'd0) X_branch_B (.in(d_is_branch_B & !stall_1), .out(x_is_branch_B), .clk(clk), .we(1), .gwe(gwe), .rst(rst));
    Nbit_reg #(1, 1'd0) X_pc_plus_one_A (.in(d_select_pc_plus_one_A), .out(x_select_pc_plus_one_A), .clk(clk), .we(1), .gwe(gwe), .rst(rst));
    Nbit_reg #(1, 1'd0) X_pc_plus_one_B (.in(d_select_pc_plus_one_B & !stall_1), .out(x_select_pc_plus_one_B), .clk(clk), .we(1), .gwe(gwe), .rst(rst));
    Nbit_reg #(1, 1'd0) X_control_A (.in(d_is_control_insn_A), .out(x_is_control_insn_A), .clk(clk), .we(1), .gwe(gwe), .rst(rst));
    Nbit_reg #(1, 1'd0) X_control_B (.in(d_is_control_insn_B & !stall_1), .out(x_is_control_insn_B), .clk(clk), .we(1), .gwe(gwe), .rst(rst));
    Nbit_reg #(3, 3'd0) X_wsel_A (.in(x_next_wsel_A), .out(x_wsel_A), .clk(clk), .we(1), .gwe(gwe), .rst(rst));
    Nbit_reg #(3, 3'd0) X_wsel_B (.in(x_next_wsel_B), .out(x_wsel_B), .clk(clk), .we(1), .gwe(gwe), .rst(rst));
    Nbit_reg #(3, 3'd0) X_r1sel_A (.in(d_r1sel_A), .out(x_r1sel_A), .clk(clk), .we(1), .gwe(gwe), .rst(rst));
    Nbit_reg #(3, 3'd0) X_r1sel_B (.in(d_r1sel_B), .out(x_r1sel_B), .clk(clk), .we(1), .gwe(gwe), .rst(rst));
    Nbit_reg #(3, 3'd0) X_r2sel_A (.in(d_r2sel_A), .out(x_r2sel_A), .clk(clk), .we(1), .gwe(gwe), .rst(rst));
    Nbit_reg #(3, 3'd0) X_r2sel_B (.in(d_r2sel_B), .out(x_r2sel_B), .clk(clk), .we(1), .gwe(gwe), .rst(rst));
    Nbit_reg #(2, 2'b10) X_stall_A (.in(x_next_stall_A), .out(x_stall_A), .clk(clk), .we(1), .gwe(gwe), .rst(rst));
    Nbit_reg #(2, 2'b10) X_stall_B (.in(x_next_stall_B), .out(x_stall_B), .clk(clk), .we(1), .gwe(gwe), .rst(rst));
    
    //EXECUTE Stage
    lc4_alu ALU_A(.i_insn(execute_insn_A), .i_pc(execute_pc_A), 
                  .i_r1data(x_r1data_A), .i_r2data(x_r2data_A), .o_result(x_alu_output_A));
    lc4_alu ALU_B(.i_insn(execute_insn_B), .i_pc(execute_pc_B), 
                  .i_r1data(x_r1data_B), .i_r2data(x_r2data_B), .o_result(x_alu_output_B));
    
    //Figure out if we are branching here
    // Will have to change this when you have to pass back nzp (but not an issue before load)
    assign curr_n = n;
    assign curr_p = p;
    assign curr_z = z;
    
    assign branch_A = ((execute_insn_A[11:9] == 1 && curr_p) | (execute_insn_A[11:9] == 2 && curr_z) | 
    (execute_insn_A[11:9] == 3 && (curr_z | curr_p)) | (execute_insn_A[11:9] == 4 && curr_n) |
    (execute_insn_A[11:9] == 5 && (curr_n | curr_p)) | (execute_insn_A[11:9] == 6 && (curr_n | curr_z)) |
    (execute_insn_A[11:9] == 7 && (curr_n | curr_p | curr_z))) && x_is_branch_A;
    
    assign branch_B = ((execute_insn_B[11:9] == 1 && curr_p) | (execute_insn_B[11:9] == 2 && curr_z) | 
    (execute_insn_B[11:9] == 3 && (curr_z | curr_p)) | (execute_insn_B[11:9] == 4 && curr_n) |
    (execute_insn_B[11:9] == 5 && (curr_n | curr_p)) | (execute_insn_B[11:9] == 6 && (curr_n | curr_z)) |
    (execute_insn_B[11:9] == 7 && (curr_n | curr_p | curr_z))) && x_is_branch_B && !branch_A;
    
    // Solve for next values to be fed into memory in case of a branch stall
    assign next_execute_insn_B = execute_insn_B;
    assign next_execute_pc_B = execute_pc_B;
    assign next_x_regfile_we_B = x_regfile_we_B  & (stall_2_A == 0);
    assign next_x_nzp_we_B = x_nzp_we_B & (stall_2_A == 0);
    assign next_x_alu_output_B = x_alu_output_B;
    assign next_x_wsel_B = x_wsel_B;
    assign next_x_stall_B = ({2{(stall_2_A == 1)}} & 2'b10) | ({2{(stall_2_A == 0)}} & x_stall_B);
    assign next_x_is_load_B = x_is_load_B & (stall_2_A == 0);
    assign next_x_is_store_B = x_is_store_B & (stall_2_A == 0);
    
    assign next_x_r2data_A = (x_r2data_A & {16{!wm_A_A & !wm_A_B}}) | 
                             (i_cur_dmem_data & {16{wm_A_A | wm_A_B}});
    assign next_x_r2data_B = (x_r2data_B & {16{!wm_B_A & !wm_B_B}}) | 
                             (i_cur_dmem_data & {16{(wm_B_B | wm_B_A)}});
                             
    //assign next_x_r1data_A = (x_r1data_A & {16{!wm_A_A & !wm_A_B}}) | 
                             //(i_cur_dmem_data & {16{wm_A_A | wm_A_B}});
    //assign next_x_r1data_B = (x_r1data_B & {16{!wm_B_A & !wm_B_B}}) | 
                             //(i_cur_dmem_data & {16{wm_B_B | wm_B_A}});
                  
    // MEMORY Registers
    Nbit_reg #(16, 16'd0) M_insn_A (.in(execute_insn_A), .out(memory_insn_A), .clk(clk), .we(1), .gwe(gwe), .rst(rst));
    Nbit_reg #(16, 16'd0) M_insn_B (.in(next_execute_insn_B), .out(memory_insn_B), .clk(clk), .we(1), .gwe(gwe), .rst(rst));
    Nbit_reg #(16, 16'd0) M_pc_A (.in(execute_pc_A), .out(memory_pc_A), .clk(clk), .we(1), .gwe(gwe), .rst(rst));
    Nbit_reg #(16, 16'd0) M_pc_B (.in(next_execute_pc_B), .out(memory_pc_B), .clk(clk), .we(1), .gwe(gwe), .rst(rst));
    Nbit_reg #(1, 1'd0) M_regfile_we_A (.in(x_regfile_we_A), .out(m_regfile_we_A), .clk(clk), .we(1), .gwe(gwe), .rst(rst));
    Nbit_reg #(1, 1'd0) M_regfile_we_B (.in(next_x_regfile_we_B), .out(m_regfile_we_B), .clk(clk), .we(1), .gwe(gwe), .rst(rst));
    Nbit_reg #(1, 1'd0) M_nzp_we_A (.in(x_nzp_we_A), .out(m_nzp_we_A), .clk(clk), .we(1), .gwe(gwe), .rst(rst));
    Nbit_reg #(1, 1'd0) M_nzp_we_B (.in(next_x_nzp_we_B), .out(m_nzp_we_B), .clk(clk), .we(1), .gwe(gwe), .rst(rst));
    Nbit_reg #(16, 16'd0) M_alu_output_A (.in(x_alu_output_A), .out(m_alu_output_A), .clk(clk), .we(1), .gwe(gwe), .rst(rst));
    Nbit_reg #(16, 16'd0) M_alu_output_B (.in(next_x_alu_output_B), .out(m_alu_output_B), .clk(clk), .we(1), .gwe(gwe), .rst(rst));
    Nbit_reg #(3, 3'd0) M_wsel_A (.in(x_wsel_A), .out(m_wsel_A), .clk(clk), .we(1), .gwe(gwe), .rst(rst));
    Nbit_reg #(3, 3'd0) M_wsel_B (.in(next_x_wsel_B), .out(m_wsel_B), .clk(clk), .we(1), .gwe(gwe), .rst(rst));
    Nbit_reg #(2, 2'b10) M_stall_A (.in(x_stall_A), .out(m_stall_A), .clk(clk), .we(1), .gwe(gwe), .rst(rst));
    Nbit_reg #(2, 2'b10) M_stall_B (.in(next_x_stall_B), .out(m_stall_B), .clk(clk), .we(1), .gwe(gwe), .rst(rst));
    Nbit_reg #(16, 16'd0) M_r2data_A (.in(next_x_r2data_A), .out(m_r2data_A), .clk(clk), .we(1), .gwe(gwe), .rst(rst));
    Nbit_reg #(16, 16'd0) M_r2data_B (.in(next_x_r2data_B), .out(m_r2data_B), .clk(clk), .we(1), .gwe(gwe), .rst(rst));
    Nbit_reg #(3, 3'd0) M_r1sel_A (.in(x_r1sel_A), .out(m_r1sel_A), .clk(clk), .we(1), .gwe(gwe), .rst(rst));
    Nbit_reg #(3, 3'd0) M_r1sel_B (.in(x_r1sel_B), .out(m_r1sel_B), .clk(clk), .we(1), .gwe(gwe), .rst(rst));
    Nbit_reg #(3, 3'd0) M_r2sel_A (.in(x_r2sel_A), .out(m_r2sel_A), .clk(clk), .we(1), .gwe(gwe), .rst(rst));
    Nbit_reg #(3, 3'd0) M_r2sel_B (.in(x_r2sel_B), .out(m_r2sel_B), .clk(clk), .we(1), .gwe(gwe), .rst(rst));
    //Nbit_reg #(16, 1'd0) M_r1data_A (.in(next_x_r1data_A), .out(m_r1data_A), .clk(clk), .we(1), .gwe(gwe), .rst(rst));
    //Nbit_reg #(16, 1'd0) M_r1data_B (.in(next_x_r1data_B), .out(m_r1data_B), .clk(clk), .we(1), .gwe(gwe), .rst(rst));
    Nbit_reg #(1, 1'd0) M_ld_A (.in(x_is_load_A), .out(m_is_load_A), .clk(clk), .we(1), .gwe(gwe), .rst(rst));
    Nbit_reg #(1, 1'd0) M_ld_B (.in(next_x_is_load_B), .out(m_is_load_B), .clk(clk), .we(1), .gwe(gwe), .rst(rst));
    Nbit_reg #(1, 1'd0) M_str_A (.in(x_is_store_A), .out(m_is_store_A), .clk(clk), .we(1), .gwe(gwe), .rst(rst));
    Nbit_reg #(1, 1'd0) M_str_B (.in(next_x_is_store_B), .out(m_is_store_B), .clk(clk), .we(1), .gwe(gwe), .rst(rst));
    Nbit_reg #(1, 1'd0) M_pc_plus_one_A (.in(x_select_pc_plus_one_A), .out(m_select_pc_plus_one_A), .clk(clk), .we(1), .gwe(gwe), .rst(rst));
    Nbit_reg #(1, 1'd0) M_pc_plus_one_B (.in(x_select_pc_plus_one_B), .out(m_select_pc_plus_one_B), .clk(clk), .we(1), .gwe(gwe), .rst(rst));

    // MEMORY Stage
    assign o_dmem_addr = (m_alu_output_A & {16{(m_is_load_A | m_is_store_A) & (m_stall_A == 0)}}) |  (m_alu_output_B & {16{(m_is_load_B | m_is_store_B) & (m_stall_B == 0)}});
    assign o_dmem_we = (m_is_store_A & (m_stall_A == 0)) | (m_is_store_B & (m_stall_B == 0));
    assign o_dmem_towrite = (m_alu_output_A & {16{m_is_store_B & within}}) | (m_r2data_A & {16{m_is_store_A}}) |  (m_r2data_B & {16{m_is_store_B & !within}});
    
    // WRITE Registers
    Nbit_reg #(16, 16'd0) W_insn_A (.in(memory_insn_A), .out(write_insn_A), .clk(clk), .we(1), .gwe(gwe), .rst(rst));
    Nbit_reg #(16, 16'd0) W_insn_B (.in(memory_insn_B), .out(write_insn_B), .clk(clk), .we(1), .gwe(gwe), .rst(rst));
    Nbit_reg #(16, 16'd0) W_pc_A (.in(memory_pc_A), .out(write_pc_A), .clk(clk), .we(1), .gwe(gwe), .rst(rst));
    Nbit_reg #(16, 16'd0) W_pc_B (.in(memory_pc_B), .out(write_pc_B), .clk(clk), .we(1), .gwe(gwe), .rst(rst));
    Nbit_reg #(1, 1'd0) W_regfile_we_A (.in(m_regfile_we_A), .out(w_regfile_we_A), .clk(clk), .we(1), .gwe(gwe), .rst(rst));
    Nbit_reg #(1, 1'd0) W_regfile_we_B (.in(m_regfile_we_B), .out(w_regfile_we_B), .clk(clk), .we(1), .gwe(gwe), .rst(rst));
    Nbit_reg #(16, 16'd0) W_alu_output_A (.in(m_alu_output_A), .out(w_alu_output_A), .clk(clk), .we(1), .gwe(gwe), .rst(rst));
    Nbit_reg #(16, 16'd0) W_alu_output_B (.in(m_alu_output_B), .out(w_alu_output_B), .clk(clk), .we(1), .gwe(gwe), .rst(rst));
    Nbit_reg #(1, 1'd0) W_nzp_we_A (.in(m_nzp_we_A), .out(w_nzp_we_A), .clk(clk), .we(1), .gwe(gwe), .rst(rst));
    Nbit_reg #(1, 1'd0) W_nzp_we_B (.in(m_nzp_we_B), .out(w_nzp_we_B), .clk(clk), .we(1), .gwe(gwe), .rst(rst));
    Nbit_reg #(3, 3'd0) W_wsel_A (.in(m_wsel_A), .out(w_wsel_A), .clk(clk), .we(1), .gwe(gwe), .rst(rst));
    Nbit_reg #(3, 3'd0) W_wsel_B (.in(m_wsel_B), .out(w_wsel_B), .clk(clk), .we(1), .gwe(gwe), .rst(rst));
    Nbit_reg #(2, 2'd10) W_stall_A (.in(m_stall_A), .out(w_stall_A), .clk(clk), .we(1), .gwe(gwe), .rst(rst));
    Nbit_reg #(2, 2'd10) W_stall_B (.in(m_stall_B), .out(w_stall_B), .clk(clk), .we(1), .gwe(gwe), .rst(rst));
    Nbit_reg #(16, 16'd0) W_r2data_A (.in(m_r2data_A), .out(w_r2data_A), .clk(clk), .we(1), .gwe(gwe), .rst(rst));
    Nbit_reg #(16, 16'd0) W_r2data_B (.in((m_r2data_B & {16{!m_is_store_B | !within}}) | (m_alu_output_A & {16{m_is_store_B & within}})), .out(w_r2data_B), .clk(clk), .we(1), .gwe(gwe), .rst(rst));
    Nbit_reg #(1, 1'd0) W_ld_A (.in(m_is_load_A), .out(w_is_load_A), .clk(clk), .we(1), .gwe(gwe), .rst(rst));
    Nbit_reg #(1, 1'd0) W_ld_B (.in(m_is_load_B), .out(w_is_load_B), .clk(clk), .we(1), .gwe(gwe), .rst(rst));
    Nbit_reg #(1, 1'd0) W_str_A (.in(m_is_store_A), .out(w_is_store_A), .clk(clk), .we(1), .gwe(gwe), .rst(rst));
    Nbit_reg #(1, 1'd0) W_str_B (.in(m_is_store_B), .out(w_is_store_B), .clk(clk), .we(1), .gwe(gwe), .rst(rst));
    Nbit_reg #(16, 16'd0) W_dmem (.in(i_cur_dmem_data), .out(w_dmem_data), .clk(clk), .we(1), .gwe(gwe), .rst(rst));
    Nbit_reg #(1, 1'd0) W_pc_plus_one_A (.in(m_select_pc_plus_one_A), .out(w_select_pc_plus_one_A), .clk(clk), .we(1), .gwe(gwe), .rst(rst));
    Nbit_reg #(1, 1'd0) W_pc_plus_one_B (.in(m_select_pc_plus_one_B), .out(w_select_pc_plus_one_B), .clk(clk), .we(1), .gwe(gwe), .rst(rst));
    
    // WRITE Stage
    assign to_write_A = ((w_alu_output_A & {16{!w_select_pc_plus_one_A & !w_is_load_A}}) | 
                        ((write_pc_A + 1) & {16{w_select_pc_plus_one_A & !w_is_load_A}}) |
                        ((w_dmem_data) & {16{!w_select_pc_plus_one_A & w_is_load_A}}));
    assign to_write_B = ((w_alu_output_B & {16{!w_select_pc_plus_one_B & !w_is_load_B}}) |
                        ((write_pc_B + 1) & {16{w_select_pc_plus_one_B & !w_is_load_B}}) |
                        ((w_dmem_data) & {16{!w_select_pc_plus_one_B & w_is_load_B}}));
    
    //Get the test NZP Values
    assign next_n_test_A = $signed(to_write_A) < 0;
    assign next_z_test_A = $signed(to_write_A) == 0;
    assign next_p_test_A = $signed(to_write_A) > 0;
    assign next_n_test_B = $signed(to_write_B) < 0;
    assign next_z_test_B = $signed(to_write_B) == 0;
    assign next_p_test_B = $signed(to_write_B) > 0;
    
    // SET ALL TEST WIRES
    assign test_cur_pc_A = write_pc_A;       // program counter
    assign test_cur_pc_B = write_pc_B;
    assign test_cur_insn_A = write_insn_A;     // instruction bits
    assign test_cur_insn_B = write_insn_B;
    //assign test_cur_insn_A = 16'd1;     // instruction bits
    //assign test_cur_insn_B = 16'd1;
    assign test_regfile_we_A = w_regfile_we_A;   // register file write-enable
    assign test_regfile_we_B = w_regfile_we_B;
    assign test_regfile_wsel_A = w_wsel_A; // which register to write
    assign test_regfile_wsel_B = w_wsel_B;
    assign test_regfile_data_A = to_write_A; // data to write to register file
    assign test_regfile_data_B = to_write_B;
    assign test_nzp_we_A = w_nzp_we_A;       // nzp register write enable
    assign test_nzp_we_B = w_nzp_we_B;
    
    assign test_nzp_new_bits_A = {next_n_test_A,next_z_test_A,next_p_test_A}; // new nzp bits
    assign test_nzp_new_bits_B = {next_n_test_B,next_z_test_B,next_p_test_B};
    
    assign test_dmem_we_A = (w_is_store_A) & (w_stall_A == 0);      // data memory write enable
    assign test_dmem_we_B = (w_is_store_B) & (w_stall_B == 0);
    assign test_dmem_addr_A = (w_alu_output_A & {16{w_is_load_A | w_is_store_A}});    // address to read/write from/to memory
    assign test_dmem_addr_B = (w_alu_output_B & {16{w_is_load_B | w_is_store_B}});
    assign test_dmem_data_A = (w_r2data_A & {16{(!w_is_load_A & w_is_store_A) & (w_stall_A == 0)}}) | 
    (w_dmem_data & {16{(w_is_load_A & !w_is_store_A) & (w_stall_A == 0)}});    // data to read/write from/to memory
    assign test_dmem_data_B = (w_r2data_B & {16{(!w_is_load_B & w_is_store_B) & 
    (w_stall_B == 0)}}) | (w_dmem_data & {16{(w_is_load_B & !w_is_store_B) & (w_stall_B == 0)}});
    
    assign test_stall_A = w_stall_A;
    assign test_stall_B = w_stall_B;




   /* Add $display(...) calls in the always block below to
    * print out debug information at the end of every cycle.
    *
    * You may also use if statements inside the always block
    * to conditionally print out information.
    */
   always @(posedge gwe) begin
      // $display("%d, %d, %d, %d, %d, %h, %h, %h", w_stall_A, w_stall_B, stall_1, d_is_load_A, d_is_load_B, decode_pc_A, decode_pc_B,  m_alu_output_A);
      // $display("%b, %b, %h, %h", write_insn_A, write_insn_B, write_pc_A, write_pc_B);
      // $display("%d, %d, %d, %d, %d, %d", mx_1_B_A, mx_1_B_B, wx_1_B_A, wx_1_B_B, pb_1_B_A, pb_1_B_B);
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
      // run it for that many nanoseconds, then set
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
endmodule
