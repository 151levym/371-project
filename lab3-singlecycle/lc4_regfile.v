/* TODO: Names of all group members
 * TODO: PennKeys of all group members
 *
 * lc4_regfile.v
 * Implements an 8-register register file parameterized on word size.
 *
 */

`timescale 1ns / 1ps


// Prevent implicit wire declaration
`default_nettype none

module lc4_regfile #(parameter n = 16)
   (input  wire         clk,
    input  wire         gwe,
    input  wire         rst,
    input  wire [  2:0] i_rs,      // rs selector
    output wire [n-1:0] o_rs_data, // rs contents
    input  wire [  2:0] i_rt,      // rt selector
    output wire [n-1:0] o_rt_data, // rt contents
    input  wire [  2:0] i_rd,      // rd selector
    input  wire [n-1:0] i_wdata,   // data to write
    input  wire         i_rd_we    // write enable
    );
    
    
    wire[15:0] outputs[15:0];
    wire[1:0] we[15:0];

    assign we[0] = i_rd === 3'b000 && i_rd_we;
    assign we[1] = i_rd === 3'b001 && i_rd_we;
    assign we[2] = i_rd === 3'b010 && i_rd_we;
    assign we[3] = i_rd === 3'b011 && i_rd_we;
    assign we[4] = i_rd === 3'b100 && i_rd_we;
    assign we[5] = i_rd === 3'b101 && i_rd_we;
    assign we[6] = i_rd === 3'b110 && i_rd_we;
    assign we[7] = i_rd === 3'b111 && i_rd_we;

    Nbit_reg #(n) r0(.in(i_wdata), .out(outputs[0]), .clk(clk), .we(we[0]), .gwe(gwe), .rst(rst));
    Nbit_reg #(n) r1(.in(i_wdata), .out(outputs[1]), .clk(clk), .we(we[1]), .gwe(gwe), .rst(rst));
    Nbit_reg #(n) r2(.in(i_wdata), .out(outputs[2]), .clk(clk), .we(we[2]), .gwe(gwe), .rst(rst));
    Nbit_reg #(n) r3(.in(i_wdata), .out(outputs[3]), .clk(clk), .we(we[3]), .gwe(gwe), .rst(rst));
    Nbit_reg #(n) r4(.in(i_wdata), .out(outputs[4]), .clk(clk), .we(we[4]), .gwe(gwe), .rst(rst));
    Nbit_reg #(n) r5(.in(i_wdata), .out(outputs[5]), .clk(clk), .we(we[5]), .gwe(gwe), .rst(rst));
    Nbit_reg #(n) r6(.in(i_wdata), .out(outputs[6]), .clk(clk), .we(we[6]), .gwe(gwe), .rst(rst));
    Nbit_reg #(n) r7(.in(i_wdata), .out(outputs[7]), .clk(clk), .we(we[7]), .gwe(gwe), .rst(rst));
    
    assign o_rs_data = outputs[i_rs];
    assign o_rt_data = outputs[i_rt];
    
endmodule
