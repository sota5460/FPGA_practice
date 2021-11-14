module syncgen (
    input logic CLK,
    input logic RST,
    output logic PCK,
    output logic VGA_HS,
    output logic VGA_VS,
    output logic [9:0] HCNT,
    output logic [9:0] VCNT
);

`include "vga_param.vh"

initial PCK = 1'b0;

always @(posedge CLK) begin
    PCK <= ~ PCK;
end

logic hcntend;
assign hcntend = (HCNT ==HPERIOD - 10'h001);

always @(posedge PCK) begin
    if(RST)
        HCNT <= 10'h000;
    else if (hcntend)
        HCNT <= 10'h000;
    else 
        HCNT <= HCNT + 10'h001;
    
end

always @(posedge PCK) begin
    if(RST)
        VCNT <= 10'h000;
    else if (hcntend) begin
        if(VCNT == VPERIOD - 10'h001)
            VCNT <= 10'h000;
        else
            VCNT <= VCNT + 10'h001;
    end
end

logic [9:0] hsstart;
assign hsstart = HFRONT - 10'h001;
logic [9:0] hsend;
assign hsend = HFRONT + HWIDTH - 10'h001;
logic [9:0] vsstart;
assign vsstart = VFRONT; 
logic [9:0] vsend;
assign vsend = VFRONT + VWIDTH;

always @(posedge PCK) begin
    if(RST)
        VGA_HS <= 1'b1;
    else if (HCNT==hsstart)
        VGA_HS <= 1'b0;
    else if (HCNT==hsend)
        VGA_HS <= 1'b1;
end

always @(posedge PCK) begin
    if(RST)
        VGA_VS <= 1'b1;
    else if (HCNT==hsstart) begin 
        if(VCNT==vsstart)
            VGA_VS <= 1'b0;
    else if (VCNT==vsend)
        VGA_VS <= 1'b1;
end
    
endmodule