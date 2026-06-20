// Description: parameterized half duplex single port RAM
//with FSM controller with state (idle -> write/read -> data_return) which work on request of master
//having same address bus for both read and write
// do read operation when cmd from master is low and write when cmd from master is high
// either read or write at one time which avoid read-write conflict
// RAM stay in idle state when no rquest from master which save power

`define BYTE 8
`define FILE "external_storage.mem"

module RAM8 # (
    parameter Word_size = 1, //number of Byte per word
    parameter Block_size = 4, // number of words per block
    parameter RAM_size = 64
  ) (
    input wire cs,
    input wire rst_n,
    input wire req, // request from master
    input wire clk,
    input wire cmd, // command from master cmd =1 (write) cmd =0 (read)
    input wire [address_width -1:0] addr,
    input wire [data_width -1:0] data_in,
    output reg [data_width -1:0] data_out,
    output reg ready, // set high when RAM is ready for request
    output reg done //set high when operation is completed
  );

  //calculating the width of differnt component
  localparam word_width = Word_size * `BYTE;
  localparam data_width = word_width;
  localparam block_width = Block_size * word_width;
  localparam address_width = $clog2(RAM_size * Block_size);

  //bites in block number and block offset
  localparam tag_bites = $clog2(RAM_size);
  localparam offset_bites = $clog2(Block_size);

  //states of FSM
  localparam idle = 2'b00,
             write = 2'b01,
             read = 2'b10,
             data_return = 2'b11;

  reg [1:0] current_state, next_state;


  //memory array
  reg [block_width -1:0] mem_array [0: RAM_size -1];

  //extract the data from external .mem file
  initial
  begin : initilize
    $readmemh(`FILE , mem_array);
  end


  //register which hold data and address coming from master
  reg [address_width -1:0] addr_hold;
  reg [data_width -1:0] data_hold;

  //partitioning the address into block number and block offset
  wire [tag_bites -1:0]tag = addr_hold[address_width -1: offset_bites];
  wire [offset_bites -1:0]offset = addr_hold[offset_bites -1:0];



  always @(posedge clk)
  begin :state_transition_logic
    if (!rst_n)
    begin
      current_state <= idle;
      addr_hold     <= {address_width{1'b0}};
      data_hold     <= {data_width{1'b0}};
    end
    else
    begin
      current_state <= next_state;

      // Capture incoming system attributes instantly during a valid request
      if (req && ready)
      begin
        addr_hold <= addr;
        data_hold <= data_in;
      end

      // SYNCHRONOUS WRITE
      if (current_state == write && cs)
      begin
        mem_array[tag][offset * data_width +: data_width] <= data_hold;
      end
    end
  end



  //state combinatinal and output logic
  always @(*)
  begin : output_logic
    // Default assignments to avoid dangerous synthesis latches
    next_state   = current_state;
    ready = 1'b0;
    done = 1'b0;
    data_out = {data_width{1'b0}};

    case (current_state)

      idle :
      begin
        ready = 1'b1;
        if (req)
        begin
          // Evaluate cmd: 1 = Write path, 0 = Read path
          next_state = (cmd) ? write : read;
        end
      end

      write :
      begin
        next_state   = data_return;
      end

      read :
      begin
        data_out = mem_array[tag][offset * data_width +: data_width];
        next_state = data_return;
      end

      data_return:
      begin
        done = 1'b1; // Strobe done signal back up to the master

        next_state = idle; 
      end

      default:
        next_state = idle;
    endcase
  end

endmodule
