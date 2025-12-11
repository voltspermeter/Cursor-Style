`timescale 1ps/1ps
`include "vunit_defines.svh"

//------------------------------------------------------------------------------
// Programmable Full Accuracy Test
//
// Verifies prog_full asserts at correct threshold:
// - RESERVE=0: prog_full same as full
// - RESERVE=4: prog_full at DEPTH-4
// - RESERVE=8: prog_full at DEPTH-8
//------------------------------------------------------------------------------

module async_fifo_prog_full_accuracy_tb;

  // Parameters
  localparam DATA_WIDTH = 8;
  localparam ADDR_WIDTH = 4;
  localparam DEPTH = 2**ADDR_WIDTH;

  // Signals
  logic rst;
  logic wr_clk = 1'b0;
  logic rd_clk = 1'b0;

  // DUT signals - RESERVE=0
  logic wr_en_r0;
  logic rd_en_r0;
  logic [DATA_WIDTH-1:0] wr_data_r0;
  wire [DATA_WIDTH-1:0] rd_data_r0;
  wire full_r0, prog_full_r0, empty_r0, has_data_r0;

  // DUT signals - RESERVE=4
  logic wr_en_r4;
  logic rd_en_r4;
  logic [DATA_WIDTH-1:0] wr_data_r4;
  wire [DATA_WIDTH-1:0] rd_data_r4;
  wire full_r4, prog_full_r4, empty_r4, has_data_r4;

  // DUT signals - RESERVE=8
  logic wr_en_r8;
  logic rd_en_r8;
  logic [DATA_WIDTH-1:0] wr_data_r8;
  wire [DATA_WIDTH-1:0] rd_data_r8;
  wire full_r8, prog_full_r8, empty_r8, has_data_r8;

  // Test tracking
  integer write_count;
  logic [DATA_WIDTH-1:0] read_val;

  // Clock generation
  always #10000 wr_clk <= !wr_clk;
  always #10000 rd_clk <= !rd_clk;

  // DUT - RESERVE=0
  async_fifo_flags #(
        .DATA_WIDTH(DATA_WIDTH)
      , .ADDR_WIDTH(ADDR_WIDTH)
      , .RESERVE(0)
  ) DUT_R0 (
        .rst(rst)
      , .wr_clk(wr_clk)
      , .wr_en(wr_en_r0)
      , .wr_data(wr_data_r0)
      , .full(full_r0)
      , .prog_full(prog_full_r0)
      , .rd_clk(rd_clk)
      , .rd_en(rd_en_r0)
      , .rd_data(rd_data_r0)
      , .empty(empty_r0)
      , .has_data(has_data_r0)
  );

  // DUT - RESERVE=4
  async_fifo_flags #(
        .DATA_WIDTH(DATA_WIDTH)
      , .ADDR_WIDTH(ADDR_WIDTH)
      , .RESERVE(4)
  ) DUT_R4 (
        .rst(rst)
      , .wr_clk(wr_clk)
      , .wr_en(wr_en_r4)
      , .wr_data(wr_data_r4)
      , .full(full_r4)
      , .prog_full(prog_full_r4)
      , .rd_clk(rd_clk)
      , .rd_en(rd_en_r4)
      , .rd_data(rd_data_r4)
      , .empty(empty_r4)
      , .has_data(has_data_r4)
  );

  // DUT - RESERVE=8
  async_fifo_flags #(
        .DATA_WIDTH(DATA_WIDTH)
      , .ADDR_WIDTH(ADDR_WIDTH)
      , .RESERVE(8)
  ) DUT_R8 (
        .rst(rst)
      , .wr_clk(wr_clk)
      , .wr_en(wr_en_r8)
      , .wr_data(wr_data_r8)
      , .full(full_r8)
      , .prog_full(prog_full_r8)
      , .rd_clk(rd_clk)
      , .rd_en(rd_en_r8)
      , .rd_data(rd_data_r8)
      , .empty(empty_r8)
      , .has_data(has_data_r8)
  );

  // VCD generation
  initial begin
    $dumpfile("test_case_1.vcd");
    $dumpvars();
  end

  // Helper task: Wait for reset complete
  task automatic wait_reset_complete();
    while (DUT_R0.wr_rst || DUT_R0.rd_rst) @(posedge wr_clk);
    repeat(5) @(posedge wr_clk);
  endtask

  `TEST_SUITE begin

    //--------------------------------------------------------------------------
    // Test 1: RESERVE=0 - prog_full same as full
    //--------------------------------------------------------------------------
    `TEST_CASE("Reserve-0-Same-As-Full") begin
      $display("Testing: RESERVE=0 - prog_full should equal full");
      $display("  FIFO depth: %0d, threshold: %0d", DEPTH, DEPTH);
      
      rst <= 1'b1;
      wr_en_r0 <= 1'b0;
      rd_en_r0 <= 1'b0;
      wr_en_r4 <= 1'b0;
      rd_en_r4 <= 1'b0;
      wr_en_r8 <= 1'b0;
      rd_en_r8 <= 1'b0;
      
      repeat(20) @(posedge wr_clk);
      rst <= 1'b0;
      wait_reset_complete();
      
      // Fill to DEPTH-1, verify neither prog_full nor full
      for (int i = 0; i < DEPTH - 1; i++) begin
        @(posedge wr_clk);
        wr_en_r0 <= 1'b1;
        wr_data_r0 <= i;
        @(posedge wr_clk);
        wr_en_r0 <= 1'b0;
      end
      
      repeat(5) @(posedge wr_clk);
      $display("  After %0d writes: full=%b, prog_full=%b", DEPTH-1, full_r0, prog_full_r0);
      `CHECK_EQUAL(full_r0, 1'b0);
      `CHECK_EQUAL(prog_full_r0, 1'b0);
      
      // Write one more to reach DEPTH
      @(posedge wr_clk);
      wr_en_r0 <= 1'b1;
      wr_data_r0 <= DEPTH - 1;
      @(posedge wr_clk);
      wr_en_r0 <= 1'b0;
      
      repeat(5) @(posedge wr_clk);
      $display("  After %0d writes: full=%b, prog_full=%b", DEPTH, full_r0, prog_full_r0);
      `CHECK_EQUAL(full_r0, 1'b1);
      `CHECK_EQUAL(prog_full_r0, 1'b1);
      
      $display("  PASS: RESERVE=0 - prog_full equals full");
    end

    //--------------------------------------------------------------------------
    // Test 2: RESERVE=4 - prog_full at DEPTH-4
    //--------------------------------------------------------------------------
    `TEST_CASE("Reserve-4-Threshold") begin
      integer threshold = DEPTH - 4;
      
      $display("Testing: RESERVE=4 - prog_full at %0d entries", threshold);
      
      rst <= 1'b1;
      wr_en_r4 <= 1'b0;
      rd_en_r4 <= 1'b0;
      
      repeat(20) @(posedge wr_clk);
      rst <= 1'b0;
      wait_reset_complete();
      
      // Fill to threshold-1
      for (int i = 0; i < threshold - 1; i++) begin
        @(posedge wr_clk);
        wr_en_r4 <= 1'b1;
        wr_data_r4 <= i;
        @(posedge wr_clk);
        wr_en_r4 <= 1'b0;
      end
      
      repeat(5) @(posedge wr_clk);
      $display("  After %0d writes: full=%b, prog_full=%b", threshold-1, full_r4, prog_full_r4);
      `CHECK_EQUAL(full_r4, 1'b0);
      `CHECK_EQUAL(prog_full_r4, 1'b0);
      
      // Write one more to reach threshold
      @(posedge wr_clk);
      wr_en_r4 <= 1'b1;
      wr_data_r4 <= threshold - 1;
      @(posedge wr_clk);
      wr_en_r4 <= 1'b0;
      
      repeat(5) @(posedge wr_clk);
      $display("  After %0d writes: full=%b, prog_full=%b", threshold, full_r4, prog_full_r4);
      `CHECK_EQUAL(full_r4, 1'b0);
      `CHECK_EQUAL(prog_full_r4, 1'b1);
      
      // Continue to full
      for (int i = threshold; i < DEPTH; i++) begin
        @(posedge wr_clk);
        wr_en_r4 <= 1'b1;
        wr_data_r4 <= i;
        @(posedge wr_clk);
        wr_en_r4 <= 1'b0;
      end
      
      repeat(5) @(posedge wr_clk);
      $display("  After %0d writes: full=%b, prog_full=%b", DEPTH, full_r4, prog_full_r4);
      `CHECK_EQUAL(full_r4, 1'b1);
      `CHECK_EQUAL(prog_full_r4, 1'b1);
      
      $display("  PASS: RESERVE=4 threshold correct");
    end

    //--------------------------------------------------------------------------
    // Test 3: RESERVE=8 - prog_full at half full
    //--------------------------------------------------------------------------
    `TEST_CASE("Reserve-8-Half-Full") begin
      integer threshold = DEPTH - 8;
      
      $display("Testing: RESERVE=8 - prog_full at %0d entries (half full)", threshold);
      
      rst <= 1'b1;
      wr_en_r8 <= 1'b0;
      rd_en_r8 <= 1'b0;
      
      repeat(20) @(posedge wr_clk);
      rst <= 1'b0;
      wait_reset_complete();
      
      // Fill to threshold-1
      for (int i = 0; i < threshold - 1; i++) begin
        @(posedge wr_clk);
        wr_en_r8 <= 1'b1;
        wr_data_r8 <= i;
        @(posedge wr_clk);
        wr_en_r8 <= 1'b0;
      end
      
      repeat(5) @(posedge wr_clk);
      $display("  After %0d writes: full=%b, prog_full=%b", threshold-1, full_r8, prog_full_r8);
      `CHECK_EQUAL(full_r8, 1'b0);
      `CHECK_EQUAL(prog_full_r8, 1'b0);
      
      // Write one more to reach threshold
      @(posedge wr_clk);
      wr_en_r8 <= 1'b1;
      wr_data_r8 <= threshold - 1;
      @(posedge wr_clk);
      wr_en_r8 <= 1'b0;
      
      repeat(5) @(posedge wr_clk);
      $display("  After %0d writes: full=%b, prog_full=%b", threshold, full_r8, prog_full_r8);
      `CHECK_EQUAL(full_r8, 1'b0);
      `CHECK_EQUAL(prog_full_r8, 1'b1);
      
      $display("  PASS: RESERVE=8 threshold correct");
    end

    //--------------------------------------------------------------------------
    // Test 4: prog_full deasserts correctly on read
    //--------------------------------------------------------------------------
    `TEST_CASE("Prog-Full-Deassert") begin
      integer threshold = DEPTH - 4;
      
      $display("Testing: prog_full deasserts when below threshold");
      
      rst <= 1'b1;
      wr_en_r4 <= 1'b0;
      rd_en_r4 <= 1'b0;
      
      repeat(20) @(posedge wr_clk);
      rst <= 1'b0;
      wait_reset_complete();
      
      // Fill to full
      for (int i = 0; i < DEPTH; i++) begin
        @(posedge wr_clk);
        wr_en_r4 <= 1'b1;
        wr_data_r4 <= i;
        @(posedge wr_clk);
        wr_en_r4 <= 1'b0;
      end
      
      repeat(5) @(posedge wr_clk);
      `CHECK_EQUAL(full_r4, 1'b1);
      `CHECK_EQUAL(prog_full_r4, 1'b1);
      
      // Read entries until below threshold
      repeat(5) @(posedge rd_clk);
      for (int i = 0; i < 5; i++) begin
        @(posedge rd_clk);
        rd_en_r4 <= 1'b1;
        @(posedge rd_clk);
        rd_en_r4 <= 1'b0;
        @(posedge rd_clk);
      end
      
      // Wait for synchronization
      repeat(10) @(posedge wr_clk);
      $display("  After 5 reads: full=%b, prog_full=%b", full_r4, prog_full_r4);
      `CHECK_EQUAL(full_r4, 1'b0);
      `CHECK_EQUAL(prog_full_r4, 1'b0);
      
      $display("  PASS: prog_full deasserts correctly");
    end

    //--------------------------------------------------------------------------
    // Test 5: Verify prog_full relationship with full
    //--------------------------------------------------------------------------
    `TEST_CASE("Prog-Full-Full-Relationship") begin
      $display("Testing: full=1 always implies prog_full=1");
      
      rst <= 1'b1;
      wr_en_r4 <= 1'b0;
      rd_en_r4 <= 1'b0;
      
      repeat(20) @(posedge wr_clk);
      rst <= 1'b0;
      wait_reset_complete();
      
      // Fill gradually and check relationship
      for (int i = 0; i < DEPTH; i++) begin
        @(posedge wr_clk);
        wr_en_r4 <= 1'b1;
        wr_data_r4 <= i;
        @(posedge wr_clk);
        wr_en_r4 <= 1'b0;
        
        repeat(5) @(posedge wr_clk);
        
        // If full is set, prog_full must also be set
        if (full_r4) begin
          `CHECK_EQUAL(prog_full_r4, 1'b1);
        end
      end
      
      // Final check at full
      `CHECK_EQUAL(full_r4, 1'b1);
      `CHECK_EQUAL(prog_full_r4, 1'b1);
      
      $display("  PASS: full implies prog_full relationship verified");
    end

    `TEST_DONE;
  end

  `WATCHDOG(3000us);

endmodule
