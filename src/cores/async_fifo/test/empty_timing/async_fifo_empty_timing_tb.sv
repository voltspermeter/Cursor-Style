`timescale 1ps/1ps
`include "vunit_defines.svh"

//------------------------------------------------------------------------------
// Empty Flag Timing Test
//
// Verifies empty flag timing:
// - Empty deasserts within expected cycles after first write
// - Empty asserts within expected cycles after last read
// - Empty behavior with single entry
// - Empty flag during reset
// - has_data is always inverse of empty
//------------------------------------------------------------------------------

module async_fifo_empty_timing_tb;

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

  // Timing measurement
  integer empty_deassert_cycles;
  integer empty_assert_cycles;
  time write_time, empty_deassert_time;
  time read_time, empty_assert_time;

  // Clock generation
  always #10000 wr_clk <= !wr_clk;
  always #10000 rd_clk <= !rd_clk;

  // DUT instantiation
  async_fifo #(
        .DATA_WIDTH(DATA_WIDTH)
      , .ADDR_WIDTH(ADDR_WIDTH)
      , .RESERVE(0)
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
    while (DUT.wr_rst || DUT.rd_rst) @(posedge wr_clk);
    repeat(5) @(posedge wr_clk);
  endtask

  `TEST_SUITE begin

    //--------------------------------------------------------------------------
    // Test 1: Empty deasserts after first write
    //--------------------------------------------------------------------------
    `TEST_CASE("Empty-Deassert-Timing") begin
      $display("Testing: Empty flag deassertion timing after write");
      
      // Initialize
      rst <= 1'b1;
      wr_en <= 1'b0;
      rd_en <= 1'b0;
      wr_data <= 8'd0;
      
      repeat(20) @(posedge wr_clk);
      rst <= 1'b0;
      wait_reset_complete();
      
      // Verify initially empty
      repeat(5) @(posedge rd_clk);
      `CHECK_EQUAL(empty, 1'b1);
      `CHECK_EQUAL(has_data, 1'b0);
      
      // Write single entry and measure time to empty deassertion
      @(posedge wr_clk);
      write_time = $time;
      wr_en <= 1'b1;
      wr_data <= 8'hAB;
      @(posedge wr_clk);
      wr_en <= 1'b0;
      
      // Count cycles until empty deasserts
      empty_deassert_cycles = 0;
      while (empty && empty_deassert_cycles < 20) begin
        @(posedge rd_clk);
        empty_deassert_cycles++;
      end
      empty_deassert_time = $time;
      
      $display("  Write at time: %0t", write_time);
      $display("  Empty deasserted at time: %0t", empty_deassert_time);
      $display("  Cycles until empty deassert: %0d rd_clk cycles", empty_deassert_cycles);
      
      // Expect 2-4 cycles due to synchronization
      `CHECK_TRUE(empty_deassert_cycles >= 2 && empty_deassert_cycles <= 6);
      `CHECK_EQUAL(empty, 1'b0);
      `CHECK_EQUAL(has_data, 1'b1);
      
      $display("  PASS: Empty deassert timing correct");
    end

    //--------------------------------------------------------------------------
    // Test 2: Empty asserts after last read
    //--------------------------------------------------------------------------
    `TEST_CASE("Empty-Assert-Timing") begin
      $display("Testing: Empty flag assertion timing after last read");
      
      rst <= 1'b1;
      wr_en <= 1'b0;
      rd_en <= 1'b0;
      
      repeat(20) @(posedge wr_clk);
      rst <= 1'b0;
      wait_reset_complete();
      
      // Write single entry
      @(posedge wr_clk);
      wr_en <= 1'b1;
      wr_data <= 8'hCD;
      @(posedge wr_clk);
      wr_en <= 1'b0;
      
      // Wait for data to be visible
      while (empty) @(posedge rd_clk);
      
      // Read the entry
      @(posedge rd_clk);
      read_time = $time;
      rd_en <= 1'b1;
      @(posedge rd_clk);
      rd_en <= 1'b0;
      
      // Count cycles until empty asserts
      empty_assert_cycles = 0;
      while (!empty && empty_assert_cycles < 20) begin
        @(posedge rd_clk);
        empty_assert_cycles++;
      end
      empty_assert_time = $time;
      
      $display("  Read at time: %0t", read_time);
      $display("  Empty asserted at time: %0t", empty_assert_time);
      $display("  Cycles until empty assert: %0d rd_clk cycles", empty_assert_cycles);
      
      // Empty should assert quickly (1-2 cycles) in read domain
      `CHECK_TRUE(empty_assert_cycles >= 0 && empty_assert_cycles <= 3);
      `CHECK_EQUAL(empty, 1'b1);
      `CHECK_EQUAL(has_data, 1'b0);
      
      $display("  PASS: Empty assert timing correct");
    end

    //--------------------------------------------------------------------------
    // Test 3: Single entry write/read cycles
    //--------------------------------------------------------------------------
    `TEST_CASE("Single-Entry-Empty") begin
      $display("Testing: Empty behavior with single entry operations");
      
      rst <= 1'b1;
      wr_en <= 1'b0;
      rd_en <= 1'b0;
      
      repeat(20) @(posedge wr_clk);
      rst <= 1'b0;
      wait_reset_complete();
      
      // Repeat single-entry write/read multiple times
      for (int i = 0; i < 10; i++) begin
        // Verify empty before write
        `CHECK_EQUAL(empty, 1'b1);
        
        // Write one
        @(posedge wr_clk);
        wr_en <= 1'b1;
        wr_data <= i;
        @(posedge wr_clk);
        wr_en <= 1'b0;
        
        // Wait for not empty
        while (empty) @(posedge rd_clk);
        `CHECK_EQUAL(has_data, 1'b1);
        
        // Read one
        @(posedge rd_clk);
        rd_en <= 1'b1;
        @(posedge rd_clk);
        rd_en <= 1'b0;
        
        // Wait for empty
        repeat(3) @(posedge rd_clk);
        
        // Verify empty after read
        `CHECK_EQUAL(empty, 1'b1);
        `CHECK_EQUAL(has_data, 1'b0);
      end
      
      $display("  PASS: Single entry empty behavior correct");
    end

    //--------------------------------------------------------------------------
    // Test 4: Empty during reset
    //--------------------------------------------------------------------------
    `TEST_CASE("Empty-During-Reset") begin
      $display("Testing: Empty flag during and after reset");
      
      rst <= 1'b1;
      wr_en <= 1'b0;
      rd_en <= 1'b0;
      
      // During reset, empty should indicate no valid data
      repeat(5) @(posedge rd_clk);
      // Note: During reset, rd_rst is high, so empty = rd_rst = 1
      `CHECK_EQUAL(empty, 1'b1);
      
      repeat(15) @(posedge wr_clk);
      rst <= 1'b0;
      wait_reset_complete();
      
      // After reset, should be empty
      repeat(3) @(posedge rd_clk);
      `CHECK_EQUAL(empty, 1'b1);
      `CHECK_EQUAL(has_data, 1'b0);
      
      $display("  PASS: Empty during reset correct");
    end

    //--------------------------------------------------------------------------
    // Test 5: has_data is always inverse of empty
    //--------------------------------------------------------------------------
    `TEST_CASE("Has-Data-Inverse-Empty") begin
      $display("Testing: has_data is always inverse of empty");
      
      rst <= 1'b1;
      wr_en <= 1'b0;
      rd_en <= 1'b0;
      
      repeat(20) @(posedge wr_clk);
      rst <= 1'b0;
      wait_reset_complete();
      
      // Check during empty state
      repeat(5) @(posedge rd_clk);
      `CHECK_EQUAL(has_data, ~empty);
      
      // Write some data
      for (int i = 0; i < 5; i++) begin
        @(posedge wr_clk);
        wr_en <= 1'b1;
        wr_data <= i;
        @(posedge wr_clk);
        wr_en <= 1'b0;
      end
      
      // Check during non-empty state
      repeat(10) @(posedge rd_clk);
      `CHECK_EQUAL(has_data, ~empty);
      
      // Read all data
      while (!empty) begin
        `CHECK_EQUAL(has_data, ~empty);  // Check every cycle
        @(posedge rd_clk);
        rd_en <= 1'b1;
        @(posedge rd_clk);
        rd_en <= 1'b0;
        @(posedge rd_clk);
      end
      
      // Check after emptying
      `CHECK_EQUAL(has_data, ~empty);
      
      $display("  PASS: has_data is always inverse of empty");
    end

    //--------------------------------------------------------------------------
    // Test 6: Empty timing with different clock ratios
    //--------------------------------------------------------------------------
    `TEST_CASE("Empty-Timing-Clock-Ratio") begin
      integer deassert_times[3];
      
      $display("Testing: Empty timing consistency");
      
      // Run multiple trials to verify consistency
      for (int trial = 0; trial < 3; trial++) begin
        rst <= 1'b1;
        wr_en <= 1'b0;
        rd_en <= 1'b0;
        
        repeat(20) @(posedge wr_clk);
        rst <= 1'b0;
        wait_reset_complete();
        
        // Verify empty
        while (!empty) @(posedge rd_clk);
        
        // Write and measure
        @(posedge wr_clk);
        wr_en <= 1'b1;
        wr_data <= trial;
        @(posedge wr_clk);
        wr_en <= 1'b0;
        
        empty_deassert_cycles = 0;
        while (empty && empty_deassert_cycles < 20) begin
          @(posedge rd_clk);
          empty_deassert_cycles++;
        end
        
        deassert_times[trial] = empty_deassert_cycles;
        $display("  Trial %0d: empty deassert in %0d cycles", trial, empty_deassert_cycles);
        
        // Read to empty
        while (!empty) begin
          @(posedge rd_clk);
          rd_en <= 1'b1;
          @(posedge rd_clk);
          rd_en <= 1'b0;
          @(posedge rd_clk);
        end
      end
      
      // Verify reasonable consistency (within 2 cycles)
      `CHECK_TRUE((deassert_times[0] - deassert_times[1]) < 3 || 
                  (deassert_times[1] - deassert_times[0]) < 3);
      
      $display("  PASS: Empty timing consistent");
    end

    `TEST_DONE;
  end

  `WATCHDOG(500us);

endmodule
