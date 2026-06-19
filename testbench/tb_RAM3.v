
module tb_RAM3;
    // Testbench signals
    reg cs, rd, wr;
    reg [3:0] addr;
    reg [7:0] data_in;
    wire [7:0] data_out;

    // Instantiate DUT
    RAM3 uut (
        .cs(cs),
        .rd(rd),
        .wr(wr),
        .addr(addr),
        .data_in(data_in),
        .data_out(data_out)
    );

    initial begin
        // VCD dump setup
        $dumpfile("tb_RAM3.vcd");   // output file
        $dumpvars(0, tb_RAM3);         // dump all variables in tb_RAM 
    end

    initial begin
        // Initialize signals
        cs = 0; 
        rd = 0; 
        wr = 0;
        addr = 0; 
        data_in = 0;

        // Monitor setup
        $monitor("T=%0t | cs=%b rd=%b wr=%b addr=%0d data_drv=%h data=%h",
                  $time, cs, rd, wr, addr, data_in, data_out);

        #10 cs = 1;
        wr = 1;
        rd = 0;

        // --- Write phase ---
        addr = 4'h2;
        data_in = 8'hA5;
        
        #10 addr = 4'h5;
        data_in = 8'h3C;
       
        #10 addr = 4'hA;
        data_in = 8'h54;
        
        #10 addr = 4'h9;
        data_in = 8'hB8;

        // --- Read phase ---
        #10 rd = 1; wr = 0;

        addr = 4'h5; 

        #10 addr = 4'h9;

        #10 addr = 4'h2;

        // --- Overwrite test ---
        #10 rd = 0; wr = 1;

        addr = 4'h2;
        data_in = 8'h83;
        
        #10 addr = 4'hA;
        data_in = 8'h67;

        // Read back overwritten value
        #10 rd = 1; wr = 0;

        addr = 4'd2;

        #10 addr = 4'd3;

        // Finish simulation
        #20;
        $finish;
    end

endmodule