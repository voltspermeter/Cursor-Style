`timescale 1ps/1ps
`include "vunit_defines.svh"

//------------------------------------------------------------------------------
// Width Variation Test
//
// Verifies operation across different data widths:
// - DATA_WIDTH=1 (single bit)
// - DATA_WIDTH=8 (byte)
// - DATA_WIDTH=32 (word)
// - DATA_WIDTH=64 (double word)
//------------------------------------------------------------------------------

module async_fifo_width_variation_tb;

  // Common parameters
  localparam ADDR_WIDTH = 4;
  localparam DEPTH = 2**ADDR_WIDTH;

  // Signals
  logic rst;
  logic wr_clk = 1'b0;
  logic rd_clk = 1'b0;

  // DUT signals - WIDTH=1
  logic wr_en_w1;
  logic rd_en_w1;
  logic [0:0] wr_data_w1;
  wire [0:0] rd_data_w1;
  wire full_w1, empty_w1, has_data_w1;

  // DUT signals - WIDTH=8
  logic wr_en_w8;
  logic rd_en_w8;
  logic [7:0] wr_data_w8;
  wire [7:0] rd_data_w8;
  wire full_w8, empty_w8, has_data_w8;

  // DUT signals - WIDTH=32
  logic wr_en_w32;
  logic rd_en_w32;
  logic [31:0] wr_data_w32;
  wire [31:0] rd_data_w32;
  wire full_w32, empty_w32, has_data_w32;

  // DUT signals - WIDTH=64
  logic wr_en_w64;
  logic rd_en_w64;
  logic [63:0] wr_data_w64;
  wire [63:0] rd_data_w64;
  wire full_w64, empty_w64, has_data_w64;

  // Clock generation
  always #10000 wr_clk <= !wr_clk;
  always #10000 rd_clk <= !rd_clk;

  // DUT - 1-bit width
  async_fifo #(
        .DATA_WIDTH(1)
      , .ADDR_WIDTH(ADDR_WIDTH)
      , .RESERVE(0)
  ) DUT_W1 (
        .rst(rst)
      , .wr_clk(wr_clk)
      , .wr_en(wr_en_w1)
      , .wr_data(wr_data_w1)
      , .full(full_w1)
      , .rd_clk(rd_clk)
      , .rd_en(rd_en_w1)
      , .rd_data(rd_data_w1)
      , .empty(empty_w1)
      , .has_data(has_data_w1)
  );

  // DUT - 8-bit width
  async_fifo #(
        .DATA_WIDTH(8)
      , .ADDR_WIDTH(ADDR_WIDTH)
      , .RESERVE(0)
  ) DUT_W8 (
        .rst(rst)
      , .wr_clk(wr_clk)
      , .wr_en(wr_en_w8)
      , .wr_data(wr_data_w8)
      , .full(full_w8)
      , .rd_clk(rd_clk)
      , .rd_en(rd_en_w8)
      , .rd_data(rd_data_w8)
      , .empty(empty_w8)
      , .has_data(has_data_w8)
  );

  // DUT - 32-bit width
  async_fifo #(
        .DATA_WIDTH(32)
      , .ADDR_WIDTH(ADDR_WIDTH)
      , .RESERVE(0)
  ) DUT_W32 (
        .rst(rst)
      , .wr_clk(wr_clk)
      , .wr_en(wr_en_w32)
      , .wr_data(wr_data_w32)
      , .full(full_w32)
      , .rd_clk(rd_clk)
      , .rd_en(rd_en_w32)
      , .rd_data(rd_data_w32)
      , .empty(empty_w32)
      , .has_data(has_data_w32)
  );

  // DUT - 64-bit width
  async_fifo #(
        .DATA_WIDTH(64)
      , .ADDR_WIDTH(ADDR_WIDTH)
      , .RESERVE(0)
  ) DUT_W64 (
        .rst(rst)
      , .wr_clk(wr_clk)
      , .wr_en(wr_en_w64)
      , .wr_data(wr_data_w64)
      , .full(full_w64)
      , .rd_clk(rd_clk)
      , .rd_en(rd_en_w64)
      , .rd_data(rd_data_w64)
      , .empty(empty_w64)
      , .has_data(has_data_w64)
  );

  // VCD generation
  initial begin
    $dumpfile("test_case_1.vcd");
    $dumpvars();
  end

  // Helper task: Wait for reset complete
  task automatic wait_reset_complete();
    while (DUT_W1.wr_rst || DUT_W1.rd_rst) @(posedge wr_clk);
    repeat(5) @(posedge wr_clk);
  endtask

  `TEST_SUITE begin

    //--------------------------------------------------------------------------
    // Test 1: Single-bit data width
    //--------------------------------------------------------------------------
    `TEST_CASE("Width-1-Bit") begin
      logic [0:0] read_val;
      integer count = 20;
      integer expected = 0;
      integer write_idx = 0;
      
      $display("Testing: DATA_WIDTH=1 (single bit)");
      
      rst <= 1'b1;
      wr_en_w1 <= 1'b0;
      rd_en_w1 <= 1'b0;
      wr_en_w8 <= 1'b0;
      rd_en_w8 <= 1'b0;
      wr_en_w32 <= 1'b0;
      rd_en_w32 <= 1'b0;
      wr_en_w64 <= 1'b0;
      rd_en_w64 <= 1'b0;
      
      repeat(20) @(posedge wr_clk);
      rst <= 1'b0;
      wait_reset_complete();
      
      fork
        // Writer - alternating 0 and 1
        begin
          for (int i = 0; i < count; i++) begin
            @(posedge wr_clk);
            while (full_w1) @(posedge wr_clk);
            wr_en_w1 <= 1'b1;
            wr_data_w1 <= write_idx[0:0];
            write_idx++;
            @(posedge wr_clk);
            wr_en_w1 <= 1'b0;
          end
        end
        // Reader
        begin
          repeat(5) @(posedge rd_clk);
          for (int i = 0; i < count; i++) begin
            while (empty_w1) @(posedge rd_clk);
            @(posedge rd_clk);
            rd_en_w1 <= 1'b1;
            @(posedge rd_clk);
            rd_en_w1 <= 1'b0;
            @(posedge rd_clk);
            read_val = rd_data_w1;
            `CHECK_EQUAL(read_val, expected[0:0]);
            expected++;
          end
        end
      join
      
      $display("  PASS: 1-bit width verified");
    end

    //--------------------------------------------------------------------------
    // Test 2: Byte width
    //--------------------------------------------------------------------------
    `TEST_CASE("Width-8-Byte") begin
      logic [7:0] read_val;
      integer count = 30;
      integer expected = 0;
      integer write_idx = 0;
      
      $display("Testing: DATA_WIDTH=8 (byte)");
      
      rst <= 1'b1;
      wr_en_w8 <= 1'b0;
      rd_en_w8 <= 1'b0;
      
      repeat(20) @(posedge wr_clk);
      rst <= 1'b0;
      wait_reset_complete();
      
      fork
        begin
          for (int i = 0; i < count; i++) begin
            @(posedge wr_clk);
            while (full_w8) @(posedge wr_clk);
            wr_en_w8 <= 1'b1;
            wr_data_w8 <= write_idx[7:0];
            write_idx++;
            @(posedge wr_clk);
            wr_en_w8 <= 1'b0;
          end
        end
        begin
          repeat(5) @(posedge rd_clk);
          for (int i = 0; i < count; i++) begin
            while (empty_w8) @(posedge rd_clk);
            @(posedge rd_clk);
            rd_en_w8 <= 1'b1;
            @(posedge rd_clk);
            rd_en_w8 <= 1'b0;
            @(posedge rd_clk);
            read_val = rd_data_w8;
            `CHECK_EQUAL(read_val, expected[7:0]);
            expected++;
          end
        end
      join
      
      $display("  PASS: 8-bit width verified");
    end

    //--------------------------------------------------------------------------
    // Test 3: Word width
    //--------------------------------------------------------------------------
    `TEST_CASE("Width-32-Word") begin
      logic [31:0] read_val;
      logic [31:0] expected_val;
      integer count = 30;
      integer write_idx = 0;
      integer read_idx = 0;
      
      $display("Testing: DATA_WIDTH=32 (word)");
      
      rst <= 1'b1;
      wr_en_w32 <= 1'b0;
      rd_en_w32 <= 1'b0;
      
      repeat(20) @(posedge wr_clk);
      rst <= 1'b0;
      wait_reset_complete();
      
      fork
        begin
          for (int i = 0; i < count; i++) begin
            @(posedge wr_clk);
            while (full_w32) @(posedge wr_clk);
            wr_en_w32 <= 1'b1;
            wr_data_w32 <= {16'hDEAD, write_idx[15:0]};
            write_idx++;
            @(posedge wr_clk);
            wr_en_w32 <= 1'b0;
          end
        end
        begin
          repeat(5) @(posedge rd_clk);
          for (int i = 0; i < count; i++) begin
            while (empty_w32) @(posedge rd_clk);
            @(posedge rd_clk);
            rd_en_w32 <= 1'b1;
            @(posedge rd_clk);
            rd_en_w32 <= 1'b0;
            @(posedge rd_clk);
            read_val = rd_data_w32;
            expected_val = {16'hDEAD, read_idx[15:0]};
            `CHECK_EQUAL(read_val, expected_val);
            read_idx++;
          end
        end
      join
      
      $display("  PASS: 32-bit width verified");
    end

    //--------------------------------------------------------------------------
    // Test 4: Double word width
    //--------------------------------------------------------------------------
    `TEST_CASE("Width-64-Dword") begin
      logic [63:0] read_val;
      logic [63:0] expected_val;
      integer count = 30;
      integer write_idx = 0;
      integer read_idx = 0;
      
      $display("Testing: DATA_WIDTH=64 (double word)");
      
      rst <= 1'b1;
      wr_en_w64 <= 1'b0;
      rd_en_w64 <= 1'b0;
      
      repeat(20) @(posedge wr_clk);
      rst <= 1'b0;
      wait_reset_complete();
      
      fork
        begin
          for (int i = 0; i < count; i++) begin
            @(posedge wr_clk);
            while (full_w64) @(posedge wr_clk);
            wr_en_w64 <= 1'b1;
            wr_data_w64 <= {32'hCAFEBABE, 16'h1234, write_idx[15:0]};
            write_idx++;
            @(posedge wr_clk);
            wr_en_w64 <= 1'b0;
          end
        end
        begin
          repeat(5) @(posedge rd_clk);
          for (int i = 0; i < count; i++) begin
            while (empty_w64) @(posedge rd_clk);
            @(posedge rd_clk);
            rd_en_w64 <= 1'b1;
            @(posedge rd_clk);
            rd_en_w64 <= 1'b0;
            @(posedge rd_clk);
            read_val = rd_data_w64;
            expected_val = {32'hCAFEBABE, 16'h1234, read_idx[15:0]};
            `CHECK_EQUAL(read_val, expected_val);
            read_idx++;
          end
        end
      join
      
      $display("  PASS: 64-bit width verified");
    end

    //--------------------------------------------------------------------------
    // Test 5: All widths concurrent
    //--------------------------------------------------------------------------
    `TEST_CASE("All-Widths-Concurrent") begin
      logic [0:0] read_w1;
      logic [7:0] read_w8;
      logic [31:0] read_w32;
      logic [63:0] read_w64;
      integer count = 20;
      integer exp_w1 = 0, exp_w8 = 0, exp_w32 = 0, exp_w64 = 0;
      integer wr_w1 = 0, wr_w8 = 0, wr_w32 = 0, wr_w64 = 0;
      
      $display("Testing: All widths operating concurrently");
      
      rst <= 1'b1;
      wr_en_w1 <= 1'b0;
      rd_en_w1 <= 1'b0;
      wr_en_w8 <= 1'b0;
      rd_en_w8 <= 1'b0;
      wr_en_w32 <= 1'b0;
      rd_en_w32 <= 1'b0;
      wr_en_w64 <= 1'b0;
      rd_en_w64 <= 1'b0;
      
      repeat(20) @(posedge wr_clk);
      rst <= 1'b0;
      wait_reset_complete();
      
      fork
        // W1 Writer
        begin
          for (int i = 0; i < count; i++) begin
            @(posedge wr_clk);
            while (full_w1) @(posedge wr_clk);
            wr_en_w1 <= 1'b1;
            wr_data_w1 <= wr_w1[0:0];
            wr_w1++;
            @(posedge wr_clk);
            wr_en_w1 <= 1'b0;
          end
        end
        // W1 Reader
        begin
          repeat(5) @(posedge rd_clk);
          for (int i = 0; i < count; i++) begin
            while (empty_w1) @(posedge rd_clk);
            @(posedge rd_clk);
            rd_en_w1 <= 1'b1;
            @(posedge rd_clk);
            rd_en_w1 <= 1'b0;
            @(posedge rd_clk);
            read_w1 = rd_data_w1;
            `CHECK_EQUAL(read_w1, exp_w1[0:0]);
            exp_w1++;
          end
        end
        // W8 Writer
        begin
          for (int i = 0; i < count; i++) begin
            @(posedge wr_clk);
            while (full_w8) @(posedge wr_clk);
            wr_en_w8 <= 1'b1;
            wr_data_w8 <= wr_w8[7:0];
            wr_w8++;
            @(posedge wr_clk);
            wr_en_w8 <= 1'b0;
          end
        end
        // W8 Reader
        begin
          repeat(5) @(posedge rd_clk);
          for (int i = 0; i < count; i++) begin
            while (empty_w8) @(posedge rd_clk);
            @(posedge rd_clk);
            rd_en_w8 <= 1'b1;
            @(posedge rd_clk);
            rd_en_w8 <= 1'b0;
            @(posedge rd_clk);
            read_w8 = rd_data_w8;
            `CHECK_EQUAL(read_w8, exp_w8[7:0]);
            exp_w8++;
          end
        end
        // W32 Writer
        begin
          for (int i = 0; i < count; i++) begin
            @(posedge wr_clk);
            while (full_w32) @(posedge wr_clk);
            wr_en_w32 <= 1'b1;
            wr_data_w32 <= wr_w32;
            wr_w32++;
            @(posedge wr_clk);
            wr_en_w32 <= 1'b0;
          end
        end
        // W32 Reader
        begin
          repeat(5) @(posedge rd_clk);
          for (int i = 0; i < count; i++) begin
            while (empty_w32) @(posedge rd_clk);
            @(posedge rd_clk);
            rd_en_w32 <= 1'b1;
            @(posedge rd_clk);
            rd_en_w32 <= 1'b0;
            @(posedge rd_clk);
            read_w32 = rd_data_w32;
            `CHECK_EQUAL(read_w32, exp_w32);
            exp_w32++;
          end
        end
        // W64 Writer
        begin
          for (int i = 0; i < count; i++) begin
            @(posedge wr_clk);
            while (full_w64) @(posedge wr_clk);
            wr_en_w64 <= 1'b1;
            wr_data_w64 <= wr_w64;
            wr_w64++;
            @(posedge wr_clk);
            wr_en_w64 <= 1'b0;
          end
        end
        // W64 Reader
        begin
          repeat(5) @(posedge rd_clk);
          for (int i = 0; i < count; i++) begin
            while (empty_w64) @(posedge rd_clk);
            @(posedge rd_clk);
            rd_en_w64 <= 1'b1;
            @(posedge rd_clk);
            rd_en_w64 <= 1'b0;
            @(posedge rd_clk);
            read_w64 = rd_data_w64;
            `CHECK_EQUAL(read_w64, exp_w64);
            exp_w64++;
          end
        end
      join
      
      $display("  PASS: All widths concurrent operation");
    end

    //--------------------------------------------------------------------------
    // Test 6: Full utilization of all bits
    //--------------------------------------------------------------------------
    `TEST_CASE("Full-Bit-Utilization") begin
      logic [63:0] read_val64;
      
      $display("Testing: Full bit utilization (all 1s and all 0s)");
      
      rst <= 1'b1;
      wr_en_w64 <= 1'b0;
      rd_en_w64 <= 1'b0;
      
      repeat(20) @(posedge wr_clk);
      rst <= 1'b0;
      wait_reset_complete();
      
      // Write all 1s
      @(posedge wr_clk);
      wr_en_w64 <= 1'b1;
      wr_data_w64 <= 64'hFFFFFFFF_FFFFFFFF;
      @(posedge wr_clk);
      wr_en_w64 <= 1'b0;
      
      // Write all 0s
      @(posedge wr_clk);
      wr_en_w64 <= 1'b1;
      wr_data_w64 <= 64'h00000000_00000000;
      @(posedge wr_clk);
      wr_en_w64 <= 1'b0;
      
      // Write alternating
      @(posedge wr_clk);
      wr_en_w64 <= 1'b1;
      wr_data_w64 <= 64'hAAAAAAAA_AAAAAAAA;
      @(posedge wr_clk);
      wr_en_w64 <= 1'b0;
      
      // Write inverse alternating
      @(posedge wr_clk);
      wr_en_w64 <= 1'b1;
      wr_data_w64 <= 64'h55555555_55555555;
      @(posedge wr_clk);
      wr_en_w64 <= 1'b0;
      
      // Read and verify
      repeat(10) @(posedge rd_clk);
      
      @(posedge rd_clk);
      rd_en_w64 <= 1'b1;
      @(posedge rd_clk);
      rd_en_w64 <= 1'b0;
      @(posedge rd_clk);
      read_val64 = rd_data_w64;
      `CHECK_EQUAL(read_val64, 64'hFFFFFFFF_FFFFFFFF);
      
      @(posedge rd_clk);
      rd_en_w64 <= 1'b1;
      @(posedge rd_clk);
      rd_en_w64 <= 1'b0;
      @(posedge rd_clk);
      read_val64 = rd_data_w64;
      `CHECK_EQUAL(read_val64, 64'h00000000_00000000);
      
      @(posedge rd_clk);
      rd_en_w64 <= 1'b1;
      @(posedge rd_clk);
      rd_en_w64 <= 1'b0;
      @(posedge rd_clk);
      read_val64 = rd_data_w64;
      `CHECK_EQUAL(read_val64, 64'hAAAAAAAA_AAAAAAAA);
      
      @(posedge rd_clk);
      rd_en_w64 <= 1'b1;
      @(posedge rd_clk);
      rd_en_w64 <= 1'b0;
      @(posedge rd_clk);
      read_val64 = rd_data_w64;
      `CHECK_EQUAL(read_val64, 64'h55555555_55555555);
      
      $display("  PASS: Full bit utilization verified");
    end

    `TEST_DONE;
  end

  `WATCHDOG(4000us);

endmodule
