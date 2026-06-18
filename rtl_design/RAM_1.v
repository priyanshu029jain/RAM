// Description: single port RAM with 8 bite data and 4 bit address having common read and write port 
// do read operation when rd && !wr and write when !rd && wr 
// either read or write not both at same time 

module RAM1(
    input wire cs,
    input wire rd, wr,
    input wire [3:0] addr,
    inout wire [7:0] data
);
    
    reg [7:0] mem_array [0:15];
    reg [7:0] data_out;
    
    // Tristate Bus Control
    assign data = (cs && rd && !wr) ? data_out : 8'bz;
    
    // ONLY trigger when 'wr' transitions to break the feedback loop.
    always @(*) begin : write
        if (cs && wr && !rd) begin
            mem_array[addr] <= data; 
        end
    end
   
    // Read is fully combinational; it updates whenever the address changes
    always @(*) begin : read
        if (cs && !wr && rd) begin
            data_out = mem_array[addr];
        end else begin
            data_out = 8'h00; 
        end
    end  
           
endmodule
