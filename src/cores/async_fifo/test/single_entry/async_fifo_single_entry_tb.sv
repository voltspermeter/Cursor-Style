`timescale 1ps/1ps
`include "vunit_defines.svh"

//------------------------------------------------------------------------------
// Single Entry Test
//
// Verifies operation with single entry in FIFO (FWFT variant):
// - Write one, read one cycles
// - Latency verification
// - Flag verification for single entry
//------------------------------------------------------------------------------

module async_fifo_single_entry_tb;

  // Parameters
  localparam DATA_WIDTH = 8;
  localparam ADDR_WIDTH = 4;
  localparam DEPTH = 2**ADDR_WIDTH;

  // Signals
  logic rst;
  logic wr_clk = 1'b0;
  logic rd_clk = 1'b0;
  logic wr_en;
  logic rd_en;
  logic [DATA_WIDTH-1:0] wr_data;
  wire [DATA_WIDTH-1:0] rd_data;
  wire full, empty, has_data;

  // Test tracking
  logic [DATA_WIDTH-1:0] read_val;
  time write_time, data_valid_time;
  integer latency_cycles;

  // Clock generation
  always #10000 wr_clk <= !wr_clk;
  always #10000 rd_clk <= !rd_clk;

  // DUT instantiation - FWFT variant
  async_fifo_fwft #(
        .DATA_WIDTH(DATA_WIDTH)
      , .ADDR_WIDTH(ADDR_WIDTH)
  ) DUT (
        .rst(rst)
      , .wr_clk(wr_clk)
      , .wr_en(wr_en)
      , .wr_data(wr_data)
      , .full(full)
      , .rd_clk(rd_clk)
      , .rd_en(rd_en)
      , .rd_data(rd_data)
      , .empty(empty)
      , .has_data(has_data)
  );

  // VCD generation
  initial begin
    $dumpfile("test_case_1.vcd");
    $dumpvars();
  end

  // Helper task: Wait for reset complete
  task automatic wait_reset_complete();
    while (DUT.FIFO_INST.wr_rst || DUT.rd_rst) @(posedge wr_clk);
    repeat(5) @(posedge wr_clk);
  endtask

  `TEST_SUITE begin

    //--------------------------------------------------------------------------
    // Test 1: Single entry write/read cycles
    //--------------------------------------------------------------------------
    `TEST_CASE("Single-Entry-Cycles") begin
      integer count = 50;
      
      $display("Testing: Single entry write/read cycles (%0d iterations)", count);
      
      rst <= 1'b1;
      wr_en <= 1'b0;
      rd_en <= 1'b0;
      
      repeat(20) @(posedge wr_clk);
      rst <= 1'b0;
      wait_reset_complete();
      
      for (int i = 0; i < count; i++) begin
        // Verify empty
        `CHECK_EQUAL(empty, 1'b1);
        `CHECK_EQUAL(has_data, 1'b0);
        
        // Write one entry
        @(posedge wr_clk);
        wr_en <= 1'b1;
        wr_data <= i;
        @(posedge wr_clk);
        wr_en <= 1'b0;
        
        // Wait for data visible (FWFT - should be quick)
        while (empty) @(posedge rd_clk);
        
        // Verify flags
        `CHECK_EQUAL(empty, 1'b0);
        `CHECK_EQUAL(has_data, 1'b1);
        `CHECK_EQUAL(full, 1'b0);
        
        // FWFT: data should already be on rd_data
        read_val = rd_data;
        `CHECK_EQUAL(read_val, i);
        
        // Read the entry
        @(posedge rd_clk);
        rd_en <= 1'b1;
        @(posedge rd_clk);
        rd_en <= 1'b0;
        
        // Wait for empty
        repeat(3) @(posedge rd_clk);
      end
      
      $display("  PASS: Single entry cycles");
    end

    //--------------------------------------------------------------------------
    // Test 2: FWFT latency measurement
    //--------------------------------------------------------------------------
    `TEST_CASE("FWFT-Latency") begin
      $display("Testing: FWFT latency measurement");
      
      rst <= 1'b1;
      wr_en <= 1'b0;
      rd_en <= 1'b0;
      
      repeat(20) @(posedge wr_clk);
      rst <= 1'b0;
      wait_reset_complete();
      
      // Measure multiple times
      for (int trial = 0; trial < 5; trial++) begin
        // Ensure empty
        while (!empty) begin
          @(posedge rd_clk);
          rd_en <= 1'b1;
          @(posedge rd_clk);
          rd_en <= 1'b0;
          @(posedge rd_clk);
        end
        
        // Write and measure time to has_data
        @(posedge wr_clk);
        write_time = $time;
        wr_en <= 1'b1;
        wr_data <= trial + 100;
        @(posedge wr_clk);
        wr_en <= 1'b0;
        
        // Count cycles until has_data
        latency_cycles = 0;
        while (!has_data && latency_cycles < 20) begin
          @(posedge rd_clk);
          latency_cycles++;
        end
        data_valid_time = $time;
        
        $display("  Trial %0d: latency = %0d rd_clk cycles", trial, latency_cycles);
        
        // FWFT latency should be 2-6 cycles (synchronization)
        `CHECK_TRUE(latency_cycles >= 2 && latency_cycles <= 8);
        
        // Verify data is immediately available
        read_val = rd_data;
        `CHECK_EQUAL(read_val, trial + 100);
        
        // Consume the entry
        @(posedge rd_clk);
        rd_en <= 1'b1;
        @(posedge rd_clk);
        rd_en <= 1'b0;
        repeat(3) @(posedge rd_clk);
      end
      
      $display("  PASS: FWFT latency verified");
    end

    //--------------------------------------------------------------------------
    // Test 3: Single entry flag transitions
    //--------------------------------------------------------------------------
    `TEST_CASE("Single-Entry-Flags") begin
      $display("Testing: Flag transitions for single entry");
      
      rst <= 1'b1;
      wr_en <= 1'b0;
      rd_en <= 1'b0;
      
      repeat(20) @(posedge wr_clk);
      rst <= 1'b0;
      wait_reset_complete();
      
      // Initial state
      repeat(3) @(posedge rd_clk);
      $display("  Initial: empty=%b, has_data=%b, full=%b", empty, has_data, full);
      `CHECK_EQUAL(empty, 1'b1);
      `CHECK_EQUAL(has_data, 1'b0);
      `CHECK_EQUAL(full, 1'b0);
      
      // Write one
      @(posedge wr_clk);
      wr_en <= 1'b1;
      wr_data <= 8'hAB;
      @(posedge wr_clk);
      wr_en <= 1'b0;
      
      // Wait for visible
      while (empty) @(posedge rd_clk);
      
      $display("  After write: empty=%b, has_data=%b, full=%b", empty, has_data, full);
      `CHECK_EQUAL(empty, 1'b0);
      `CHECK_EQUAL(has_data, 1'b1);
      `CHECK_EQUAL(full, 1'b0);  // Not full with 1 entry
      
      // Read it
      @(posedge rd_clk);
      rd_en <= 1'b1;
      @(posedge rd_clk);
      rd_en <= 1'b0;
      
      // Wait for empty
      repeat(5) @(posedge rd_clk);
      
      $display("  After read: empty=%b, has_data=%b, full=%b", empty, has_data, full);
      `CHECK_EQUAL(empty, 1'b1);
      `CHECK_EQUAL(has_data, 1'b0);
      
      $display("  PASS: Single entry flags");
    end

    //--------------------------------------------------------------------------
    // Test 4: Rapid single entry operations
    //--------------------------------------------------------------------------
    `TEST_CASE("Rapid-Single-Entry") begin
      integer count = 100;
      
      $display("Testing: Rapid single entry operations");
      
      rst <= 1'b1;
      wr_en <= 1'b0;
      rd_en <= 1'b0;
      
      repeat(20) @(posedge wr_clk);
      rst <= 1'b0;
      wait_reset_complete();
      
      // Rapid write/read with minimal delay
      for (int i = 0; i < count; i++) begin
        // Write
        @(posedge wr_clk);
        wr_en <= 1'b1;
        wr_data <= i;
        @(posedge wr_clk);
        wr_en <= 1'b0;
        
        // Immediate read attempt (may need to wait)
        while (empty) @(posedge rd_clk);
        
        // Verify FWFT data
        read_val = rd_data;
        `CHECK_EQUAL(read_val, i);
        
        // Consume
        @(posedge rd_clk);
        rd_en <= 1'b1;
        @(posedge rd_clk);
        rd_en <= 1'b0;
        
        // Minimal wait before next
        @(posedge rd_clk);
      end
      
      $display("  PASS: Rapid single entry operations");
    end

    //--------------------------------------------------------------------------
    // Test 5: Single entry data integrity
    //--------------------------------------------------------------------------
    `TEST_CASE("Single-Entry-Integrity") begin
      logic [DATA_WIDTH-1:0] pattern;
      
      $display("Testing: Single entry data integrity");
      
      rst <= 1'b1;
      wr_en <= 1'b0;
      rd_en <= 1'b0;
      
      repeat(20) @(posedge wr_clk);
      rst <= 1'b0;
      wait_reset_complete();
      
      // Test each pattern
      for (int p = 0; p < 8; p++) begin
        // Select pattern
        case (p)
          0: pattern = 8'h00;
          1: pattern = 8'hFF;
          2: pattern = 8'hAA;
          3: pattern = 8'h55;
          4: pattern = 8'h0F;
          5: pattern = 8'hF0;
          6: pattern = 8'h5A;
          7: pattern = 8'hA5;
        endcase
        
        // Write pattern
        @(posedge wr_clk);
        wr_en <= 1'b1;
        wr_data <= pattern;
        @(posedge wr_clk);
        wr_en <= 1'b0;
        
        // Wait and verify
        while (empty) @(posedge rd_clk);
        
        read_val = rd_data;
        `CHECK_EQUAL(read_val, pattern);
        
        // Consume
        @(posedge rd_clk);
        rd_en <= 1'b1;
        @(posedge rd_clk);
        rd_en <= 1'b0;
        
        // Wait for empty
        repeat(3) @(posedge rd_clk);
        `CHECK_EQUAL(empty, 1'b1);
      end
      
      $display("  PASS: Single entry data integrity");
    end

    `TEST_DONE;
  end

  `WATCHDOG(3000us);

endmodule
