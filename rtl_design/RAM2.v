// Description: single port RAM with 8 bite data and 4 bit address  
// having common bus for data and address 
// drive data when ALE (Address Latch Enable) =0 and drive address = 1 
// either data or address can be drive form bus at one time

module RAM2(
    input wire cs,
    input wire ale, // make data bus last byte addr when high
    input wire rd,
    input wire wr,

    //common bus for data and address
    inout wire [7:0] data
);
    //memory declaration
    reg [7:0] mem_array [0:15];
    reg [7:0] data_out;
    reg [3:0] addr; // hold address to data 
    
    // Tristate Bus Control
    assign data = (cs && !ale && rd && !wr) ? data_out : 8'bz;
    
    //Captures address from data bus when rtl is high
    always @(*) begin : address
        if (cs && ale) begin
            addr = data[3:0];
        end
    end

    // ONLY trigger when 'wr' transitions to break the feedback loop.
    always @(*) begin : write
        if (cs && !ale && wr && !rd) begin
            mem_array[addr] <= data; 
        end
    end
   
    // Read is fully combinational; it updates whenever the address changes
    always @(*) begin :read
        if (cs && !ale && !wr && rd) begin
            data_out = mem_array[addr];
        end else begin
            data_out = 8'h00; 
        end
    end  
           
endmodule
