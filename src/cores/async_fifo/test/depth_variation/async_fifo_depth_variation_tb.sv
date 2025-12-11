`timescale 1ps/1ps
`include "vunit_defines.svh"

//------------------------------------------------------------------------------
// Depth Variation Test
//
// Verifies operation across different FIFO depths:
// - ADDR_WIDTH=2 (4 entries) - minimum practical
// - ADDR_WIDTH=4 (16 entries) - small
// - ADDR_WIDTH=6 (64 entries) - medium (RAM_STYLE boundary)
//------------------------------------------------------------------------------

module async_fifo_depth_variation_tb;

  // Common parameters
  localparam DATA_WIDTH = 8;

  // Signals
  logic rst;
  logic wr_clk = 1'b0;
  logic rd_clk = 1'b0;

  // DUT signals - ADDR_WIDTH=2 (4 entries)
  logic wr_en_d4;
  logic rd_en_d4;
  logic [DATA_WIDTH-1:0] wr_data_d4;
  wire [DATA_WIDTH-1:0] rd_data_d4;
  wire full_d4, empty_d4, has_data_d4;

  // DUT signals - ADDR_WIDTH=4 (16 entries)
  logic wr_en_d16;
  logic rd_en_d16;
  logic [DATA_WIDTH-1:0] wr_data_d16;
  wire [DATA_WIDTH-1:0] rd_data_d16;
  wire full_d16, empty_d16, has_data_d16;

  // DUT signals - ADDR_WIDTH=6 (64 entries)
  logic wr_en_d64;
  logic rd_en_d64;
  logic [DATA_WIDTH-1:0] wr_data_d64;
  wire [DATA_WIDTH-1:0] rd_data_d64;
  wire full_d64, empty_d64, has_data_d64;

  // Test tracking
  logic [DATA_WIDTH-1:0] read_val;

  // Clock generation
  always #10000 wr_clk <= !wr_clk;
  always #10000 rd_clk <= !rd_clk;

  // DUT - 4 entries
  async_fifo #(
        .DATA_WIDTH(DATA_WIDTH)
      , .ADDR_WIDTH(2)
      , .RESERVE(0)
  ) DUT_D4 (
        .rst(rst)
      , .wr_clk(wr_clk)
      , .wr_en(wr_en_d4)
      , .wr_data(wr_data_d4)
      , .full(full_d4)
      , .rd_clk(rd_clk)
      , .rd_en(rd_en_d4)
      , .rd_data(rd_data_d4)
      , .empty(empty_d4)
      , .has_data(has_data_d4)
  );

  // DUT - 16 entries
  async_fifo #(
        .DATA_WIDTH(DATA_WIDTH)
      , .ADDR_WIDTH(4)
      , .RESERVE(0)
  ) DUT_D16 (
        .rst(rst)
      , .wr_clk(wr_clk)
      , .wr_en(wr_en_d16)
      , .wr_data(wr_data_d16)
      , .full(full_d16)
      , .rd_clk(rd_clk)
      , .rd_en(rd_en_d16)
      , .rd_data(rd_data_d16)
      , .empty(empty_d16)
      , .has_data(has_data_d16)
  );

  // DUT - 64 entries
  async_fifo #(
        .DATA_WIDTH(DATA_WIDTH)
      , .ADDR_WIDTH(6)
      , .RESERVE(0)
  ) DUT_D64 (
        .rst(rst)
      , .wr_clk(wr_clk)
      , .wr_en(wr_en_d64)
      , .wr_data(wr_data_d64)
      , .full(full_d64)
      , .rd_clk(rd_clk)
      , .rd_en(rd_en_d64)
      , .rd_data(rd_data_d64)
      , .empty(empty_d64)
      , .has_data(has_data_d64)
  );

  // VCD generation
  initial begin
    $dumpfile("test_case_1.vcd");
    $dumpvars();
  end

  // Helper task: Wait for reset complete
  task automatic wait_reset_complete();
    while (DUT_D4.wr_rst || DUT_D4.rd_rst) @(posedge wr_clk);
    repeat(5) @(posedge wr_clk);
  endtask

  `TEST_SUITE begin

    //--------------------------------------------------------------------------
    // Test 1: Depth=4 fill and empty
    //--------------------------------------------------------------------------
    `TEST_CASE("Depth-4-Fill-Empty") begin
      integer depth = 4;
      integer expected = 0;
      
      $display("Testing: ADDR_WIDTH=2, Depth=%0d entries", depth);
      
      rst <= 1'b1;
      wr_en_d4 <= 1'b0;
      rd_en_d4 <= 1'b0;
      wr_en_d16 <= 1'b0;
      rd_en_d16 <= 1'b0;
      wr_en_d64 <= 1'b0;
      rd_en_d64 <= 1'b0;
      
      repeat(20) @(posedge wr_clk);
      rst <= 1'b0;
      wait_reset_complete();
      
      // Fill completely
      for (int i = 0; i < depth; i++) begin
        @(posedge wr_clk);
        wr_en_d4 <= 1'b1;
        wr_data_d4 <= i;
        @(posedge wr_clk);
        wr_en_d4 <= 1'b0;
      end
      
      // Verify full
      repeat(5) @(posedge wr_clk);
      `CHECK_EQUAL(full_d4, 1'b1);
      $display("  Filled %0d entries, full=%b", depth, full_d4);
      
      // Empty completely
      repeat(5) @(posedge rd_clk);
      for (int i = 0; i < depth; i++) begin
        while (empty_d4) @(posedge rd_clk);
        @(posedge rd_clk);
        rd_en_d4 <= 1'b1;
        @(posedge rd_clk);
        rd_en_d4 <= 1'b0;
        @(posedge rd_clk);
        read_val = rd_data_d4;
        `CHECK_EQUAL(read_val, expected);
        expected++;
      end
      
      // Verify empty
      repeat(5) @(posedge rd_clk);
      `CHECK_EQUAL(empty_d4, 1'b1);
      
      $display("  PASS: Depth=4 fill and empty");
    end

    //--------------------------------------------------------------------------
    // Test 2: Depth=16 fill and empty
    //--------------------------------------------------------------------------
    `TEST_CASE("Depth-16-Fill-Empty") begin
      integer depth = 16;
      integer expected = 0;
      
      $display("Testing: ADDR_WIDTH=4, Depth=%0d entries", depth);
      
      rst <= 1'b1;
      wr_en_d16 <= 1'b0;
      rd_en_d16 <= 1'b0;
      
      repeat(20) @(posedge wr_clk);
      rst <= 1'b0;
      wait_reset_complete();
      
      // Fill completely
      for (int i = 0; i < depth; i++) begin
        @(posedge wr_clk);
        wr_en_d16 <= 1'b1;
        wr_data_d16 <= i;
        @(posedge wr_clk);
        wr_en_d16 <= 1'b0;
      end
      
      // Verify full
      repeat(5) @(posedge wr_clk);
      `CHECK_EQUAL(full_d16, 1'b1);
      $display("  Filled %0d entries, full=%b", depth, full_d16);
      
      // Empty completely
      repeat(5) @(posedge rd_clk);
      for (int i = 0; i < depth; i++) begin
        while (empty_d16) @(posedge rd_clk);
        @(posedge rd_clk);
        rd_en_d16 <= 1'b1;
        @(posedge rd_clk);
        rd_en_d16 <= 1'b0;
        @(posedge rd_clk);
        read_val = rd_data_d16;
        `CHECK_EQUAL(read_val, expected);
        expected++;
      end
      
      // Verify empty
      repeat(5) @(posedge rd_clk);
      `CHECK_EQUAL(empty_d16, 1'b1);
      
      $display("  PASS: Depth=16 fill and empty");
    end

    //--------------------------------------------------------------------------
    // Test 3: Depth=64 fill and empty
    //--------------------------------------------------------------------------
    `TEST_CASE("Depth-64-Fill-Empty") begin
      integer depth = 64;
      integer expected = 0;
      
      $display("Testing: ADDR_WIDTH=6, Depth=%0d entries", depth);
      
      rst <= 1'b1;
      wr_en_d64 <= 1'b0;
      rd_en_d64 <= 1'b0;
      
      repeat(20) @(posedge wr_clk);
      rst <= 1'b0;
      wait_reset_complete();
      
      // Fill completely
      for (int i = 0; i < depth; i++) begin
        @(posedge wr_clk);
        wr_en_d64 <= 1'b1;
        wr_data_d64 <= i;
        @(posedge wr_clk);
        wr_en_d64 <= 1'b0;
      end
      
      // Verify full
      repeat(5) @(posedge wr_clk);
      `CHECK_EQUAL(full_d64, 1'b1);
      $display("  Filled %0d entries, full=%b", depth, full_d64);
      
      // Empty completely
      repeat(5) @(posedge rd_clk);
      for (int i = 0; i < depth; i++) begin
        while (empty_d64) @(posedge rd_clk);
        @(posedge rd_clk);
        rd_en_d64 <= 1'b1;
        @(posedge rd_clk);
        rd_en_d64 <= 1'b0;
        @(posedge rd_clk);
        read_val = rd_data_d64;
        `CHECK_EQUAL(read_val, expected);
        expected++;
      end
      
      // Verify empty
      repeat(5) @(posedge rd_clk);
      `CHECK_EQUAL(empty_d64, 1'b1);
      
      $display("  PASS: Depth=64 fill and empty");
    end

    //--------------------------------------------------------------------------
    // Test 4: Depth=4 streaming
    //--------------------------------------------------------------------------
    `TEST_CASE("Depth-4-Streaming") begin
      integer count = 100;
      integer expected = 0;
      integer write_idx = 0;
      
      $display("Testing: Depth=4 streaming %0d entries", count);
      
      rst <= 1'b1;
      wr_en_d4 <= 1'b0;
      rd_en_d4 <= 1'b0;
      
      repeat(20) @(posedge wr_clk);
      rst <= 1'b0;
      wait_reset_complete();
      
      fork
        // Writer
        begin
          for (int i = 0; i < count; i++) begin
            @(posedge wr_clk);
            while (full_d4) @(posedge wr_clk);
            wr_en_d4 <= 1'b1;
            wr_data_d4 <= write_idx;
            write_idx++;
            @(posedge wr_clk);
            wr_en_d4 <= 1'b0;
          end
        end
        // Reader
        begin
          repeat(5) @(posedge rd_clk);
          for (int i = 0; i < count; i++) begin
            while (empty_d4) @(posedge rd_clk);
            @(posedge rd_clk);
            rd_en_d4 <= 1'b1;
            @(posedge rd_clk);
            rd_en_d4 <= 1'b0;
            @(posedge rd_clk);
            read_val = rd_data_d4;
            `CHECK_EQUAL(read_val, expected);
            expected++;
          end
        end
      join
      
      $display("  PASS: Depth=4 streaming");
    end

    //--------------------------------------------------------------------------
    // Test 5: All depths concurrent
    //--------------------------------------------------------------------------
    `TEST_CASE("All-Depths-Concurrent") begin
      integer count = 30;
      integer exp_d4 = 0, exp_d16 = 0, exp_d64 = 0;
      integer wr_d4 = 0, wr_d16 = 0, wr_d64 = 0;
      
      $display("Testing: All depths operating concurrently");
      
      rst <= 1'b1;
      wr_en_d4 <= 1'b0;
      rd_en_d4 <= 1'b0;
      wr_en_d16 <= 1'b0;
      rd_en_d16 <= 1'b0;
      wr_en_d64 <= 1'b0;
      rd_en_d64 <= 1'b0;
      
      repeat(20) @(posedge wr_clk);
      rst <= 1'b0;
      wait_reset_complete();
      
      fork
        // Writer D4
        begin
          for (int i = 0; i < count; i++) begin
            @(posedge wr_clk);
            while (full_d4) @(posedge wr_clk);
            wr_en_d4 <= 1'b1;
            wr_data_d4 <= wr_d4;
            wr_d4++;
            @(posedge wr_clk);
            wr_en_d4 <= 1'b0;
          end
        end
        // Reader D4
        begin
          repeat(5) @(posedge rd_clk);
          for (int i = 0; i < count; i++) begin
            while (empty_d4) @(posedge rd_clk);
            @(posedge rd_clk);
            rd_en_d4 <= 1'b1;
            @(posedge rd_clk);
            rd_en_d4 <= 1'b0;
            @(posedge rd_clk);
            read_val = rd_data_d4;
            `CHECK_EQUAL(read_val, exp_d4);
            exp_d4++;
          end
        end
        // Writer D16
        begin
          for (int i = 0; i < count; i++) begin
            @(posedge wr_clk);
            while (full_d16) @(posedge wr_clk);
            wr_en_d16 <= 1'b1;
            wr_data_d16 <= wr_d16 + 100;
            wr_d16++;
            @(posedge wr_clk);
            wr_en_d16 <= 1'b0;
          end
        end
        // Reader D16
        begin
          repeat(5) @(posedge rd_clk);
          for (int i = 0; i < count; i++) begin
            while (empty_d16) @(posedge rd_clk);
            @(posedge rd_clk);
            rd_en_d16 <= 1'b1;
            @(posedge rd_clk);
            rd_en_d16 <= 1'b0;
            @(posedge rd_clk);
            read_val = rd_data_d16;
            `CHECK_EQUAL(read_val, exp_d16 + 100);
            exp_d16++;
          end
        end
        // Writer D64
        begin
          for (int i = 0; i < count; i++) begin
            @(posedge wr_clk);
            while (full_d64) @(posedge wr_clk);
            wr_en_d64 <= 1'b1;
            wr_data_d64 <= wr_d64 + 200;
            wr_d64++;
            @(posedge wr_clk);
            wr_en_d64 <= 1'b0;
          end
        end
        // Reader D64
        begin
          repeat(5) @(posedge rd_clk);
          for (int i = 0; i < count; i++) begin
            while (empty_d64) @(posedge rd_clk);
            @(posedge rd_clk);
            rd_en_d64 <= 1'b1;
            @(posedge rd_clk);
            rd_en_d64 <= 1'b0;
            @(posedge rd_clk);
            read_val = rd_data_d64;
            `CHECK_EQUAL(read_val, exp_d64 + 200);
            exp_d64++;
          end
        end
      join
      
      $display("  PASS: All depths concurrent operation");
    end

    `TEST_DONE;
  end

  `WATCHDOG(5000us);

endmodule
