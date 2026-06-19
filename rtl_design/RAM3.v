// Description: single port RAM with 8 bite data and 4 bit address 
//having common address bus for both read and write 
// do read operation when rd && !wr and write when !rd && wr 
// either read or write not both at same time 

module RAM3(
    input wire cs,
    input wire rd, wr,
    input wire [3:0] addr,
    input wire [7:0] data_in,
    output reg [7:0] data_out
);
    //memory array 
    reg [7:0] mem_array [0:15];
    
    // ONLY trigger when 'wr' transitions to break the feedback loop.
    always @(*) begin : write
        if (cs && wr && !rd) begin
            mem_array[addr] = data_in; 
        end
    end
   
    // Read is fully combinational; it updates whenever the address changes
    always @(*) begin : read
        if (cs && !wr && rd) begin
            data_out = mem_array[addr];
        end else begin
            data_out = 8'hzz; 
        end
    end  
           
endmodule