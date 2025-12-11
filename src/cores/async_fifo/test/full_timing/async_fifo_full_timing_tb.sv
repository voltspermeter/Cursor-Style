`timescale 1ps/1ps
`include "vunit_defines.svh"

//------------------------------------------------------------------------------
// Full Flag Timing Test
//
// Verifies full flag timing:
// - Full asserts when FIFO fills
// - Full deasserts after read
// - Full at exact capacity boundary
// - Full flag during reset
// - Conservative full assertion
//------------------------------------------------------------------------------

module async_fifo_full_timing_tb;

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
  integer write_count;
  integer full_assert_cycles;
  integer full_deassert_cycles;

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

  // Helper task: Wait for reset complete
  task automatic wait_reset_complete();
    while (DUT.wr_rst || DUT.rd_rst) @(posedge wr_clk);
    repeat(5) @(posedge wr_clk);
  endtask

  `TEST_SUITE begin

    //--------------------------------------------------------------------------
    // Test 1: Full asserts when FIFO fills
    //--------------------------------------------------------------------------
    `TEST_CASE("Full-Assert-At-Capacity") begin
      $display("Testing: Full flag assertion at capacity");
      $display("  FIFO depth: %0d entries", DEPTH);
      
      // Initialize
      rst <= 1'b1;
      wr_en <= 1'b0;
      rd_en <= 1'b0;
      wr_data <= 8'd0;
      
      repeat(20) @(posedge wr_clk);
      rst <= 1'b0;
      wait_reset_complete();
      
      // Verify not full initially
      `CHECK_EQUAL(full, 1'b0);
      
      // Fill FIFO completely
      write_count = 0;
      while (!full && write_count < DEPTH + 5) begin
        @(posedge wr_clk);
        wr_en <= 1'b1;
        wr_data <= write_count;
        @(posedge wr_clk);
        wr_en <= 1'b0;
        write_count++;
        
        if (!full) begin
          $display("  Write %0d: full=%b, wr_ptr=%0d", 
                   write_count, full, DUT.wr_ptr);
        end
      end
      
      $display("  Full asserted after %0d writes", write_count);
      
      // Full should assert at DEPTH entries
      `CHECK_TRUE(write_count >= DEPTH - 1 && write_count <= DEPTH + 1);
      `CHECK_EQUAL(full, 1'b1);
      
      $display("  PASS: Full asserts at capacity");
    end

    //--------------------------------------------------------------------------
    // Test 2: Full deasserts after read
    //--------------------------------------------------------------------------
    `TEST_CASE("Full-Deassert-After-Read") begin
      $display("Testing: Full flag deassertion after read");
      
      rst <= 1'b1;
      wr_en <= 1'b0;
      rd_en <= 1'b0;
      
      repeat(20) @(posedge wr_clk);
      rst <= 1'b0;
      wait_reset_complete();
      
      // Fill FIFO
      for (int i = 0; i < DEPTH; i++) begin
        @(posedge wr_clk);
        wr_en <= 1'b1;
        wr_data <= i;
        @(posedge wr_clk);
        wr_en <= 1'b0;
      end
      
      // Wait for full
      repeat(5) @(posedge wr_clk);
      `CHECK_EQUAL(full, 1'b1);
      
      // Read one entry
      repeat(5) @(posedge rd_clk);
      @(posedge rd_clk);
      rd_en <= 1'b1;
      @(posedge rd_clk);
      rd_en <= 1'b0;
      
      // Count cycles until full deasserts
      full_deassert_cycles = 0;
      while (full && full_deassert_cycles < 20) begin
        @(posedge wr_clk);
        full_deassert_cycles++;
      end
      
      $display("  Full deasserted after %0d wr_clk cycles", full_deassert_cycles);
      
      // Should deassert within synchronization latency (2-6 cycles)
      `CHECK_TRUE(full_deassert_cycles >= 2 && full_deassert_cycles <= 8);
      `CHECK_EQUAL(full, 1'b0);
      
      $display("  PASS: Full deasserts after read");
    end

    //--------------------------------------------------------------------------
    // Test 3: Full at exact capacity boundary
    //--------------------------------------------------------------------------
    `TEST_CASE("Full-Exact-Boundary") begin
      $display("Testing: Full at exact capacity boundary");
      
      rst <= 1'b1;
      wr_en <= 1'b0;
      rd_en <= 1'b0;
      
      repeat(20) @(posedge wr_clk);
      rst <= 1'b0;
      wait_reset_complete();
      
      // Write DEPTH-1 entries
      for (int i = 0; i < DEPTH - 1; i++) begin
        @(posedge wr_clk);
        wr_en <= 1'b1;
        wr_data <= i;
        @(posedge wr_clk);
        wr_en <= 1'b0;
      end
      
      repeat(5) @(posedge wr_clk);
      $display("  After %0d writes: full=%b", DEPTH-1, full);
      
      // Should not be full yet
      `CHECK_EQUAL(full, 1'b0);
      
      // Write one more (DEPTH-th entry)
      @(posedge wr_clk);
      wr_en <= 1'b1;
      wr_data <= DEPTH - 1;
      @(posedge wr_clk);
      wr_en <= 1'b0;
      
      // Should become full
      repeat(3) @(posedge wr_clk);
      $display("  After %0d writes: full=%b", DEPTH, full);
      `CHECK_EQUAL(full, 1'b1);
      
      $display("  PASS: Full at exact boundary correct");
    end

    //--------------------------------------------------------------------------
    // Test 4: Full flag during reset
    //--------------------------------------------------------------------------
    `TEST_CASE("Full-During-Reset") begin
      $display("Testing: Full flag during reset");
      
      rst <= 1'b1;
      wr_en <= 1'b0;
      rd_en <= 1'b0;
      
      // During reset, full should be asserted (prevent writes)
      repeat(5) @(posedge wr_clk);
      `CHECK_EQUAL(full, 1'b1);
      
      repeat(15) @(posedge wr_clk);
      rst <= 1'b0;
      
      // Wait for internal wr_rst to deassert
      while (DUT.wr_rst) @(posedge wr_clk);
      
      // full_reg deasserts one cycle after wr_rst
      repeat(3) @(posedge wr_clk);
      
      // After reset complete, full should deassert (FIFO is empty)
      `CHECK_EQUAL(full, 1'b0);
      
      $display("  PASS: Full during reset correct");
    end

    //--------------------------------------------------------------------------
    // Test 5: Conservative full (never late)
    //--------------------------------------------------------------------------
    `TEST_CASE("Conservative-Full") begin
      integer accepted_writes;
      
      $display("Testing: Conservative full assertion (never late)");
      
      rst <= 1'b1;
      wr_en <= 1'b0;
      rd_en <= 1'b0;
      
      repeat(20) @(posedge wr_clk);
      rst <= 1'b0;
      wait_reset_complete();
      
      // Try to write more than DEPTH entries
      accepted_writes = 0;
      for (int i = 0; i < DEPTH + 5; i++) begin
        @(posedge wr_clk);
        if (!full) begin
          wr_en <= 1'b1;
          wr_data <= i;
          accepted_writes++;
        end else begin
          wr_en <= 1'b0;
        end
        @(posedge wr_clk);
        wr_en <= 1'b0;
      end
      
      $display("  Attempted %0d writes, accepted %0d", DEPTH + 5, accepted_writes);
      
      // Should never accept more than DEPTH
      `CHECK_TRUE(accepted_writes <= DEPTH);
      
      // May accept fewer (conservative), but should accept at least DEPTH-2
      `CHECK_TRUE(accepted_writes >= DEPTH - 2);
      
      $display("  PASS: Full is conservative (accepted %0d/%0d)", 
               accepted_writes, DEPTH);
    end

    //--------------------------------------------------------------------------
    // Test 6: Full/not-full transitions
    //--------------------------------------------------------------------------
    `TEST_CASE("Full-Transitions") begin
      $display("Testing: Full flag transitions");
      
      rst <= 1'b1;
      wr_en <= 1'b0;
      rd_en <= 1'b0;
      
      repeat(20) @(posedge wr_clk);
      rst <= 1'b0;
      wait_reset_complete();
      
      // Multiple fill/partial-drain cycles
      for (int cycle = 0; cycle < 3; cycle++) begin
        $display("  Cycle %0d", cycle);
        
        // Fill to full
        while (!full) begin
          @(posedge wr_clk);
          wr_en <= 1'b1;
          wr_data <= cycle;
          @(posedge wr_clk);
          wr_en <= 1'b0;
        end
        
        `CHECK_EQUAL(full, 1'b1);
        $display("    Filled to full");
        
        // Read half
        repeat(5) @(posedge rd_clk);
        for (int i = 0; i < DEPTH / 2; i++) begin
          @(posedge rd_clk);
          rd_en <= 1'b1;
          @(posedge rd_clk);
          rd_en <= 1'b0;
        end
        
        // Wait for full to deassert
        repeat(10) @(posedge wr_clk);
        `CHECK_EQUAL(full, 1'b0);
        $display("    Drained half, full=%b", full);
        
        // Drain rest
        repeat(5) @(posedge rd_clk);
        while (!empty) begin
          @(posedge rd_clk);
          rd_en <= 1'b1;
          @(posedge rd_clk);
          rd_en <= 1'b0;
          @(posedge rd_clk);
        end
      end
      
      $display("  PASS: Full transitions correct");
    end

    `TEST_DONE;
  end

  `WATCHDOG(1000us);

endmodule
