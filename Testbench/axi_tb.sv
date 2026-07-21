`timescale 1ns/1ps
`include "axi_if.sv"

module axi_tb;

    // Parameters
    parameter DATA_WIDTH = 32;
    parameter ADDR_WIDTH = 16;
    parameter LEN_WIDTH  = 8;
    parameter SIZE_WIDTH = 3;
    parameter MEM_DEPTH  = 1024;

    // Clock and Reset Signals
    logic ACLK;
    logic ARESETn;

    // Clock Generation (10ns period -> 100MHz)
    always #5 ACLK = ~ACLK;

    // Instantiate the AXI Interface
    axi_if #(
        .DATA_WIDTH(DATA_WIDTH),
        .ADDR_WIDTH(ADDR_WIDTH),
        .LEN_WIDTH(LEN_WIDTH),
        .SIZE_WIDTH(SIZE_WIDTH)
    ) intf (
        .ACLK(ACLK),
        .ARESETn(ARESETn)
    );

    // Instantiate the Top Level DUT (Device Under Test)
    axi_top #(
        .DATA_WIDTH(DATA_WIDTH),
        .ADDR_WIDTH(ADDR_WIDTH),
        .LEN_WIDTH(LEN_WIDTH),
        .SIZE_WIDTH(SIZE_WIDTH),
        .MEM_DEPTH(MEM_DEPTH)
    ) dut (
        .intr(intf.slave_mp)
    );

    // Scoreboard / Reference Model Memory Array to track expected data
    logic [DATA_WIDTH-1:0] scoreboard_mem [0:MEM_DEPTH-1];

    //---------------------------------------------------------
    // Task: Reset Sequence
    //---------------------------------------------------------
    task reset_dut();
        begin
            $display("[%0t] INFO: Applying Reset...", $time);
            ACLK = 0;
            ARESETn = 0;
            intf.AWADDR  = 0;
            intf.AWLEN   = 0;
            intf.AWSIZE  = 0;
            intf.AWVALID = 0;
            intf.WDATA   = 0;
            intf.WLAST   = 0;
            intf.WVALID  = 0;
            intf.BREADY  = 0;
            intf.ARADDR  = 0;
            intf.ARLEN   = 0;
            intf.ARSIZE  = 0;
            intf.ARVALID = 0;
            intf.RREADY  = 0;
            #20;
            ARESETn = 1;
            $display("[%0t] INFO: Reset Released.", $time);
            @(posedge ACLK);
        end
    endtask

    //---------------------------------------------------------
    // Task: AXI Write Transaction
    //---------------------------------------------------------
    task axi_write(
        input [ADDR_WIDTH-1:0] addr,
        input [LEN_WIDTH-1:0]  len,
        input [SIZE_WIDTH-1:0] size,
        input [DATA_WIDTH-1:0] data_arr []
    );
        integer i;
        begin
            @(posedge ACLK);
            // Drive Address Channel
            intf.AWADDR  <= addr;
            intf.AWLEN   <= len;
            intf.AWSIZE  <= size;
            intf.AWVALID <= 1'b1;
            intf.BREADY  <= 1'b1;

            // Wait for address handshake (AWREADY is hardwired to 1 in your design, but we wait safely)
            do begin
                @(posedge ACLK);
            end while (!(intf.AWVALID && intf.AWREADY));
            
            intf.AWVALID <= 1'b0;

            // Drive Data Channel beats
            for (i = 0; i <= len; i = i + 1) begin
                intf.WDATA  <= data_arr[i];
                intf.WVALID <= 1'b1;
                intf.WLAST  <= (i == len) ? 1'b1 : 1'b0;

                // Wait for WREADY handshake
                do begin
                    @(posedge ACLK);
                end while (!(intf.WVALID && intf.WREADY));

                // Update Scoreboard if within valid memory bounds and legal settings
                // (Assuming word-aligned address shifts for basic tracking)
                if ((addr >> 2) + i < MEM_DEPTH) begin
                    scoreboard_mem[(addr >> 2) + i] = data_arr[i];
                end
            end

            intf.WVALID <= 1'b0;
            intf.WLAST  <= 1'b0;

            // Wait for Write Response (BVALID)
            do begin
                @(posedge ACLK);
            end while (!intf.BVALID);

            if (intf.BRESP == 2'b00) 
                $display("[%0t] WRITE OKAY Response received for Addr=0x%0h", $time, addr);
            else 
                $display("[%0t] WRITE SLVERR Response received (Expected if out of range) for Addr=0x%0h", $time, addr);

            @(posedge ACLK);
            intf.BREADY <= 1'b0;
        end
    endtask

    //---------------------------------------------------------
    // Task: AXI Read Transaction
    //---------------------------------------------------------
    task axi_read(
        input [ADDR_WIDTH-1:0] addr,
        input [LEN_WIDTH-1:0]  len,
        input [SIZE_WIDTH-1:0] size
    );
        integer i;
        logic [DATA_WIDTH-1:0] expected_data;
        begin
            @(posedge ACLK);
            // Drive Read Address Channel
            intf.ARADDR  <= addr;
            intf.ARLEN   <= len;
            intf.ARSIZE  <= size;
            intf.ARVALID <= 1'b1;
            intf.RREADY  <= 1'b1;

            // Wait for ARREADY handshake
            do begin
                @(posedge ACLK);
            end while (!(intf.ARVALID && intf.ARREADY));

            intf.ARVALID <= 1'b0;

            // Read Data Beats
            for (i = 0; i <= len; i = i + 1) begin
                do begin
                    @(posedge ACLK);
                end while (!intf.RVALID);

                if (intf.RRESP == 2'b01) begin
                    $display("[%0t] READ SLVERR captured on beat %0d for Addr=0x%0h", $time, i, addr);
                end else begin
                    if ((addr >> 2) + i < MEM_DEPTH) begin
                        expected_data = scoreboard_mem[(addr >> 2) + i];
                        if (intf.RDATA !== expected_data) begin
                            $error("[%0t] DATA MISMATCH! Addr: 0x%0h | Expected: 0x%0h | Got: 0x%0h", 
                                    $time, addr + (i << size), expected_data, intf.RDATA);
                        end else begin
                            $display("[%0t] READ MATCH: Addr=0x%0h, Data=0x%0h", $time, addr + (i << size), intf.RDATA);
                        end
                    end
                end

                if (intf.RLAST) begin
                    if (i !== len) 
                        $warning("[%0t] RLAST asserted prematurely at beat %0d (Expected len: %0d)", $time, i, len);
                    break;
                end
            end

            @(posedge ACLK);
            intf.RREADY <= 1'b0;
        end
    endtask

    //---------------------------------------------------------
    // Stimulus Execution Block
    //---------------------------------------------------------
    initial begin
        // Local arrays for burst testing
        logic [DATA_WIDTH-1:0] test_data_burst [0:3];
        
        reset_dut();

        // Test 1: Normal Single/Burst Write and Read within memory range
        $display("\n--- TEST 1: Standard Write/Read Burst Within Bounds ---");
        test_data_burst[0] = 32'hDEADBEEF;
        test_data_burst[1] = 32'h12345678;
        test_data_burst[2] = 32'hCAFEBABE;
        test_data_burst[3] = 32'h87654321;
        
        axi_write(16'h0010, 3, 3'h2, test_data_burst); // Byte address 0x10 -> Word 4, Len 3 (4 beats)
        #50;
        axi_read(16'h0010, 3, 3'h2);

        #100;

        // Test 2: Out of Memory Range Check (Should trigger SLVERR response)
        $display("\n--- TEST 2: Out of Range Memory Boundary Check ---");
        test_data_burst[0] = 32'h11111111;
        test_data_burst[1] = 32'h22222222;
        
        // Exceeding MEM_DEPTH (MEM_DEPTH = 1024 words = 4096 bytes)
        axi_write(16'h1000, 1, 3'h2, test_data_burst); 
        #50;
        axi_read(16'h1000, 1, 3'h2);

        #100;
        $display("\n--- SIMULATION COMPLETED ---");
        $finish;
    end

    //---------------------------------------------------------
    // Protocol Error Monitors / Checkers
    //---------------------------------------------------------
    // Monitor FSM Lockups or stuck signals
    initial begin
        // Watch for infinite wait loops on control signals
        fork
            begin
                wait(intf.AWVALID && !intf.AWREADY);
                #1000;
                $error("[MONITOR ERROR] AWREADY stuck low for too long!");
            end
            begin
                wait(intf.ARVALID && !intf.ARREADY);
                #1000;
                $error("[MONITOR ERROR] ARREADY stuck low for too long!");
            end
        join_any
    end

endmodule