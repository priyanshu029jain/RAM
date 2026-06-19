// Description: single port RAM with 8 bite data and 4 bit address 
//having seprate address bus for both read and write 
// do read operation when rd is high and write when wr is high
// can do both read and write at same time 
// write first bypass condition to avoid read-write conflict

module RAM4(
    input wire cs,
    input wire clk,
    input wire rd,
    input wire wr,
    input wire [3:0] addr_rd,
    input wire [3:0] addr_wr,
    input wire [7:0] data_in,
    output reg [7:0] data_out
);
    //memory array 
    reg [7:0] mem_array [0:15];
    
    // write the data_in to RAM memory array 
    always @(posedge clk) begin : write
        if (cs && wr) begin
            mem_array[addr_wr] = data_in; 
        end
    end
   
    // Read is fully combinational; it updates whenever the address changes
    always @(*) begin : read
        if (cs && rd) begin
            data_out = (addr_rd == addr_wr)? data_in : mem_array[addr_rd];
        end else begin
            data_out = 8'hzz; 
        end
    end  
           
endmodule