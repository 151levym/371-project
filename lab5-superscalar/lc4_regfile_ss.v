`timescale 1ns / 1ps

// Prevent implicit wire declaration
`default_nettype none

/* 8-register, n-bit register file with
 * four read ports and two write ports
 * to support two pipes.
 * 
 * If both pipes try to write to the
 * same register, pipe B wins.
 * 
 * Inputs should be bypassed to the outputs
 * as needed so the register file returns
 * data that is written immediately
 * rather than only on the next cycle.
 */
module lc4_regfile_ss #(parameter n = 16)
   (input  wire         clk,
    input  wire         gwe,
    input  wire         rst,

    input  wire [  2:0] i_rs_A,      // pipe A: rs selector
    output wire [n-1:0] o_rs_data_A, // pipe A: rs contents
    input  wire [  2:0] i_rt_A,      // pipe A: rt selector
    output wire [n-1:0] o_rt_data_A, // pipe A: rt contents

    input  wire [  2:0] i_rs_B,      // pipe B: rs selector
    output wire [n-1:0] o_rs_data_B, // pipe B: rs contents
    input  wire [  2:0] i_rt_B,      // pipe B: rt selector
    output wire [n-1:0] o_rt_data_B, // pipe B: rt contents

    input  wire [  2:0]  i_rd_A,     // pipe A: rd selector
    input  wire [n-1:0]  i_wdata_A,  // pipe A: data to write
    input  wire          i_rd_we_A,  // pipe A: write enable

    input  wire [  2:0]  i_rd_B,     // pipe B: rd selector
    input  wire [n-1:0]  i_wdata_B,  // pipe B: data to write
    input  wire          i_rd_we_B   // pipe B: write enable
    );

    wire[15:0] outputs[15:0];
    wire[1:0] we_1[15:0];
    wire[1:0] we_2[15:0];

    assign we_1[0] = (i_rd_A === 3'b000) && i_rd_we_A;
    assign we_1[1] = (i_rd_A === 3'b001) && i_rd_we_A;
    assign we_1[2] = (i_rd_A === 3'b010) && i_rd_we_A;
    assign we_1[3] = (i_rd_A === 3'b011) && i_rd_we_A;
    assign we_1[4] = (i_rd_A === 3'b100) && i_rd_we_A;
    assign we_1[5] = (i_rd_A === 3'b101) && i_rd_we_A;
    assign we_1[6] = (i_rd_A === 3'b110) && i_rd_we_A;
    assign we_1[7] = (i_rd_A === 3'b111) && i_rd_we_A;
    
    assign we_2[0] = (i_rd_B === 3'b000) && i_rd_we_B;
    assign we_2[1] = (i_rd_B === 3'b001) && i_rd_we_B;
    assign we_2[2] = (i_rd_B === 3'b010) && i_rd_we_B;
    assign we_2[3] = (i_rd_B === 3'b011) && i_rd_we_B;
    assign we_2[4] = (i_rd_B === 3'b100) && i_rd_we_B;
    assign we_2[5] = (i_rd_B === 3'b101) && i_rd_we_B;
    assign we_2[6] = (i_rd_B === 3'b110) && i_rd_we_B;
    assign we_2[7] = (i_rd_B === 3'b111) && i_rd_we_B;

    Nbit_reg #(n) r0(.in(we_2[0] ? i_wdata_B : i_wdata_A), .out(outputs[0]), .clk(clk),
                    .we(we_1[0] | we_2[0]), .gwe(gwe), .rst(rst));
    Nbit_reg #(n) r1(.in(we_2[1] ? i_wdata_B : i_wdata_A), .out(outputs[1]), .clk(clk), 
                    .we(we_1[1] | we_2[1]), .gwe(gwe), .rst(rst));
    Nbit_reg #(n) r2(.in(we_2[2] ? i_wdata_B : i_wdata_A), .out(outputs[2]), .clk(clk), 
                  .we(we_1[2] | we_2[2]), .gwe(gwe), .rst(rst));
    Nbit_reg #(n) r3(.in(we_2[3] ? i_wdata_B : i_wdata_A), .out(outputs[3]), .clk(clk), 
                  .we(we_1[3] | we_2[3]), .gwe(gwe), .rst(rst));
    Nbit_reg #(n) r4(.in(we_2[4] ? i_wdata_B : i_wdata_A), .out(outputs[4]), .clk(clk), 
                  .we(we_1[4] | we_2[4]), .gwe(gwe), .rst(rst));
    Nbit_reg #(n) r5(.in(we_2[5] ? i_wdata_B : i_wdata_A), .out(outputs[5]), .clk(clk),
                  .we(we_1[5] | we_2[5]), .gwe(gwe), .rst(rst));
    Nbit_reg #(n) r6(.in(we_2[6] ? i_wdata_B : i_wdata_A), .out(outputs[6]), .clk(clk),
                  .we(we_1[6] | we_2[6]), .gwe(gwe), .rst(rst));
    Nbit_reg #(n) r7(.in(we_2[7] ? i_wdata_B : i_wdata_A), .out(outputs[7]), .clk(clk), 
                  .we(we_1[7] | we_2[7]), .gwe(gwe), .rst(rst));
    
    assign o_rs_data_A = outputs[i_rs_A];
    assign o_rt_data_A = outputs[i_rt_A];
    assign o_rs_data_B = outputs[i_rs_B];
    assign o_rt_data_B = outputs[i_rt_B];

endmodule
