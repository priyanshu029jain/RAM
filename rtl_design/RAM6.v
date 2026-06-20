// Description: parameterized single port RAM 
//having multiple words per block
//having seprate address bus for both read and write 
// do read operation when rd is high and write when wr is high
// can do both read and write at same time 
// write first bypass condition to avoid read-write conflict
// get initialized by external storage 
// remove $writeh() as it is non-synth.

`define BYTE 8
`define FILE "external_storage.mem"

module RAM6 # (
  parameter Word_size = 1, //number of Byte per word  
  parameter Block_size = 4, // number of words per block
  parameter RAM_size = 64 
) ( 
    input wire cs,
    input wire clk,
    input wire rd,
    input wire wr,
    input wire [address_width -1:0] addr_rd,
    input wire [address_width -1:0] addr_wr,
    input wire [data_width -1:0] data_in,
    output reg [data_width -1:0] data_out
);
    //calculating the width of differnt component
    localparam word_width = Word_size * `BYTE;
    localparam data_width = word_width;
    localparam block_width = Block_size * word_width;
    localparam address_width = $clog2(RAM_size * Block_size);

    //bites in block number and block offset
    localparam tag_bites = $clog2(RAM_size);
    localparam offset_bites = $clog2(Block_size);

    //memory array 
    reg [block_width -1:0] mem_array [0: RAM_size -1];

    //partitioning the address into block number and block offset
    wire [tag_bites -1:0]tag_rd = addr_rd[address_width -1: offset_bites];
    wire [offset_bites -1:0]offset_rd = addr_rd[offset_bites -1:0];

    wire [tag_bites -1:0]tag_wr = addr_wr[address_width -1: offset_bites];
    wire [offset_bites -1:0]offset_wr = addr_wr[offset_bites -1:0];

     //extract the data from external .mem file
    initial begin : initilize
        $readmemh(`FILE , mem_array);
    end
    
    // write the data_in to RAM memory array 
    always @(posedge clk) begin : write
        if (cs && wr) begin
            mem_array[tag_wr][offset_wr * data_width +: data_width] <= data_in;

        end
    end
   
    // Read is fully combinational; it updates whenever the address changes
    always @(*) begin : read
        if (cs && rd) begin

            if((addr_rd == addr_wr) && wr) data_out = data_in; // during the confilict write data bypass
            else data_out = mem_array[tag_rd][offset_rd * data_width +: data_width]; //normal read

        end else begin
            data_out = {data_width{1'b0}}; 
        end
    end  

endmodule