module fgaif_ip (

    //avalon bus inter connect
    input logic clk,reset,
    input logic [11:0] address,
    input logic [3:0] byteenable,
    input logic write, read,
    input logic [31:0] writedata,
    output logic [31:0] readdata,

    //vga output
    output [3:0] VGA_R,
    output [3:0] VGA_G,
    output [3:0] VGA_B,
    output       VGA_HS, VGA_VS
);


`include "vga_param.vh"

logic [9:0] HCNT;
logic [9:0] VCNT;
logic       PCK;

syncgen sysncgen (
    .CLK(clk),
    .RST(reset),
    .PCK(PCK),
    .VGA_HS(VGA_HS),
    .VGA_VS(VGA_VS),
    .HCNT(HCNT),
    .VCNT(VCNT)
);

logic [9:0] iHCNT;
assign iHCNT = HCNT - HFRONT - HWIDTH - HBACK + 10'd8;

logic [9:0] iVCNT;
assign iVCNT = VCNT - VFRONT - VWIDTH - VBACK - 10'd40;

logic [31:0] vramout;
logic [11:0] vramaddr;

VRAM VRAM(
    .data_a (writedata),
    .address_a(address),
    .wren_a(write),
    .byteena_a(byteenable),
    .clock_a(clk),
    .q_a(readdata),
    .data_b(32'h0),
    .address_b(vramaddr),
    .wren_b(1'b0),
    .clock_b(PCK),
    .q_b(vramout)
);

logic [2:0] vdotcnt;
logic [7:0] cgout;

CGROM CGROM(
    .address({vramout[6:0],vdotcnt}),
    .q (cgout),
    .clock(PCK)
);

logic [6:0] hchacnt;
assign hchacnt = iHCNT[9:3];

logic [2:0] hdotcnt;
assign hdotcnt = iHCNT[2:0];

logic [5:0] vchacnt;
assign vchacnt = iVCNT[8:3];

assign vdotcnt = iVCNT[2:0];

assign vramaddr = (vchacnt << 6) + (vchacnt <<4) + hchacnt;

logic [7:0] sreg;
logic sregld;
assign sregld = (hdotcnt == 3'h6 && iHCNT < 10'd640);

always @(posedge PCK) begin
    if (reset) 
        sreg <= 8'h00;
    else if(sregld)
        sreg <= cgout;
    else
        sreg <= {sreg[6:0],1'b0};
end

logic [11:0] color;

always @(posedge PCK) begin
    if (reset)
        color <= 12'h000;
    else if (sregld)
        color <= vramout[27:16];
    
end

logic hdispen;
assign hdispen = (10'd7 <= iHCNT && iHCNT < 10'd647);

logic vdispen;
assign vdispen = (iVCNT < 9'd400);

logic [11:0] vga_rgb;

always @(posedge PCK) begin
    if(reset)
        vga_rgb <= 12'h000;
    else 
        vga_rgb <= color & {12{hdispen & vdispen & sreg[7]}};
end

assign VGA_R = vga_rgb[11:8];
assign VGA_G = vga_rgb[11:8];
assign VGA_B = vga_rgb[11:8];
    



    
endmodule