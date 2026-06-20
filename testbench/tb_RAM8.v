`timescale 1ns/1ps

module tb_RAM8;

    // Parameters matching the design instantiation
    parameter WORD_SIZE  = 1;
    parameter BLOCK_SIZE = 4;
    parameter RAM_SIZE   = 16; // Using 16 blocks to fit 6-bit address space
    
    // Derived Localparams for bus sizing
    localparam DATA_WIDTH = WORD_SIZE * 8;
    localparam ADDR_WIDTH = $clog2(RAM_SIZE * BLOCK_SIZE); // log2(16 * 4) = 6 bits

    // Testbench Driver Signals
    reg                     clk;
    reg                     rst_n;
    reg                     cs;
    reg                     req;
    reg                     cmd;
    reg [ADDR_WIDTH-1:0]    addr;
    reg [DATA_WIDTH-1:0]    data_in;
    
    // Monitored Outputs from DUT
    wire [DATA_WIDTH-1:0]   data_out;
    wire                    ready;
    wire                    done;

    // =========================================================================
    // 1. DUT Instantiation (Aligned with corrected FSM Ports)
    // =========================================================================
    RAM8 # (
        .Word_size(WORD_SIZE),
        .Block_size(BLOCK_SIZE),
        .RAM_size(RAM_SIZE)
    ) uut (
        .clk(clk),
        .rst_n(rst_n),
        .cs(cs),
        .req(req),
        .cmd(cmd),
        .addr(addr),
        .data_in(data_in),
        .data_out(data_out),
        .ready(ready),
        .done(done)
    );

    // =========================================================================
    // 2. Clock Generator (50 MHz / 20ns Period)
    // =========================================================================
    always #10 clk = ~clk;

    // =========================================================================
    // 3. Simulation Control & Stimulus Matrix
    // =========================================================================
    initial begin
        // Signal Initialization
        clk     = 0;
        rst_n   = 0;
        cs      = 0;
        req     = 0;
        cmd     = 0;
        addr    = 0;
        data_in = 0;

        // VCD Dump Setup for GTKWave
        $dumpfile("tb_RAM8.vcd");
        $dumpvars(0, tb_RAM8);

        // Modern Monitor Setup Tracker
        $monitor("T=%0t | cs=%b req=%b cmd=%b (1=W,0=R) | addr=%0d data_in=%h | ready=%b done=%b data_out=%h",
                 $time, cs, req, cmd, addr, data_in, ready, done, data_out);

        // --- Release Reset ---
        #25 rst_n = 1;
        #10 cs    = 1; // Assert Chip Select

        // =========================================================================
        // WRITE PHASE (cmd = 1)
        // =========================================================================
        // Write 1: Store 0xA5 at Address 8
        wait(ready);
        @(posedge clk);
        req     <= 1;
        cmd     <= 1; // Write Command
        addr    <= 6'b0010_00; // Address 8
        data_in <= 8'hA5;
        @(posedge clk) req <= 0; // Drop request, wait for controller execution
        wait(done);

        // Write 2: Store 0x3C at Address 20
        wait(ready);
        @(posedge clk);
        req     <= 1;
        cmd     <= 1;
        addr    <= 6'b0101_00; // Address 20
        data_in <= 8'h3C;
        @(posedge clk) req <= 0;
        wait(done);

        // Write 3: Store 0x54 at Address 40
        wait(ready);
        @(posedge clk);
        req     <= 1;
        cmd     <= 1;
        addr    <= 6'b1010_00; // Address 40
        data_in <= 8'h54;
        @(posedge clk) req <= 0;
        wait(done);

        // =========================================================================
        // READ PHASE (cmd = 0)
        // =========================================================================
        // Read 1: Target empty/unitialized memory slot at Address 44
        wait(ready);
        @(posedge clk);
        req  <= 1;
        cmd  <= 0; // Read Command
        addr <= 6'b1011_00; // Address 44
        @(posedge clk) req <= 0;
        wait(done);

        // Read 2: Fetch data from Address 20 (Should return 0x3C from our Write 2)
        wait(ready);
        @(posedge clk);
        req  <= 1;
        cmd  <= 0;
        addr <= 6'b0101_00; // Address 20
        @(posedge clk) req <= 0;
        wait(done);

        // Read 3: Fetch data from Address 8 (Should return 0xA5 from our Write 1)
        wait(ready);
        @(posedge clk);
        req  <= 1;
        cmd  <= 0;
        addr <= 6'b0010_00; // Address 8
        @(posedge clk) req <= 0;
        wait(done);

        // Clean Wrap Up
        #40;
        cs = 0;
        $finish;
    end

endmodule