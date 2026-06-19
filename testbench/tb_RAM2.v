
module tb_RAM2;

    // Testbench signals
    reg cs, rd, wr,ale;
    //reg [3:0] addr;
    wire [7:0] data;

    // Drive data bus from testbench
    reg [7:0] data_drv;
    assign data = ((cs && wr && !rd)||(ale)) ? data_drv : 8'bz;

    // Instantiate DUT
    RAM2 uut (
        .cs(cs),
        .rd(rd),
        .wr(wr),
        .ale(ale),
        .data(data)
    );

    initial begin
        // VCD dump setup
        $dumpfile("tb_RAM2.vcd");   // output file
        $dumpvars(0, tb_RAM2);         // dump all variables in tb_RAM 
    end

    initial begin
        // Initialize signals
        cs = 0; 
        rd = 0; 
        wr = 0;
        ale = 0;
        //addr = 0; 
        data_drv = 0;

        // Monitor setup
        $monitor("T=%0t | cs=%b rd=%b wr=%b, ale=%b, addr=%0d data_drv=%h data=%h",
                  $time, cs, rd, wr, ale, data_drv[3:0], data_drv, data);

        #10 cs = 1;
        wr = 1;
        rd = 0;
        ale = 1;

        // --- Write phase ---
        data_drv = 4'h2;
        #10 ale = 0;
        data_drv = 8'hA5;
        
        #10 ale = 1;
        data_drv = 4'h5;
        #10 ale = 0;
        data_drv = 8'h3C;
       
        #10  ale = 1;
        data_drv = 4'hA;
        #10 ale = 0;
        data_drv = 8'h54;
        
        #10  ale = 1;
        data_drv = 4'h9;
        #10 ale = 0;
        data_drv = 8'hB8;

        // --- Read phase ---
        #10 rd = 1; wr = 0; ale =1;

        data_drv = 4'h5;
        #10 ale = 0;
        
        #10  ale = 1;
        data_drv = 4'h9;
        #10 ale = 0;

        #10 ale = 1;
        data_drv = 4'h2;
        #10 ale = 0;

        // --- Overwrite test ---
        #10 rd = 0; wr = 1; ale =1;

        data_drv = 4'h2;
        #10 ale = 0;
        data_drv = 8'h83;
        
        #10  ale = 1;
        data_drv = 4'hA;
        #10 ale = 0;
        data_drv = 8'h67;

        // Read back overwritten value
        #10 rd = 1; wr = 0; ale = 1;

        
        data_drv = 4'h2;
        #10 ale = 0;

        #10 ale = 1;
        data_drv = 4'h3;
        #10 ale = 0;

        // Finish simulation
        #20;
        $finish;
    end

endmodule

// RAM1 : single port with common read and write port
//         markdown/RAM_1.md : module details
//         rtl_design/RAM_1.v : rtl design code
//         testbench/tb_RAM1.v : testbench for simulation
//         waveform/RAM1.png : simulation gtk wavefrom
