`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////
// Company:
// Engineer:
//
// Create Date: 2019/10/21 20:56:54
// Design Name:
// Module Name: lts_gen
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


module lts_gen(input rst_n,
               input clk,
               input en,
               output reg [7:0] re,
               output reg [7:0] im,
               output reg [7:0] index,
               output reg data_valid);
    reg [1:0] i;
    reg [5:0] j;
    reg [7:0] longrom_re [63:0];
    reg [7:0] longrom_im [63:0];
    
    always @ (negedge rst_n or posedge clk)  //registers initialize
        if (!rst_n)
        begin
            i          = 0;
            j          = 0;
            re    = 0;
            im    = 0;
            index = 0;
            data_valid    = 0;
            
            longrom_re[0]  = 8'b00101000;
            longrom_re[1]  = 8'b11111111;
            longrom_re[2]  = 8'b00001010;
            longrom_re[3]  = 8'b00011001;
            longrom_re[4]  = 8'b00000101;
            longrom_re[5]  = 8'b00001111;
            longrom_re[6]  = 8'b11100011;
            longrom_re[7]  = 8'b11110110;
            longrom_re[8]  = 8'b00011001;
            longrom_re[9]  = 8'b00001110;
            longrom_re[10] = 8'b00000000;
            longrom_re[11] = 8'b11011101;
            longrom_re[12] = 8'b00000110;
            longrom_re[13] = 8'b00001111;
            longrom_re[14] = 8'b11111010;
            longrom_re[15] = 8'b00011111;
            longrom_re[16] = 8'b00010000;
            longrom_re[17] = 8'b00001001;
            longrom_re[18] = 8'b11110001;
            longrom_re[19] = 8'b11011110;
            longrom_re[20] = 8'b00010101;
            longrom_re[21] = 8'b00010010;
            longrom_re[22] = 8'b11110001;
            longrom_re[23] = 8'b11110010;
            longrom_re[24] = 8'b11110111;
            longrom_re[25] = 8'b11100001;
            longrom_re[26] = 8'b11011111;
            longrom_re[27] = 8'b00010011;
            longrom_re[28] = 8'b11111111;
            longrom_re[29] = 8'b11101000;
            longrom_re[30] = 8'b00010111;
            longrom_re[31] = 8'b00000011;
            longrom_re[32] = 8'b11011000;
            longrom_re[33] = 8'b00000011;
            longrom_re[34] = 8'b00010111;
            longrom_re[35] = 8'b11101000;
            longrom_re[36] = 8'b11111111;
            longrom_re[37] = 8'b00010011;
            longrom_re[38] = 8'b11011111;
            longrom_re[39] = 8'b11100001;
            longrom_re[40] = 8'b11110111;
            longrom_re[41] = 8'b11110010;
            longrom_re[42] = 8'b11110001;
            longrom_re[43] = 8'b00010010;
            longrom_re[44] = 8'b00010101;
            longrom_re[45] = 8'b11011110;
            longrom_re[46] = 8'b11110001;
            longrom_re[47] = 8'b00001001;
            longrom_re[48] = 8'b00010000;
            longrom_re[49] = 8'b00011111;
            longrom_re[50] = 8'b11111010;
            longrom_re[51] = 8'b00001111;
            longrom_re[52] = 8'b00000110;
            longrom_re[53] = 8'b11011101;
            longrom_re[54] = 8'b00000000;
            longrom_re[55] = 8'b00001110;
            longrom_re[56] = 8'b00011001;
            longrom_re[57] = 8'b11110110;
            longrom_re[58] = 8'b11100011;
            longrom_re[59] = 8'b00001111;
            longrom_re[60] = 8'b00000101;
            longrom_re[61] = 8'b00011001;
            longrom_re[62] = 8'b00001010;
            longrom_re[63] = 8'b11111111;
            
            longrom_im[0]  = 8'b00000000;
            longrom_im[1]  = 8'b11100001;
            longrom_im[2]  = 8'b11100100;
            longrom_im[3]  = 8'b00010101;
            longrom_im[4]  = 8'b00000111;
            longrom_im[5]  = 8'b11101010;
            longrom_im[6]  = 8'b11110010;
            longrom_im[7]  = 8'b11100101;
            longrom_im[8]  = 8'b11111001;
            longrom_im[9]  = 8'b00000001;
            longrom_im[10] = 8'b11100011;
            longrom_im[11] = 8'b11110100;
            longrom_im[12] = 8'b11110001;
            longrom_im[13] = 8'b11111100;
            longrom_im[14] = 8'b00101001;
            longrom_im[15] = 8'b11111111;
            longrom_im[16] = 8'b11110000;
            longrom_im[17] = 8'b00011001;
            longrom_im[18] = 8'b00001010;
            longrom_im[19] = 8'b00010001;
            longrom_im[20] = 8'b00011000;
            longrom_im[21] = 8'b00000100;
            longrom_im[22] = 8'b00010101;
            longrom_im[23] = 8'b11111010;
            longrom_im[24] = 8'b11011001;
            longrom_im[25] = 8'b11111100;
            longrom_im[26] = 8'b11111011;
            longrom_im[27] = 8'b11101101;
            longrom_im[28] = 8'b00001110;
            longrom_im[29] = 8'b00011101;
            longrom_im[30] = 8'b00011011;
            longrom_im[31] = 8'b00011001;
            longrom_im[32] = 8'b00000000;
            longrom_im[33] = 8'b11100111;
            longrom_im[34] = 8'b11100101;
            longrom_im[35] = 8'b11100011;
            longrom_im[36] = 8'b11110010;
            longrom_im[37] = 8'b00010011;
            longrom_im[38] = 8'b00000101;
            longrom_im[39] = 8'b00000100;
            longrom_im[40] = 8'b00100111;
            longrom_im[41] = 8'b00000110;
            longrom_im[42] = 8'b11101011;
            longrom_im[43] = 8'b11111100;
            longrom_im[44] = 8'b11101000;
            longrom_im[45] = 8'b11101111;
            longrom_im[46] = 8'b11110110;
            longrom_im[47] = 8'b11100111;
            longrom_im[48] = 8'b00010000;
            longrom_im[49] = 8'b00000001;
            longrom_im[50] = 8'b11010111;
            longrom_im[51] = 8'b00000100;
            longrom_im[52] = 8'b00001111;
            longrom_im[53] = 8'b00001100;
            longrom_im[54] = 8'b00011101;
            longrom_im[55] = 8'b11111111;
            longrom_im[56] = 8'b00000111;
            longrom_im[57] = 8'b00011011;
            longrom_im[58] = 8'b00001110;
            longrom_im[59] = 8'b00010110;
            longrom_im[60] = 8'b11111001;
            longrom_im[61] = 8'b11101011;
            longrom_im[62] = 8'b00011100;
            longrom_im[63] = 8'b00011111;
            
        end
    
    
    //************************************
    else
    begin
    if (en)
    begin
        index = index+1;
        //Add cyclic guard//
        if (i == 0)
            if (j<31)
            begin
                re = longrom_re[j+32];
                im = longrom_im[j+32];
                data_valid = 1;
                if (i == 0&j == 0)
                begin     //multiplied by the window function
                    re = 8'b11101100;
                end
                j = j+1;
            end
            else
            begin
                re = longrom_re[j+32];
                im = longrom_im[j+32];
                data_valid = 1;
                j       = 0;
                i       = i+1;
            end
        else if (i>0&i <= 2)
            if (j<63)
            begin
                re = longrom_re[j];
                im = longrom_im[j];
                data_valid = 1;
                j       = j+1;
            end
            else
            begin
                re = longrom_re[j];
                im = longrom_im[j];
                data_valid = 1;
                j       = 0;
                i       = i+1;
            end
        else
        begin
            i       = 0;
            re = longrom_re[j]>>1;  //multiplied by the window function
            im = longrom_im[j]>>1;
        end
    end
    else
    begin
        i          = 0;
        j          = 0;
        re    = 0;
        im    = 0;
        index = 0;
        data_valid    = 0;
    end
    end
    
endmodule
