module ps2if_ip (
    input logic clk,reset,
    input [1:0] address,
    input logic write, read,
    input [7:0] writedata,
    output [7:0] readdata,

    inout logic PS2CLK, PS2DATA,
    output logic LOGCLK // for logic analyzer. nothing to do with avalon. condit 
);

logic [9:0] sft;
logic [7:0] ps2rdata;
logic empty, valid;

localparam HALT = 3'h0, CLKLOW=3'h1, STBIT = 3'h2, SENDBIT= 3'h3, WAITCLK=3'h4, GETBIT=3'h5, SETFLG=3'h6;
logic [2:0] cur, nxt;

logic txregwr;
assign txregwr = (address == 2'h0) ? {6'h0, empty, valid} : ps2rdata;

logic ps2clken;

always @(posedge clk) begin
    if (reset)
        ps2clken <= 1'b0;
    else 
        ps2clken <= (cur==CLKLOW || cur == STBIT); 
end


assign PS2CLK = (ps2clken) ? 1'b0 : 1'bz;
assign PS2DATA = (cur==SENDBIT || cur==STBIT) ? sft[0]:1'bz;


// to count 100us by dividing 50 Mhz with 5000 (50M/5k = 1 us)
logic [12:0] txcnt;

localparam TXMAX = 13'd5000;
logic over100us; 
assign over100us= (txcnt == TXMAX-1);

//unless cur is either HALT or over100us, txcnt is incrimented
always @(posedge clk) begin
    if (reset) 
        txcnt <= 13'h0000;
    else if (cur == HALT)
        txcnt <= 13'h0000;
    else if (over100us)
        txcnt <= 13'h0000;
    else 
        txcnt <= txcnt + 13'h1;
end

// to detect negative edge of PS2CLK
logic [2:0] sreg;
logic clkfall;

always @(posedge clk) begin
    if(reset)
        sreg <= 3'b000;
    else
        sreg <= {sreg[1:0], PS2CLK};
end

assign clkfall = sreg[2] & ~sreg[1];

// bitcount for transfer data
logic [3:0] bitcnt;

always @(posedge clk) begin
    if (reset) 
        bitcnt <= 4'h0;
    else if(cur ==HALT)
        bitcnt <= 4'h0;
    else if((cur == SENDBIT || cur == GETBIT) & clkfall)
        bitcnt <= bitcnt + 4'h1;
end


// state machine
// cur is current state. cur is only changed by nxt. 
always @(posedge clk) begin
    if (reset) 
        cur <= HALT;
    else 
        cur <= nxt;
end

always_comb begin 
    case(cur)
        HALT: if(txregwr)
                nxt <= CLKLOW;
              else if ((PS2DATA == 1'b0)& clkfall)
                nxt <= GETBIT;
              else
                nxt <=HALT;
        CLKLOW:if(over100us)
                 nxt <= STBIT;
               else
                 nxt <= CLKLOW;
        STBIT: if (over100us)
                 nxt <- SENDBIT;
               else
                 nxt <= STBIT;
        SENDBIT:if((bitcnt == 4'h9) & clkfall) 
                 nxt <= WAITCLK;
                else
                 nxt<= SENDBIT;
        WAITCLK:if(clkfall)
                 nxt <= HALT;
                else 
                 nxt <= WAITCLK;
        GETBIT: if((bitcnt==4'h7) & clkfall)
                 nxt <= SETFLG;
                else
                 nxt <= GETBIT;
        SETFLG: if(clkfall)
                 nxt <= WAITCLK;
                else
                 nxt <= SETFLG;
        default:nxt <= HALT;
    endcase
end

//empty flg
always @(posedge clk) begin
    if (reset) 
        empty <= 1'b1;
    else
        empty <= (cur == HALT) ? 1'b1: 1'b0;
end

// valid flg
always @(posedge clk) begin
    if(reset)
        valid <= 1'b0;
    else if((address == 2'h0) & write)
        valid <= writedata[0];
    else if( cur == SETFLG & clkfall)
        valid <= 1'b1;
end

//shift resister (transfer to ps2divice)
always @(posedge clk) begin
    if (reset) 
        sft <= 10'h000;
    else if (txregwr)
        sht <={ ~(^writedata),writedata,1'b0};
    else if (cur == SENDBIT & clkfall)
        sht <= {1'b1, sft[9:1]};
    else if (cur == GETBIT & clkfall)
        sht <={PS2DATA,sft[9:1]};
end

// to receive data from ps2device ( to receive data on ps2rdata)
always @(posedge clk) begin
        if(reset)
            ps2rdata <= 8'h00;
        else if(cur == SETFLG & clkfall)
            ps2rdata <= sft[9:2];
end

// logic analyzer clk creater. to create 1 Mhz clk (LOGCLK)
logic [4:0] logcnt;

localparam MAX = 5'd25 ;
logic cntend;
assign cntend = (logcnt == MAX -1);

always @(posedge clk) begin
    if(reset)
        logcnt <= 5'h00;
    else if (cntend)
        logcnt <= 5'h00;
    else 
        logcnt <= logcnt + 5'h1;
end

always @(posedge clk ) begin
    if (reset) 
        LOGCLK <= 1'b0;
    else if (cntend)
        LOGCLK <= ~LOGCLK;
    
end
    
endmodule