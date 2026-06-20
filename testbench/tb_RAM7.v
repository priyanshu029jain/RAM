
module tb_RAM7;
  // Testbench signals
  reg clk_ram, clk_cpu;
  reg cs, rd, wr;
  reg [5:0] addr_rd, addr_wr;
  reg [7:0] data_in;
  wire [7:0] data_out;

  // Instantiate DUT
  RAM # (
        .Word_size(1),
        .RAM_size(16),
        .Block_size(4)
      ) uut (
        .clk_ram(clk_ram),
        .clk_cpu(clk_cpu),
        .cs(cs),
        .rd(rd),
        .wr(wr),
        .addr_wr(addr_wr),
        .addr_rd(addr_rd),
        .data_in(data_in),
        .data_out(data_out)
      );

  initial
  begin
    // VCD dump setup
    $dumpfile("tb_RAM7.vcd");   // output file
    $dumpvars(0, tb_RAM7);         // dump all variables in tb_RAM
  end

  always #5 clk_ram = ~clk_ram;
  always #10 clk_cpu = ~clk_cpu;

  initial
  begin
    // Initialize signals
    clk_cpu =1;
    clk_ram =0;
    cs = 0;
    rd = 0;
    wr = 0;
    addr_rd = 0;
    addr_wr = 0;
    data_in = 0;

    // Monitor setup
    $monitor("T=%0t | cs=%b rd=%b wr=%b addr_wr=%0d data_in=%h addr_rd=%d data_out=%h",
             $time, cs, rd, wr, addr_wr, data_in, addr_rd, data_out);

    #10 cs = 1;
    wr = 1;
    rd = 0;

    // --- Write phase ---
    addr_wr = 6'b0010_00;
    data_in = 8'hA5;

    #10 addr_wr = 6'b0101_00;
    data_in = 8'h3C;

    #10 addr_wr = 6'b1010_00;
    data_in = 8'h54;

    #10 addr_wr = 6'b1001_00;
    data_in = 8'hB8;

    // --- Read phase ---
    #10 rd = 1;
    wr = 0;

    addr_rd = 6'b1011_00; //4F
    #10 addr_rd = 6'b0001_00; //4F

    // --- Read and write ---
    #10 rd = 1;
    wr = 1;

    addr_rd = 6'b0101_00; //3C
    addr_wr = 6'b0111_00;
    data_in = 8'h83;

    #10 addr_rd = 6'b0000_00; //5F
    addr_wr = 6'b1010_00;
    data_in = 8'h67;

    #10 addr_rd = 6'b0010_00; //5F
    addr_wr = 6'b1111_00;
    data_in = 8'h67;

    #10 addr_rd = 6'b1010_00; //67
    addr_wr = 6'b1010_00;
    data_in = 8'h67;

    // Finish simulation
    #20;
    $finish;
  end

endmodule
