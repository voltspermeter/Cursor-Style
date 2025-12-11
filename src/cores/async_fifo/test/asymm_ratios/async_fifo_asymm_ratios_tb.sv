`timescale 1ps/1ps
`include "vunit_defines.svh"

//------------------------------------------------------------------------------
// Asymmetric Ratio Variation Test
//
// Tests different width ratios:
// - 2:1 ratio
// - 4:1 ratio (default)
// - Both concat and split variants
//------------------------------------------------------------------------------

module async_fifo_asymm_ratios_tb;

  // Common parameters
  localparam WR_ADDR_WIDTH = 4;

  // Signals
  logic rst;
  logic wr_clk = 1'b0;
  logic rd_clk = 1'b0;

  // Concat 2:1 (8-bit write, 16-bit read)
  logic concat2_wr_en;
  logic [7:0] concat2_wr_data;
  wire concat2_full;
  logic concat2_rd_en;
  wire [15:0] concat2_rd_data;
  wire concat2_empty, concat2_has_data;

  // Concat 4:1 (8-bit write, 32-bit read)
  logic concat4_wr_en;
  logic [7:0] concat4_wr_data;
  wire concat4_full;
  logic concat4_rd_en;
  wire [31:0] concat4_rd_data;
  wire concat4_empty, concat4_has_data;

  // Split 2:1 (16-bit write, 8-bit read)
  logic split2_wr_en;
  logic [15:0] split2_wr_data;
  wire split2_full;
  logic split2_rd_en;
  wire [7:0] split2_rd_data;
  wire split2_empty, split2_has_data;

  // Split 4:1 (32-bit write, 8-bit read)
  logic split4_wr_en;
  logic [31:0] split4_wr_data;
  wire split4_full;
  logic split4_rd_en;
  wire [7:0] split4_rd_data;
  wire split4_empty, split4_has_data;

  // Test tracking
  integer error_count;

  // Clock generation
  always #10000 wr_clk <= !wr_clk;
  always #10000 rd_clk <= !rd_clk;

  // DUT - Concat 2:1
  async_fifo_asymm_concat_fwft #(
        .WR_WIDTH_BYTES(1)
      , .WR_ADDR_WIDTH(WR_ADDR_WIDTH)
      , .WIDTH_RATIO_LOG2(1)  // 2:1 ratio
      , .RESERVE(0)
  ) DUT_CONCAT_2 (
        .rst(rst)
      , .wr_clk(wr_clk)
      , .wr_en(concat2_wr_en)
      , .wr_data(concat2_wr_data)
      , .full(concat2_full)
      , .rd_clk(rd_clk)
      , .rd_en(concat2_rd_en)
      , .rd_data(concat2_rd_data)
      , .empty(concat2_empty)
      , .has_data(concat2_has_data)
  );

  // DUT - Concat 4:1
  async_fifo_asymm_concat_fwft #(
        .WR_WIDTH_BYTES(1)
      , .WR_ADDR_WIDTH(WR_ADDR_WIDTH)
      , .WIDTH_RATIO_LOG2(2)  // 4:1 ratio
      , .RESERVE(0)
  ) DUT_CONCAT_4 (
        .rst(rst)
      , .wr_clk(wr_clk)
      , .wr_en(concat4_wr_en)
      , .wr_data(concat4_wr_data)
      , .full(concat4_full)
      , .rd_clk(rd_clk)
      , .rd_en(concat4_rd_en)
      , .rd_data(concat4_rd_data)
      , .empty(concat4_empty)
      , .has_data(concat4_has_data)
  );

  // DUT - Split 2:1
  async_fifo_asymm_split_fwft #(
        .WR_WIDTH_BYTES(2)
      , .WR_ADDR_WIDTH(WR_ADDR_WIDTH)
      , .WIDTH_RATIO_LOG2(1)  // 2:1 ratio
      , .RESERVE(0)
  ) DUT_SPLIT_2 (
        .rst(rst)
      , .wr_clk(wr_clk)
      , .wr_en(split2_wr_en)
      , .wr_data(split2_wr_data)
      , .full(split2_full)
      , .rd_clk(rd_clk)
      , .rd_en(split2_rd_en)
      , .rd_data(split2_rd_data)
      , .empty(split2_empty)
      , .has_data(split2_has_data)
  );

  // DUT - Split 4:1
  async_fifo_asymm_split_fwft #(
        .WR_WIDTH_BYTES(4)
      , .WR_ADDR_WIDTH(WR_ADDR_WIDTH)
      , .WIDTH_RATIO_LOG2(2)  // 4:1 ratio
      , .RESERVE(0)
  ) DUT_SPLIT_4 (
        .rst(rst)
      , .wr_clk(wr_clk)
      , .wr_en(split4_wr_en)
      , .wr_data(split4_wr_data)
      , .full(split4_full)
      , .rd_clk(rd_clk)
      , .rd_en(split4_rd_en)
      , .rd_data(split4_rd_data)
      , .empty(split4_empty)
      , .has_data(split4_has_data)
  );

  // VCD generation
  initial begin
    $dumpfile("test_case_1.vcd");
    $dumpvars();
  end

  // Helper task: Wait for reset complete
  task automatic wait_reset_complete();
    while (DUT_CONCAT_2.wr_rst) @(posedge wr_clk);
    repeat(10) @(posedge wr_clk);
  endtask

  `TEST_SUITE begin

    //--------------------------------------------------------------------------
    // Test 1: Concat 2:1 ratio
    //--------------------------------------------------------------------------
    `TEST_CASE("Concat-2to1-Ratio") begin
      logic [15:0] actual;
      integer num_words = 5;
      
      $display("Testing: Concat 2:1 (8-bit write, 16-bit read)");
      
      rst <= 1'b1;
      concat2_wr_en <= 1'b0;
      concat2_rd_en <= 1'b0;
      concat4_wr_en <= 1'b0;
      concat4_rd_en <= 1'b0;
      split2_wr_en <= 1'b0;
      split2_rd_en <= 1'b0;
      split4_wr_en <= 1'b0;
      split4_rd_en <= 1'b0;
      error_count = 0;
      
      repeat(20) @(posedge wr_clk);
      rst <= 1'b0;
      wait_reset_complete();
      
      // Write and verify multiple 16-bit words
      for (int word = 0; word < num_words; word++) begin
        // Write 2 bytes
        @(posedge wr_clk);
        concat2_wr_en <= 1'b1;
        concat2_wr_data <= word * 2;
        @(posedge wr_clk);
        concat2_wr_data <= word * 2 + 1;
        @(posedge wr_clk);
        concat2_wr_en <= 1'b0;
      end
      
      // Read and verify
      repeat(10) @(posedge rd_clk);
      for (int word = 0; word < num_words; word++) begin
        while (concat2_empty) @(posedge rd_clk);
        @(posedge rd_clk);
        concat2_rd_en <= 1'b1;
        @(posedge rd_clk);
        concat2_rd_en <= 1'b0;
        @(posedge rd_clk);
        actual = concat2_rd_data;
        if (actual[7:0] !== word * 2 || actual[15:8] !== word * 2 + 1) begin
          error_count++;
          $display("  ERROR word %0d: got 0x%04X", word, actual);
        end
      end
      
      $display("  Errors: %0d", error_count);
      `CHECK_EQUAL(error_count, 0);
      $display("  PASS: Concat 2:1 ratio");
    end

    //--------------------------------------------------------------------------
    // Test 2: Concat 4:1 ratio
    //--------------------------------------------------------------------------
    `TEST_CASE("Concat-4to1-Ratio") begin
      logic [31:0] actual;
      integer num_words = 5;
      
      $display("Testing: Concat 4:1 (8-bit write, 32-bit read)");
      
      rst <= 1'b1;
      concat4_wr_en <= 1'b0;
      concat4_rd_en <= 1'b0;
      error_count = 0;
      
      repeat(20) @(posedge wr_clk);
      rst <= 1'b0;
      wait_reset_complete();
      
      // Write and verify multiple 32-bit words
      for (int word = 0; word < num_words; word++) begin
        // Write 4 bytes
        for (int byte_idx = 0; byte_idx < 4; byte_idx++) begin
          @(posedge wr_clk);
          concat4_wr_en <= 1'b1;
          concat4_wr_data <= word * 4 + byte_idx;
          @(posedge wr_clk);
          concat4_wr_en <= 1'b0;
        end
      end
      
      // Read and verify
      repeat(10) @(posedge rd_clk);
      for (int word = 0; word < num_words; word++) begin
        while (concat4_empty) @(posedge rd_clk);
        @(posedge rd_clk);
        concat4_rd_en <= 1'b1;
        @(posedge rd_clk);
        concat4_rd_en <= 1'b0;
        @(posedge rd_clk);
        actual = concat4_rd_data;
        for (int byte_idx = 0; byte_idx < 4; byte_idx++) begin
          if (actual[byte_idx*8 +: 8] !== word * 4 + byte_idx) begin
            error_count++;
          end
        end
      end
      
      $display("  Errors: %0d", error_count);
      `CHECK_EQUAL(error_count, 0);
      $display("  PASS: Concat 4:1 ratio");
    end

    //--------------------------------------------------------------------------
    // Test 3: Split 2:1 ratio
    //--------------------------------------------------------------------------
    `TEST_CASE("Split-2to1-Ratio") begin
      logic [7:0] rd_val;
      integer num_words = 5;
      integer rd_byte = 0;
      
      $display("Testing: Split 2:1 (16-bit write, 8-bit read)");
      
      rst <= 1'b1;
      split2_wr_en <= 1'b0;
      split2_rd_en <= 1'b0;
      error_count = 0;
      
      repeat(20) @(posedge wr_clk);
      rst <= 1'b0;
      wait_reset_complete();
      
      // Write multiple 16-bit words
      for (int word = 0; word < num_words; word++) begin
        @(posedge wr_clk);
        split2_wr_en <= 1'b1;
        split2_wr_data <= {8'(word * 2 + 1), 8'(word * 2)};  // {hi, lo}
        @(posedge wr_clk);
        split2_wr_en <= 1'b0;
      end
      
      // Read and verify
      repeat(10) @(posedge rd_clk);
      for (int word = 0; word < num_words; word++) begin
        for (int byte_idx = 0; byte_idx < 2; byte_idx++) begin
          while (split2_empty) @(posedge rd_clk);
          @(posedge rd_clk);
          split2_rd_en <= 1'b1;
          @(posedge rd_clk);
          split2_rd_en <= 1'b0;
          @(posedge rd_clk);
          rd_val = split2_rd_data;
          if (rd_val !== rd_byte) begin
            error_count++;
            $display("  ERROR byte %0d: got 0x%02X, expected 0x%02X", rd_byte, rd_val, rd_byte);
          end
          rd_byte++;
        end
      end
      
      $display("  Bytes read: %0d, Errors: %0d", rd_byte, error_count);
      `CHECK_EQUAL(error_count, 0);
      $display("  PASS: Split 2:1 ratio");
    end

    //--------------------------------------------------------------------------
    // Test 4: Split 4:1 ratio
    //--------------------------------------------------------------------------
    `TEST_CASE("Split-4to1-Ratio") begin
      logic [7:0] rd_val;
      integer num_words = 5;
      integer rd_byte = 0;
      
      $display("Testing: Split 4:1 (32-bit write, 8-bit read)");
      
      rst <= 1'b1;
      split4_wr_en <= 1'b0;
      split4_rd_en <= 1'b0;
      error_count = 0;
      
      repeat(20) @(posedge wr_clk);
      rst <= 1'b0;
      wait_reset_complete();
      
      // Write multiple 32-bit words
      for (int word = 0; word < num_words; word++) begin
        @(posedge wr_clk);
        split4_wr_en <= 1'b1;
        split4_wr_data <= {8'(word * 4 + 3), 8'(word * 4 + 2), 8'(word * 4 + 1), 8'(word * 4)};
        @(posedge wr_clk);
        split4_wr_en <= 1'b0;
      end
      
      // Read and verify
      repeat(10) @(posedge rd_clk);
      for (int word = 0; word < num_words; word++) begin
        for (int byte_idx = 0; byte_idx < 4; byte_idx++) begin
          while (split4_empty) @(posedge rd_clk);
          @(posedge rd_clk);
          split4_rd_en <= 1'b1;
          @(posedge rd_clk);
          split4_rd_en <= 1'b0;
          @(posedge rd_clk);
          rd_val = split4_rd_data;
          if (rd_val !== rd_byte) begin
            error_count++;
            $display("  ERROR byte %0d: got 0x%02X, expected 0x%02X", rd_byte, rd_val, rd_byte);
          end
          rd_byte++;
        end
      end
      
      $display("  Bytes read: %0d, Errors: %0d", rd_byte, error_count);
      `CHECK_EQUAL(error_count, 0);
      $display("  PASS: Split 4:1 ratio");
    end

    //--------------------------------------------------------------------------
    // Test 5: All ratios concurrent
    //--------------------------------------------------------------------------
    `TEST_CASE("All-Ratios-Concurrent") begin
      integer num_ops = 10;
      integer c2_wr = 0, c4_wr = 0, s2_wr = 0, s4_wr = 0;
      integer c2_rd = 0, c4_rd = 0, s2_rd = 0, s4_rd = 0;
      
      $display("Testing: All ratios operating concurrently");
      
      rst <= 1'b1;
      concat2_wr_en <= 1'b0;
      concat2_rd_en <= 1'b0;
      concat4_wr_en <= 1'b0;
      concat4_rd_en <= 1'b0;
      split2_wr_en <= 1'b0;
      split2_rd_en <= 1'b0;
      split4_wr_en <= 1'b0;
      split4_rd_en <= 1'b0;
      error_count = 0;
      
      repeat(20) @(posedge wr_clk);
      rst <= 1'b0;
      wait_reset_complete();
      
      fork
        // Concat 2:1 writer
        begin
          for (int i = 0; i < num_ops * 2; i++) begin
            @(posedge wr_clk);
            concat2_wr_en <= 1'b1;
            concat2_wr_data <= i;
            @(posedge wr_clk);
            concat2_wr_en <= 1'b0;
            c2_wr++;
          end
        end
        // Concat 4:1 writer
        begin
          for (int i = 0; i < num_ops * 4; i++) begin
            @(posedge wr_clk);
            concat4_wr_en <= 1'b1;
            concat4_wr_data <= i;
            @(posedge wr_clk);
            concat4_wr_en <= 1'b0;
            c4_wr++;
          end
        end
        // Split 2:1 writer
        begin
          for (int i = 0; i < num_ops; i++) begin
            @(posedge wr_clk);
            split2_wr_en <= 1'b1;
            split2_wr_data <= {8'(i*2+1), 8'(i*2)};
            @(posedge wr_clk);
            split2_wr_en <= 1'b0;
            s2_wr++;
          end
        end
        // Split 4:1 writer
        begin
          for (int i = 0; i < num_ops; i++) begin
            @(posedge wr_clk);
            split4_wr_en <= 1'b1;
            split4_wr_data <= {8'(i*4+3), 8'(i*4+2), 8'(i*4+1), 8'(i*4)};
            @(posedge wr_clk);
            split4_wr_en <= 1'b0;
            s4_wr++;
          end
        end
        // Readers
        begin
          repeat(15) @(posedge rd_clk);
          while (c2_rd < num_ops) begin
            while (concat2_empty) @(posedge rd_clk);
            @(posedge rd_clk);
            concat2_rd_en <= 1'b1;
            @(posedge rd_clk);
            concat2_rd_en <= 1'b0;
            @(posedge rd_clk);
            c2_rd++;
          end
        end
        begin
          repeat(15) @(posedge rd_clk);
          while (c4_rd < num_ops) begin
            while (concat4_empty) @(posedge rd_clk);
            @(posedge rd_clk);
            concat4_rd_en <= 1'b1;
            @(posedge rd_clk);
            concat4_rd_en <= 1'b0;
            @(posedge rd_clk);
            c4_rd++;
          end
        end
        begin
          repeat(15) @(posedge rd_clk);
          while (s2_rd < num_ops * 2) begin
            while (split2_empty) @(posedge rd_clk);
            @(posedge rd_clk);
            split2_rd_en <= 1'b1;
            @(posedge rd_clk);
            split2_rd_en <= 1'b0;
            @(posedge rd_clk);
            s2_rd++;
          end
        end
        begin
          repeat(15) @(posedge rd_clk);
          while (s4_rd < num_ops * 4) begin
            while (split4_empty) @(posedge rd_clk);
            @(posedge rd_clk);
            split4_rd_en <= 1'b1;
            @(posedge rd_clk);
            split4_rd_en <= 1'b0;
            @(posedge rd_clk);
            s4_rd++;
          end
        end
      join
      
      $display("  Concat2: wr=%0d, rd=%0d", c2_wr, c2_rd);
      $display("  Concat4: wr=%0d, rd=%0d", c4_wr, c4_rd);
      $display("  Split2: wr=%0d, rd=%0d", s2_wr, s2_rd);
      $display("  Split4: wr=%0d, rd=%0d", s4_wr, s4_rd);
      
      `CHECK_EQUAL(c2_rd, num_ops);
      `CHECK_EQUAL(c4_rd, num_ops);
      `CHECK_EQUAL(s2_rd, num_ops * 2);
      `CHECK_EQUAL(s4_rd, num_ops * 4);
      
      $display("  PASS: All ratios concurrent");
    end

    `TEST_DONE;
  end

  `WATCHDOG(5000us);

endmodule
