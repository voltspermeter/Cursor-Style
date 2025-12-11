`timescale 1ps/1ps
`include "vunit_defines.svh"

//------------------------------------------------------------------------------
// Near-Empty Threshold Test
//
// Verifies behavior near empty condition:
// - Read to 1 entry remaining, verify not empty
// - Read last entry, verify empty
// - Operate at 1 entry for extended period
// - has_data vs empty consistency
//------------------------------------------------------------------------------

module async_fifo_near_empty_tb;

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
  integer write_count;
  integer read_count;
  logic [DATA_WIDTH-1:0] read_val;

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
    // Test 1: Read to 1 entry remaining, verify not empty
    //--------------------------------------------------------------------------
    `TEST_CASE("One-Entry-Not-Empty") begin
      $display("Testing: Read to 1 entry remaining, verify not empty");
      
      rst <= 1'b1;
      wr_en <= 1'b0;
      rd_en <= 1'b0;
      
      repeat(20) @(posedge wr_clk);
      rst <= 1'b0;
      wait_reset_complete();
      
      // Write 5 entries
      for (int i = 0; i < 5; i++) begin
        @(posedge wr_clk);
        wr_en <= 1'b1;
        wr_data <= i;
        @(posedge wr_clk);
        wr_en <= 1'b0;
      end
      
      // Wait for data propagation
      repeat(10) @(posedge rd_clk);
      
      // Read 4 entries, leaving 1
      for (int i = 0; i < 4; i++) begin
        @(posedge rd_clk);
        rd_en <= 1'b1;
        @(posedge rd_clk);
        rd_en <= 1'b0;
        @(posedge rd_clk);
      end
      
      // Verify not empty with 1 entry
      repeat(5) @(posedge rd_clk);
      $display("  With 1 entry: empty=%b, has_data=%b", empty, has_data);
      `CHECK_EQUAL(empty, 1'b0);
      `CHECK_EQUAL(has_data, 1'b1);
      
      $display("  PASS: 1 entry remaining is not empty");
    end

    //--------------------------------------------------------------------------
    // Test 2: Read last entry, verify empty
    //--------------------------------------------------------------------------
    `TEST_CASE("Last-Entry-Empty") begin
      $display("Testing: Read last entry, verify empty");
      
      rst <= 1'b1;
      wr_en <= 1'b0;
      rd_en <= 1'b0;
      
      repeat(20) @(posedge wr_clk);
      rst <= 1'b0;
      wait_reset_complete();
      
      // Write 3 entries
      for (int i = 0; i < 3; i++) begin
        @(posedge wr_clk);
        wr_en <= 1'b1;
        wr_data <= i;
        @(posedge wr_clk);
        wr_en <= 1'b0;
      end
      
      repeat(10) @(posedge rd_clk);
      
      // Read 2 entries
      for (int i = 0; i < 2; i++) begin
        @(posedge rd_clk);
        rd_en <= 1'b1;
        @(posedge rd_clk);
        rd_en <= 1'b0;
        @(posedge rd_clk);
      end
      
      // Verify still has 1 entry
      repeat(3) @(posedge rd_clk);
      `CHECK_EQUAL(empty, 1'b0);
      
      // Read last entry
      @(posedge rd_clk);
      rd_en <= 1'b1;
      @(posedge rd_clk);
      rd_en <= 1'b0;
      
      // Verify empty
      repeat(5) @(posedge rd_clk);
      $display("  After reading last entry: empty=%b, has_data=%b", empty, has_data);
      `CHECK_EQUAL(empty, 1'b1);
      `CHECK_EQUAL(has_data, 1'b0);
      
      $display("  PASS: Last entry read triggers empty");
    end

    //--------------------------------------------------------------------------
    // Test 3: Operate at 1 entry for extended period
    //--------------------------------------------------------------------------
    `TEST_CASE("Sustained-Near-Empty") begin
      integer cycles = 100;
      integer expected = 0;
      
      $display("Testing: Operate at 1 entry for %0d cycles", cycles);
      
      rst <= 1'b1;
      wr_en <= 1'b0;
      rd_en <= 1'b0;
      
      repeat(20) @(posedge wr_clk);
      rst <= 1'b0;
      wait_reset_complete();
      
      // Start with 1 entry
      @(posedge wr_clk);
      wr_en <= 1'b1;
      wr_data <= 0;
      @(posedge wr_clk);
      wr_en <= 1'b0;
      
      write_count = 1;
      repeat(10) @(posedge rd_clk);
      
      // Maintain 1 entry: read one, write one
      for (int cycle = 0; cycle < cycles; cycle++) begin
        // Read one
        while (empty) @(posedge rd_clk);
        @(posedge rd_clk);
        rd_en <= 1'b1;
        @(posedge rd_clk);
        rd_en <= 1'b0;
        @(posedge rd_clk);
        read_val = rd_data;
        `CHECK_EQUAL(read_val, expected);
        expected++;
        
        // Write one
        @(posedge wr_clk);
        wr_en <= 1'b1;
        wr_data <= write_count;
        write_count++;
        @(posedge wr_clk);
        wr_en <= 1'b0;
        
        // Wait for data
        repeat(5) @(posedge rd_clk);
      end
      
      $display("  Completed %0d cycles at near-empty", cycles);
      $display("  PASS: Sustained near-empty operation");
    end

    //--------------------------------------------------------------------------
    // Test 4: has_data vs empty consistency
    //--------------------------------------------------------------------------
    `TEST_CASE("Has-Data-Empty-Consistency") begin
      $display("Testing: has_data vs empty consistency");
      
      rst <= 1'b1;
      wr_en <= 1'b0;
      rd_en <= 1'b0;
      
      repeat(20) @(posedge wr_clk);
      rst <= 1'b0;
      wait_reset_complete();
      
      // Check consistency during transitions
      for (int round = 0; round < 5; round++) begin
        // Empty state
        repeat(3) @(posedge rd_clk);
        `CHECK_EQUAL(has_data, ~empty);
        
        // Write some entries
        for (int i = 0; i < 4; i++) begin
          @(posedge wr_clk);
          wr_en <= 1'b1;
          wr_data <= round * 10 + i;
          @(posedge wr_clk);
          wr_en <= 1'b0;
        end
        
        // Check during not-empty
        repeat(10) @(posedge rd_clk);
        `CHECK_EQUAL(has_data, ~empty);
        `CHECK_EQUAL(has_data, 1'b1);
        
        // Read all entries
        while (!empty) begin
          `CHECK_EQUAL(has_data, ~empty);
          @(posedge rd_clk);
          rd_en <= 1'b1;
          @(posedge rd_clk);
          rd_en <= 1'b0;
          @(posedge rd_clk);
        end
        
        // Back to empty
        `CHECK_EQUAL(has_data, ~empty);
        `CHECK_EQUAL(has_data, 1'b0);
      end
      
      $display("  PASS: has_data always inverse of empty");
    end

    //--------------------------------------------------------------------------
    // Test 5: Empty flag timing at boundary
    //--------------------------------------------------------------------------
    `TEST_CASE("Empty-Boundary-Timing") begin
      integer empty_deassert_cycles;
      integer empty_assert_cycles;
      
      $display("Testing: Empty flag timing at boundary");
      
      rst <= 1'b1;
      wr_en <= 1'b0;
      rd_en <= 1'b0;
      
      repeat(20) @(posedge wr_clk);
      rst <= 1'b0;
      wait_reset_complete();
      
      // Verify empty initially
      repeat(3) @(posedge rd_clk);
      `CHECK_EQUAL(empty, 1'b1);
      
      // Write one entry and measure empty deassertion
      @(posedge wr_clk);
      wr_en <= 1'b1;
      wr_data <= 8'hAB;
      @(posedge wr_clk);
      wr_en <= 1'b0;
      
      empty_deassert_cycles = 0;
      while (empty && empty_deassert_cycles < 20) begin
        @(posedge rd_clk);
        empty_deassert_cycles++;
      end
      $display("  Empty deasserted after %0d cycles", empty_deassert_cycles);
      `CHECK_TRUE(empty_deassert_cycles >= 2 && empty_deassert_cycles <= 8);
      
      // Read and measure empty assertion
      @(posedge rd_clk);
      rd_en <= 1'b1;
      @(posedge rd_clk);
      rd_en <= 1'b0;
      
      empty_assert_cycles = 0;
      while (!empty && empty_assert_cycles < 20) begin
        @(posedge rd_clk);
        empty_assert_cycles++;
      end
      $display("  Empty asserted after %0d cycles", empty_assert_cycles);
      `CHECK_TRUE(empty_assert_cycles >= 0 && empty_assert_cycles <= 3);
      
      $display("  PASS: Empty boundary timing correct");
    end

    //--------------------------------------------------------------------------
    // Test 6: Data integrity at near-empty
    //--------------------------------------------------------------------------
    `TEST_CASE("Near-Empty-Integrity") begin
      integer count = 50;
      integer expected = 0;
      
      $display("Testing: Data integrity while operating at near-empty");
      
      rst <= 1'b1;
      wr_en <= 1'b0;
      rd_en <= 1'b0;
      
      repeat(20) @(posedge wr_clk);
      rst <= 1'b0;
      wait_reset_complete();
      
      write_count = 0;
      
      // Stream data while near empty
      fork
        // Writer - add entries slowly
        begin
          for (int i = 0; i < count; i++) begin
            @(posedge wr_clk);
            wr_en <= 1'b1;
            wr_data <= write_count;
            write_count++;
            @(posedge wr_clk);
            wr_en <= 1'b0;
            repeat(3) @(posedge wr_clk);  // Slow write
          end
        end
        // Reader - read as fast as possible
        begin
          repeat(10) @(posedge rd_clk);
          for (int i = 0; i < count; i++) begin
            while (empty) @(posedge rd_clk);
            @(posedge rd_clk);
            rd_en <= 1'b1;
            @(posedge rd_clk);
            rd_en <= 1'b0;
            @(posedge rd_clk);
            read_val = rd_data;
            `CHECK_EQUAL(read_val, expected);
            expected++;
          end
        end
      join
      
      $display("  PASS: Data integrity at near-empty verified");
    end

    `TEST_DONE;
  end

  `WATCHDOG(3000us);

endmodule
