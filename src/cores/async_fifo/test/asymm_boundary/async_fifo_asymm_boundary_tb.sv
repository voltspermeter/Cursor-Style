`timescale 1ps/1ps
`include "vunit_defines.svh"

//------------------------------------------------------------------------------
// Asymmetric Boundary Test
//
// Verifies asymmetric FIFOs at width ratio boundaries:
// - Concat: narrow write, wide read
// - Split: wide write, narrow read
//------------------------------------------------------------------------------

module async_fifo_asymm_boundary_tb;

  // Parameters - Concat (4:1 ratio, 8-bit write, 32-bit read)
  localparam CONCAT_WR_WIDTH_BYTES = 1;    // 8-bit write
  localparam CONCAT_WR_ADDR_WIDTH = 4;
  localparam CONCAT_WIDTH_RATIO_LOG2 = 2;  // 4:1 ratio
  localparam CONCAT_WR_WIDTH = 8 * CONCAT_WR_WIDTH_BYTES;
  localparam CONCAT_RD_WIDTH = CONCAT_WR_WIDTH * (2**CONCAT_WIDTH_RATIO_LOG2);
  localparam CONCAT_RATIO = 2**CONCAT_WIDTH_RATIO_LOG2;

  // Parameters - Split (4:1 ratio, 32-bit write, 8-bit read)
  localparam SPLIT_WR_WIDTH_BYTES = 4;     // 32-bit write
  localparam SPLIT_WR_ADDR_WIDTH = 4;
  localparam SPLIT_WIDTH_RATIO_LOG2 = 2;   // 4:1 ratio
  localparam SPLIT_WR_WIDTH = 8 * SPLIT_WR_WIDTH_BYTES;
  localparam SPLIT_RD_WIDTH = SPLIT_WR_WIDTH / (2**SPLIT_WIDTH_RATIO_LOG2);
  localparam SPLIT_RATIO = 2**SPLIT_WIDTH_RATIO_LOG2;

  // Signals
  logic rst;
  logic wr_clk = 1'b0;
  logic rd_clk = 1'b0;

  // Concat signals
  logic concat_wr_en;
  logic [CONCAT_WR_WIDTH-1:0] concat_wr_data;
  wire concat_full;
  logic concat_rd_en;
  wire [CONCAT_RD_WIDTH-1:0] concat_rd_data;
  wire concat_empty, concat_has_data;

  // Split signals
  logic split_wr_en;
  logic [SPLIT_WR_WIDTH-1:0] split_wr_data;
  wire split_full;
  logic split_rd_en;
  wire [SPLIT_RD_WIDTH-1:0] split_rd_data;
  wire split_empty, split_has_data;

  // Test tracking
  integer error_count;

  // Clock generation
  always #10000 wr_clk <= !wr_clk;
  always #10000 rd_clk <= !rd_clk;

  // DUT - Concat (narrow write, wide read)
  async_fifo_asymm_concat_fwft #(
        .WR_WIDTH_BYTES(CONCAT_WR_WIDTH_BYTES)
      , .WR_ADDR_WIDTH(CONCAT_WR_ADDR_WIDTH)
      , .WIDTH_RATIO_LOG2(CONCAT_WIDTH_RATIO_LOG2)
      , .RESERVE(0)
  ) DUT_CONCAT (
        .rst(rst)
      , .wr_clk(wr_clk)
      , .wr_en(concat_wr_en)
      , .wr_data(concat_wr_data)
      , .full(concat_full)
      , .rd_clk(rd_clk)
      , .rd_en(concat_rd_en)
      , .rd_data(concat_rd_data)
      , .empty(concat_empty)
      , .has_data(concat_has_data)
  );

  // DUT - Split (wide write, narrow read)
  async_fifo_asymm_split_fwft #(
        .WR_WIDTH_BYTES(SPLIT_WR_WIDTH_BYTES)
      , .WR_ADDR_WIDTH(SPLIT_WR_ADDR_WIDTH)
      , .WIDTH_RATIO_LOG2(SPLIT_WIDTH_RATIO_LOG2)
      , .RESERVE(0)
  ) DUT_SPLIT (
        .rst(rst)
      , .wr_clk(wr_clk)
      , .wr_en(split_wr_en)
      , .wr_data(split_wr_data)
      , .full(split_full)
      , .rd_clk(rd_clk)
      , .rd_en(split_rd_en)
      , .rd_data(split_rd_data)
      , .empty(split_empty)
      , .has_data(split_has_data)
  );

  // VCD generation
  initial begin
    $dumpfile("test_case_1.vcd");
    $dumpvars();
  end

  // Helper task: Wait for reset complete
  task automatic wait_reset_complete();
    while (DUT_CONCAT.wr_rst) @(posedge wr_clk);
    repeat(10) @(posedge wr_clk);
  endtask

  `TEST_SUITE begin

    //--------------------------------------------------------------------------
    // Test 1: Concat - Write exactly WIDTH_RATIO entries, verify one read
    //--------------------------------------------------------------------------
    `TEST_CASE("Concat-Width-Ratio-Boundary") begin
      logic [CONCAT_RD_WIDTH-1:0] expected;
      logic [CONCAT_RD_WIDTH-1:0] actual;
      
      $display("Testing: Concat - Write %0d bytes, verify one %0d-bit read", 
               CONCAT_RATIO, CONCAT_RD_WIDTH);
      
      rst <= 1'b1;
      concat_wr_en <= 1'b0;
      concat_rd_en <= 1'b0;
      split_wr_en <= 1'b0;
      split_rd_en <= 1'b0;
      error_count = 0;
      
      repeat(20) @(posedge wr_clk);
      rst <= 1'b0;
      wait_reset_complete();
      
      // Verify empty initially
      repeat(5) @(posedge rd_clk);
      `CHECK_EQUAL(concat_empty, 1'b1);
      `CHECK_EQUAL(concat_has_data, 1'b0);
      
      // Write RATIO-1 entries - should still be empty
      for (int i = 0; i < CONCAT_RATIO - 1; i++) begin
        @(posedge wr_clk);
        concat_wr_en <= 1'b1;
        concat_wr_data <= 8'hA0 + i;  // 0xA0, 0xA1, 0xA2
        @(posedge wr_clk);
        concat_wr_en <= 1'b0;
      end
      
      repeat(10) @(posedge rd_clk);
      $display("  After %0d writes: empty=%b, has_data=%b", CONCAT_RATIO-1, concat_empty, concat_has_data);
      `CHECK_EQUAL(concat_empty, 1'b1);
      `CHECK_EQUAL(concat_has_data, 1'b0);
      
      // Write one more to complete the word
      @(posedge wr_clk);
      concat_wr_en <= 1'b1;
      concat_wr_data <= 8'hA3;  // Complete the 4-byte word
      @(posedge wr_clk);
      concat_wr_en <= 1'b0;
      
      // Wait for data to appear
      repeat(10) @(posedge rd_clk);
      $display("  After %0d writes: empty=%b, has_data=%b", CONCAT_RATIO, concat_empty, concat_has_data);
      `CHECK_EQUAL(concat_empty, 1'b0);
      `CHECK_EQUAL(concat_has_data, 1'b1);
      
      // Read and verify byte ordering
      @(posedge rd_clk);
      concat_rd_en <= 1'b1;
      @(posedge rd_clk);
      concat_rd_en <= 1'b0;
      @(posedge rd_clk);
      actual = concat_rd_data;
      
      // The concat module shifts right, so first byte goes to LSB
      // Expected: {A3, A2, A1, A0}
      expected = {8'hA3, 8'hA2, 8'hA1, 8'hA0};
      $display("  Read data: 0x%08X, expected: 0x%08X", actual, expected);
      `CHECK_EQUAL(actual, expected);
      
      $display("  PASS: Concat width ratio boundary");
    end

    //--------------------------------------------------------------------------
    // Test 2: Split - Write one entry, verify WIDTH_RATIO reads
    //--------------------------------------------------------------------------
    `TEST_CASE("Split-Width-Ratio-Boundary") begin
      logic [SPLIT_RD_WIDTH-1:0] rd_bytes[0:SPLIT_RATIO-1];
      
      $display("Testing: Split - Write one %0d-bit word, verify %0d byte reads", 
               SPLIT_WR_WIDTH, SPLIT_RATIO);
      
      rst <= 1'b1;
      split_wr_en <= 1'b0;
      split_rd_en <= 1'b0;
      error_count = 0;
      
      repeat(20) @(posedge wr_clk);
      rst <= 1'b0;
      wait_reset_complete();
      
      // Verify empty initially
      repeat(5) @(posedge rd_clk);
      `CHECK_EQUAL(split_empty, 1'b1);
      
      // Write one 32-bit word: 0xDEADBEEF
      @(posedge wr_clk);
      split_wr_en <= 1'b1;
      split_wr_data <= 32'hDEADBEEF;
      @(posedge wr_clk);
      split_wr_en <= 1'b0;
      
      // Wait for data to appear
      repeat(10) @(posedge rd_clk);
      $display("  After 1 write: empty=%b, has_data=%b", split_empty, split_has_data);
      `CHECK_EQUAL(split_empty, 1'b0);
      `CHECK_EQUAL(split_has_data, 1'b1);
      
      // Read RATIO bytes and verify ordering
      for (int i = 0; i < SPLIT_RATIO; i++) begin
        @(posedge rd_clk);
        split_rd_en <= 1'b1;
        @(posedge rd_clk);
        split_rd_en <= 1'b0;
        @(posedge rd_clk);
        rd_bytes[i] = split_rd_data;
        $display("  Read[%0d]: 0x%02X", i, rd_bytes[i]);
      end
      
      // Verify byte ordering (LSB first): 0xEF, 0xBE, 0xAD, 0xDE
      `CHECK_EQUAL(rd_bytes[0], 8'hEF);
      `CHECK_EQUAL(rd_bytes[1], 8'hBE);
      `CHECK_EQUAL(rd_bytes[2], 8'hAD);
      `CHECK_EQUAL(rd_bytes[3], 8'hDE);
      
      // Verify empty after all reads
      repeat(5) @(posedge rd_clk);
      `CHECK_EQUAL(split_empty, 1'b1);
      
      $display("  PASS: Split width ratio boundary");
    end

    //--------------------------------------------------------------------------
    // Test 3: Concat - Multiple complete words
    //--------------------------------------------------------------------------
    `TEST_CASE("Concat-Multiple-Words") begin
      logic [CONCAT_RD_WIDTH-1:0] expected;
      logic [CONCAT_RD_WIDTH-1:0] actual;
      integer num_words = 4;
      
      $display("Testing: Concat - %0d complete words", num_words);
      
      rst <= 1'b1;
      concat_wr_en <= 1'b0;
      concat_rd_en <= 1'b0;
      error_count = 0;
      
      repeat(20) @(posedge wr_clk);
      rst <= 1'b0;
      wait_reset_complete();
      
      // Write multiple complete words
      for (int word = 0; word < num_words; word++) begin
        for (int byte_idx = 0; byte_idx < CONCAT_RATIO; byte_idx++) begin
          @(posedge wr_clk);
          concat_wr_en <= 1'b1;
          concat_wr_data <= (word << 4) | byte_idx;
          @(posedge wr_clk);
          concat_wr_en <= 1'b0;
        end
      end
      
      // Read and verify
      repeat(10) @(posedge rd_clk);
      for (int word = 0; word < num_words; word++) begin
        while (concat_empty) @(posedge rd_clk);
        @(posedge rd_clk);
        concat_rd_en <= 1'b1;
        @(posedge rd_clk);
        concat_rd_en <= 1'b0;
        @(posedge rd_clk);
        actual = concat_rd_data;
        // Build expected value byte by byte
        expected[7:0] = (word << 4) | 0;
        expected[15:8] = (word << 4) | 1;
        expected[23:16] = (word << 4) | 2;
        expected[31:24] = (word << 4) | 3;
        if (actual !== expected) begin
          $display("  ERROR word %0d: got 0x%08X, expected 0x%08X", word, actual, expected);
          error_count++;
        end
      end
      
      `CHECK_EQUAL(error_count, 0);
      $display("  PASS: Concat multiple words");
    end

    //--------------------------------------------------------------------------
    // Test 4: Split - Interleaved read/write
    //--------------------------------------------------------------------------
    `TEST_CASE("Split-Interleaved") begin
      logic [SPLIT_RD_WIDTH-1:0] rd_val;
      integer rd_idx = 0;
      
      $display("Testing: Split - Interleaved read/write");
      
      rst <= 1'b1;
      split_wr_en <= 1'b0;
      split_rd_en <= 1'b0;
      error_count = 0;
      
      repeat(20) @(posedge wr_clk);
      rst <= 1'b0;
      wait_reset_complete();
      
      // Write first word
      @(posedge wr_clk);
      split_wr_en <= 1'b1;
      split_wr_data <= 32'h01020304;
      @(posedge wr_clk);
      split_wr_en <= 1'b0;
      
      // Wait for data
      repeat(10) @(posedge rd_clk);
      
      // Read partial (2 bytes)
      for (int i = 0; i < 2; i++) begin
        @(posedge rd_clk);
        split_rd_en <= 1'b1;
        @(posedge rd_clk);
        split_rd_en <= 1'b0;
        @(posedge rd_clk);
        rd_val = split_rd_data;
        $display("  Read[%0d]: 0x%02X", rd_idx, rd_val);
        rd_idx++;
      end
      
      // Write another word while partially read
      @(posedge wr_clk);
      split_wr_en <= 1'b1;
      split_wr_data <= 32'h05060708;
      @(posedge wr_clk);
      split_wr_en <= 1'b0;
      
      // Continue reading
      repeat(5) @(posedge rd_clk);
      while (!split_empty) begin
        @(posedge rd_clk);
        split_rd_en <= 1'b1;
        @(posedge rd_clk);
        split_rd_en <= 1'b0;
        @(posedge rd_clk);
        rd_val = split_rd_data;
        $display("  Read[%0d]: 0x%02X", rd_idx, rd_val);
        rd_idx++;
      end
      
      $display("  Total bytes read: %0d (expected 8)", rd_idx);
      `CHECK_EQUAL(rd_idx, 8);
      
      $display("  PASS: Split interleaved");
    end

    //--------------------------------------------------------------------------
    // Test 5: Concat - Data integrity streaming
    //--------------------------------------------------------------------------
    `TEST_CASE("Concat-Streaming") begin
      logic [CONCAT_RD_WIDTH-1:0] actual;
      integer num_words = 10;
      integer wr_word = 0;
      integer rd_word = 0;
      
      $display("Testing: Concat - Streaming %0d words", num_words);
      
      rst <= 1'b1;
      concat_wr_en <= 1'b0;
      concat_rd_en <= 1'b0;
      error_count = 0;
      
      repeat(20) @(posedge wr_clk);
      rst <= 1'b0;
      wait_reset_complete();
      
      fork
        // Writer
        begin
          while (wr_word < num_words) begin
            for (int byte_idx = 0; byte_idx < CONCAT_RATIO; byte_idx++) begin
              @(posedge wr_clk);
              while (concat_full) @(posedge wr_clk);
              concat_wr_en <= 1'b1;
              concat_wr_data <= wr_word * CONCAT_RATIO + byte_idx;
              @(posedge wr_clk);
              concat_wr_en <= 1'b0;
            end
            wr_word++;
          end
        end
        // Reader
        begin
          repeat(15) @(posedge rd_clk);
          while (rd_word < num_words) begin
            while (concat_empty) @(posedge rd_clk);
            @(posedge rd_clk);
            concat_rd_en <= 1'b1;
            @(posedge rd_clk);
            concat_rd_en <= 1'b0;
            @(posedge rd_clk);
            actual = concat_rd_data;
            // Verify
            for (int byte_idx = 0; byte_idx < CONCAT_RATIO; byte_idx++) begin
              if (actual[byte_idx*8 +: 8] !== (rd_word * CONCAT_RATIO + byte_idx)) begin
                error_count++;
              end
            end
            rd_word++;
          end
        end
      join
      
      $display("  Words transferred: %0d, Errors: %0d", rd_word, error_count);
      `CHECK_EQUAL(error_count, 0);
      $display("  PASS: Concat streaming");
    end

    //--------------------------------------------------------------------------
    // Test 6: Split - Data integrity streaming
    //--------------------------------------------------------------------------
    `TEST_CASE("Split-Streaming") begin
      logic [SPLIT_RD_WIDTH-1:0] rd_val;
      integer num_words = 10;
      integer expected_bytes = num_words * SPLIT_RATIO;
      integer wr_word = 0;
      integer rd_byte = 0;
      
      $display("Testing: Split - Streaming %0d words (%0d bytes)", num_words, expected_bytes);
      
      rst <= 1'b1;
      split_wr_en <= 1'b0;
      split_rd_en <= 1'b0;
      error_count = 0;
      
      repeat(20) @(posedge wr_clk);
      rst <= 1'b0;
      wait_reset_complete();
      
      fork
        // Writer
        begin
          while (wr_word < num_words) begin
            @(posedge wr_clk);
            while (split_full) @(posedge wr_clk);
            split_wr_en <= 1'b1;
            split_wr_data[7:0] <= wr_word[7:0];
            split_wr_data[15:8] <= wr_word[7:0] + 1;
            split_wr_data[23:16] <= wr_word[7:0] + 2;
            split_wr_data[31:24] <= wr_word[7:0] + 3;
            @(posedge wr_clk);
            split_wr_en <= 1'b0;
            wr_word++;
          end
        end
        // Reader
        begin
          repeat(15) @(posedge rd_clk);
          while (rd_byte < expected_bytes) begin
            while (split_empty) @(posedge rd_clk);
            @(posedge rd_clk);
            split_rd_en <= 1'b1;
            @(posedge rd_clk);
            split_rd_en <= 1'b0;
            @(posedge rd_clk);
            rd_val = split_rd_data;
            // Verify: bytes come out as word_idx + byte_offset
            if (rd_val !== ((rd_byte / SPLIT_RATIO) + (rd_byte % SPLIT_RATIO))) begin
              error_count++;
            end
            rd_byte++;
          end
        end
      join
      
      $display("  Bytes transferred: %0d, Errors: %0d", rd_byte, error_count);
      `CHECK_EQUAL(error_count, 0);
      $display("  PASS: Split streaming");
    end

    `TEST_DONE;
  end

  `WATCHDOG(5000us);

endmodule
