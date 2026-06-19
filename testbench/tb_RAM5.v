
module tb_RAM5;
    // Testbench signals
    reg cs, clk, rd, wr;
    reg [3:0] addr_rd, addr_wr;
    reg [7:0] data_in;
    wire [7:0] data_out;

    // Instantiate DUT
    RAM5 uut (
        .clk(clk),
        .cs(cs),
        .rd(rd),
        .wr(wr),
        .addr_wr(addr_wr),
        .addr_rd(addr_rd),
        .data_in(data_in),
        .data_out(data_out)
    );

    initial begin
        // VCD dump setup
        $dumpfile("tb_RAM5.vcd");   // output file
        $dumpvars(0, tb_RAM5);         // dump all variables in tb_RAM 
    end

    always #5 clk = ~clk;

    initial begin
        // Initialize signals
        clk =0;
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
        addr_wr = 4'h2;
        data_in = 8'hA5;
        
        #10 addr_wr = 4'h5;
        data_in = 8'h3C;
       
        #10 addr_wr = 4'hA;
        data_in = 8'h54;
        
        #10 addr_wr = 4'h9;
        data_in = 8'hB8;

        // --- Read phase ---
        #10 rd = 1; wr = 0;

        addr_rd = 4'hB; //4F
        #10 addr_rd = 4'h1; //6E
        
        // --- Read and write ---
        #10 rd = 1; wr = 1;

        addr_rd = 4'h5; //3C
        addr_wr = 4'h7;
        data_in = 8'h83; 

        #10 addr_rd = 4'h0; //7A
        addr_wr = 4'hA;
        data_in = 8'h67;

        #10 addr_rd = 4'h2; //A5
        addr_wr = 4'hF;
        data_in = 8'h67;

        #10 addr_rd = 4'hA; //67
        addr_wr = 4'hA;
        data_in = 8'h67;

        // Finish simulation
        #20;
        $finish;
    end

endmodule

