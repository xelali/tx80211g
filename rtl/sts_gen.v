`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////
// Company:
// Engineer:
//
// Create Date: 2019/10/21 20:48:27
// Design Name:
// Module Name: sts_gen
// Project Name:
// Target Devices:
// Tool Versions:
// Description:
//
// Dependencies:
//
// Revision:
// Revision 0.01 - File Created
// Additional Comments:
//
//////////////////////////////////////////////////////////////////////////////////


module sts_gen(input rst_n,
               input clk,
               input en,
               output reg [7:0] re,
               output reg [7:0] im,
               output reg [7:0] index,
               output reg data_valid);
    
    reg [3:0] i;
    reg [3:0] j;
    reg [7:0] shortrom_re [15:0];
    reg [7:0] shortrom_im [15:0];
    
    always @ (negedge rst_n or posedge clk)  //registers initial
        if (!rst_n)
        begin
            i          = 0;
            j          = 0;
            re         = 0;
            im         = 0;
            index      = 0;
            data_valid = 0;
            
            shortrom_re[0]  = 8'b00001100;
            shortrom_re[1]  = 8'b11011110;
            shortrom_re[2]  = 8'b11111101;
            shortrom_re[3]  = 8'b00100100;
            shortrom_re[4]  = 8'b00011000;
            shortrom_re[5]  = 8'b00100100;
            shortrom_re[6]  = 8'b11111101;
            shortrom_re[7]  = 8'b11011110;
            shortrom_re[8]  = 8'b00001100;
            shortrom_re[9]  = 8'b00000001;
            shortrom_re[10] = 8'b11101100;
            shortrom_re[11] = 8'b11111101;
            shortrom_re[12] = 8'b00000000;
            shortrom_re[13] = 8'b11111101;
            shortrom_re[14] = 8'b11101100;
            shortrom_re[15] = 8'b00000001;
            
            shortrom_im[0]  = 8'b00001100;
            shortrom_im[1]  = 8'b00000001;
            shortrom_im[2]  = 8'b11101100;
            shortrom_im[3]  = 8'b11111101;
            shortrom_im[4]  = 8'b00000000;
            shortrom_im[5]  = 8'b11111101;
            shortrom_im[6]  = 8'b11101100;
            shortrom_im[7]  = 8'b00000001;
            shortrom_im[8]  = 8'b00001100;
            shortrom_im[9]  = 8'b11011110;
            shortrom_im[10] = 8'b11111101;
            shortrom_im[11] = 8'b00100100;
            shortrom_im[12] = 8'b00011000;
            shortrom_im[13] = 8'b00100100;
            shortrom_im[14] = 8'b11111101;
            shortrom_im[15] = 8'b11011110;
            
        end
    
    
    //************************************
    
    else
    begin
    if (en)
        if (i <= 9)
            if (j<15)
            begin
                re         = shortrom_re[j];
                im         = shortrom_im[j];
                data_valid = 1;
                if (i == 0&j == 0)   //multiplied by the window function
                begin
                    re = re>>1;
                    im = im>>1;
                end
                j     = j+1;
                index = index+1;
            end
            else
            begin
                re         = shortrom_re[j];
                im         = shortrom_im[j];
                index      = index+1;
                data_valid = 1;
                j          = 0;
                i          = i+1;
            end
        else
        begin
            i     = 0;
            re    = shortrom_re[j]>>1;  //multiplied by the window function
            im    = shortrom_im[j]>>1;
            index = index+1;
        end
    else
    begin
        i          = 0;
        j          = 0;
        re         = 0;
        im         = 0;
        index      = 0;
        data_valid = 0;
    end
    end
endmodule
