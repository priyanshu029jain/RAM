// Description: parameterized single port RAM 
//with Time-Division Multiplexing (TDM) logic
//having seprate address bus for both read and write
// do read operation when rd is cpu clock is low and write when cpu clock is high
// either read or write at one time which avoid read-write conflict 
// but from cpu prespective both in same clock cycle

`define BYTE 8
`define FILE "external_storage.mem"

module RAM7 # (
    parameter Word_size = 1, //number of Byte per word
    parameter Block_size = 4, // number of words per block
    parameter RAM_size = 64
  ) (
    input wire cs,
    input wire clk_cpu, // cpu clock 
    input wire clk_ram, // ram intenal clock atleat 2x cpu_clk
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

  // internal TDM tracks address and signals 
  reg [address_width -1:0] muxed_addr;
  reg muxed_rd, muxed_wr;

  // Time Division Multiplexor (TDM) bus steering
  always @(*)
  begin : TDM_logic
    if (clk_cpu)
    begin
      // CPU Clock is HIGH -> Dedicate Port to WRITE
      muxed_addr = addr_wr;
      muxed_wr   = wr;
      muxed_rd   = 1'b0; // Force read idle during write phase
    end
    else
    begin
      // CPU Clock is LOW -> Dedicate Port to READ
      muxed_addr = addr_rd;
      muxed_wr   = 1'b0; // Force write idle during read phase
      muxed_rd   = rd;
    end
  end

  //partitioning the address into block number and block offset
  wire [tag_bites -1:0]tag = muxed_addr[address_width -1: offset_bites];
  wire [offset_bites -1:0]offset = muxed_addr[offset_bites -1:0];

  //extract the data from external .mem file
  initial
  begin : initilize
    $readmemh(`FILE , mem_array);
  end

  // High-Speed Edge Triggered Execution Loop
  always @(posedge clk_ram)
  begin : ram_operation

    if (cs)
    begin
      if (muxed_wr)
      begin : write_execute
        // write during the active write window
        mem_array[tag][offset * data_width +: data_width] <= data_in;
      end

      if (muxed_rd)
      begin : read_execute
        // Updates data_out only during an active read window
        data_out <= mem_array[tag][offset * data_width +: data_width];
      end
      // else data_out will hold its last read value
    end

    else
    begin
      data_out <= {data_width{1'bz}}; // disconnect bus if chip select drops
    end
  end

endmodule
