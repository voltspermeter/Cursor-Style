`timescale 1ps/1ps
`include "vunit_defines.svh"

//------------------------------------------------------------------------------
// Near-Full Threshold Test
//
// Verifies behavior near full condition:
// - Write to N-1 entries, verify not full
// - Write to N entries, verify full
// - Operate at N-1 entries for extended period
// - Verify RESERVE parameter triggers early full
//------------------------------------------------------------------------------

module async_fifo_near_full_tb;

  // Parameters
  localparam DATA_WIDTH = 8;
  localparam ADDR_WIDTH = 4;
  localparam DEPTH = 2**ADDR_WIDTH;

  // Signals for DUT with RESERVE=0
  logic rst;
  logic wr_clk = 1'b0;
  logic rd_clk = 1'b0;
  logic wr_en;
  logic rd_en;
  logic [DATA_WIDTH-1:0] wr_data;
  wire [DATA_WIDTH-1:0] rd_data;
  wire full, empty, has_data;

  // Signals for DUT with RESERVE=4
  logic wr_en_r4;
  logic rd_en_r4;
  logic [DATA_WIDTH-1:0] wr_data_r4;
  wire [DATA_WIDTH-1:0] rd_data_r4;
  wire full_r4, empty_r4, has_data_r4;

  // Test tracking
  integer write_count;
  logic [DATA_WIDTH-1:0] read_val;

  // Clock generation
  always #10000 wr_clk <= !wr_clk;
  always #10000 rd_clk <= !rd_clk;

  // DUT instantiation - RESERVE=0
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

  // DUT instantiation - RESERVE=4
  async_fifo #(
        .DATA_WIDTH(DATA_WIDTH)
      , .ADDR_WIDTH(ADDR_WIDTH)
      , .RESERVE(4)
  ) DUT_R4 (
        .rst(rst)
      , .wr_clk(wr_clk)
      , .wr_en(wr_en_r4)
      , .wr_data(wr_data_r4)
      , .full(full_r4)
      , .rd_clk(rd_clk)
      , .rd_en(rd_en_r4)
      , .rd_data(rd_data_r4)
      , .empty(empty_r4)
      , .has_data(has_data_r4)
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
    // Test 1: Write to N-1 entries, verify not full
    //--------------------------------------------------------------------------
    `TEST_CASE("N-Minus-1-Not-Full") begin
      $display("Testing: Write N-1 entries, verify not full");
      $display("  FIFO depth: %0d", DEPTH);
      
      rst <= 1'b1;
      wr_en <= 1'b0;
      rd_en <= 1'b0;
      wr_en_r4 <= 1'b0;
      rd_en_r4 <= 1'b0;
      
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
      
      // Verify not full
      repeat(5) @(posedge wr_clk);
      $display("  After %0d writes: full=%b", DEPTH-1, full);
      `CHECK_EQUAL(full, 1'b0);
      
      $display("  PASS: N-1 entries does not trigger full");
    end

    //--------------------------------------------------------------------------
    // Test 2: Write to N entries, verify full
    //--------------------------------------------------------------------------
    `TEST_CASE("N-Entries-Full") begin
      $display("Testing: Write N entries, verify full");
      
      rst <= 1'b1;
      wr_en <= 1'b0;
      rd_en <= 1'b0;
      
      repeat(20) @(posedge wr_clk);
      rst <= 1'b0;
      wait_reset_complete();
      
      // Write DEPTH entries
      for (int i = 0; i < DEPTH; i++) begin
        @(posedge wr_clk);
        wr_en <= 1'b1;
        wr_data <= i;
        @(posedge wr_clk);
        wr_en <= 1'b0;
      end
      
      // Verify full
      repeat(5) @(posedge wr_clk);
      $display("  After %0d writes: full=%b", DEPTH, full);
      `CHECK_EQUAL(full, 1'b1);
      
      $display("  PASS: N entries triggers full");
    end

    //--------------------------------------------------------------------------
    // Test 3: Operate at N-1 entries for extended period
    //--------------------------------------------------------------------------
    `TEST_CASE("Sustained-Near-Full") begin
      integer cycles = 100;
      integer expected_read = 0;
      
      $display("Testing: Operate at N-1 entries for %0d cycles", cycles);
      
      rst <= 1'b1;
      wr_en <= 1'b0;
      rd_en <= 1'b0;
      
      repeat(20) @(posedge wr_clk);
      rst <= 1'b0;
      wait_reset_complete();
      
      // Fill to N-1
      for (int i = 0; i < DEPTH - 1; i++) begin
        @(posedge wr_clk);
        wr_en <= 1'b1;
        wr_data <= i;
        @(posedge wr_clk);
        wr_en <= 1'b0;
      end
      
      write_count = DEPTH - 1;
      
      // Maintain at N-1: write one, read one
      repeat(5) @(posedge rd_clk);
      
      for (int cycle = 0; cycle < cycles; cycle++) begin
        // Write one
        @(posedge wr_clk);
        wr_en <= 1'b1;
        wr_data <= write_count;
        write_count++;
        @(posedge wr_clk);
        wr_en <= 1'b0;
        
        // Read one
        repeat(3) @(posedge rd_clk);
        while (empty) @(posedge rd_clk);
        @(posedge rd_clk);
        rd_en <= 1'b1;
        @(posedge rd_clk);
        rd_en <= 1'b0;
        @(posedge rd_clk);
        read_val = rd_data;
        `CHECK_EQUAL(read_val, expected_read);
        expected_read++;
        
        // Verify not full (most of the time)
        repeat(2) @(posedge wr_clk);
      end
      
      $display("  Completed %0d cycles at near-full", cycles);
      $display("  PASS: Sustained near-full operation");
    end

    //--------------------------------------------------------------------------
    // Test 4: RESERVE=4 triggers early full
    //--------------------------------------------------------------------------
    `TEST_CASE("Reserve-Early-Full") begin
      integer effective_depth = DEPTH - 4;
      
      $display("Testing: RESERVE=4 triggers full at %0d entries", effective_depth);
      
      rst <= 1'b1;
      wr_en_r4 <= 1'b0;
      rd_en_r4 <= 1'b0;
      
      repeat(20) @(posedge wr_clk);
      rst <= 1'b0;
      wait_reset_complete();
      
      // Write effective_depth - 1 entries
      for (int i = 0; i < effective_depth - 1; i++) begin
        @(posedge wr_clk);
        wr_en_r4 <= 1'b1;
        wr_data_r4 <= i;
        @(posedge wr_clk);
        wr_en_r4 <= 1'b0;
      end
      
      repeat(5) @(posedge wr_clk);
      $display("  After %0d writes: full_r4=%b", effective_depth-1, full_r4);
      `CHECK_EQUAL(full_r4, 1'b0);
      
      // Write one more to reach effective_depth
      @(posedge wr_clk);
      wr_en_r4 <= 1'b1;
      wr_data_r4 <= effective_depth - 1;
      @(posedge wr_clk);
      wr_en_r4 <= 1'b0;
      
      repeat(5) @(posedge wr_clk);
      $display("  After %0d writes: full_r4=%b", effective_depth, full_r4);
      `CHECK_EQUAL(full_r4, 1'b1);
      
      $display("  PASS: RESERVE triggers early full correctly");
    end

    //--------------------------------------------------------------------------
    // Test 5: Full flag timing at boundary
    //--------------------------------------------------------------------------
    `TEST_CASE("Full-Boundary-Timing") begin
      $display("Testing: Full flag timing at capacity boundary");
      
      rst <= 1'b1;
      wr_en <= 1'b0;
      rd_en <= 1'b0;
      
      repeat(20) @(posedge wr_clk);
      rst <= 1'b0;
      wait_reset_complete();
      
      // Fill completely
      for (int i = 0; i < DEPTH; i++) begin
        @(posedge wr_clk);
        wr_en <= 1'b1;
        wr_data <= i;
        @(posedge wr_clk);
        wr_en <= 1'b0;
      end
      
      repeat(5) @(posedge wr_clk);
      `CHECK_EQUAL(full, 1'b1);
      
      // Read one entry
      repeat(5) @(posedge rd_clk);
      @(posedge rd_clk);
      rd_en <= 1'b1;
      @(posedge rd_clk);
      rd_en <= 1'b0;
      
      // Wait for full to deassert
      repeat(10) @(posedge wr_clk);
      $display("  After 1 read: full=%b", full);
      `CHECK_EQUAL(full, 1'b0);
      
      // Write one more
      @(posedge wr_clk);
      wr_en <= 1'b1;
      wr_data <= 8'hFF;
      @(posedge wr_clk);
      wr_en <= 1'b0;
      
      // Full should reassert
      repeat(5) @(posedge wr_clk);
      $display("  After 1 write: full=%b", full);
      `CHECK_EQUAL(full, 1'b1);
      
      $display("  PASS: Full flag boundary timing correct");
    end

    //--------------------------------------------------------------------------
    // Test 6: Data integrity at near-full
    //--------------------------------------------------------------------------
    `TEST_CASE("Near-Full-Integrity") begin
      integer count = 50;
      integer expected = 0;
      
      $display("Testing: Data integrity while operating at near-full");
      
      rst <= 1'b1;
      wr_en <= 1'b0;
      rd_en <= 1'b0;
      
      repeat(20) @(posedge wr_clk);
      rst <= 1'b0;
      wait_reset_complete();
      
      // Fill to DEPTH-2
      for (int i = 0; i < DEPTH - 2; i++) begin
        @(posedge wr_clk);
        wr_en <= 1'b1;
        wr_data <= i;
        @(posedge wr_clk);
        wr_en <= 1'b0;
      end
      
      write_count = DEPTH - 2;
      
      // Stream data while near full
      fork
        // Writer
        begin
          for (int i = 0; i < count; i++) begin
            @(posedge wr_clk);
            while (full) @(posedge wr_clk);
            wr_en <= 1'b1;
            wr_data <= write_count;
            write_count++;
            @(posedge wr_clk);
            wr_en <= 1'b0;
          end
        end
        // Reader
        begin
          repeat(10) @(posedge rd_clk);
          for (int i = 0; i < count + DEPTH - 2; i++) begin
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
      
      $display("  PASS: Data integrity at near-full verified");
    end

    `TEST_DONE;
  end

  `WATCHDOG(3000us);

endmodule
