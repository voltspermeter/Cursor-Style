`timescale 1ps/1ps
`include "vunit_defines.svh"

//------------------------------------------------------------------------------
// Pointer Wraparound Test
//
// Verifies correct operation when read/write pointers wrap around:
// - Fill and empty FIFO multiple times
// - Data integrity across wraparound boundary
// - Small FIFO (ADDR_WIDTH=2) for fast wraparound
// - Gray code encoding at wraparound
// - Full/empty detection with wrapped pointers
//------------------------------------------------------------------------------

module async_fifo_ptr_wraparound_tb;

  // Parameters - Small FIFO for fast wraparound testing
  localparam DATA_WIDTH = 8;
  localparam ADDR_WIDTH = 2;  // Only 4 entries!
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

  // Tracking
  logic [DATA_WIDTH-1:0] read_val;
  integer total_writes = 0;
  integer total_reads = 0;
  integer write_index = 0;
  integer read_index = 0;

  // Clock generation
  always #10000 wr_clk <= !wr_clk;
  always #10000 rd_clk <= !rd_clk;

  // DUT instantiation - Small FIFO
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
    // Test 1: Basic wraparound - fill and empty multiple times
    //--------------------------------------------------------------------------
    `TEST_CASE("Basic-Wraparound") begin
      logic [DATA_WIDTH-1:0] expected;
      integer iterations = 10;  // 10 * 4 = 40 writes, wraps ~10 times
      
      $display("Testing: Basic pointer wraparound");
      $display("  FIFO depth: %0d entries", DEPTH);
      $display("  Iterations: %0d", iterations);
      
      // Initialize
      rst <= 1'b1;
      wr_en <= 1'b0;
      rd_en <= 1'b0;
      wr_data <= 8'd0;
      total_writes = 0;
      total_reads = 0;
      write_index = 0;
      read_index = 0;
      
      repeat(20) @(posedge wr_clk);
      rst <= 1'b0;
      wait_reset_complete();
      
      // Fill and empty FIFO multiple times
      for (int iter = 0; iter < iterations; iter++) begin
        $display("  Iteration %0d: wr_ptr=%0d, rd_ptr=%0d", 
                 iter, DUT.wr_ptr, DUT.rd_ptr);
        
        // Fill FIFO
        for (int i = 0; i < DEPTH; i++) begin
          @(posedge wr_clk);
          while (full) @(posedge wr_clk);
          wr_en <= 1'b1;
          wr_data <= write_index;
          @(posedge wr_clk);
          wr_en <= 1'b0;
          write_index++;
          total_writes++;
        end
        
        // Wait for sync
        repeat(5) @(posedge rd_clk);
        
        // Empty FIFO
        for (int i = 0; i < DEPTH; i++) begin
          @(posedge rd_clk);
          while (empty) @(posedge rd_clk);
          rd_en <= 1'b1;
          @(posedge rd_clk);
          rd_en <= 1'b0;
          @(posedge rd_clk);
          read_val = rd_data;
          `CHECK_EQUAL(read_val, read_index);
          read_index++;
          total_reads++;
        end
      end
      
      $display("  Total writes: %0d, Total reads: %0d", total_writes, total_reads);
      `CHECK_EQUAL(total_writes, total_reads);
      `CHECK_EQUAL(empty, 1'b1);
      
      $display("  PASS: Basic wraparound correct");
    end

    //--------------------------------------------------------------------------
    // Test 2: Wraparound with partial fill/empty
    //--------------------------------------------------------------------------
    `TEST_CASE("Partial-Fill-Wraparound") begin
      $display("Testing: Wraparound with partial fill/empty");
      
      rst <= 1'b1;
      wr_en <= 1'b0;
      rd_en <= 1'b0;
      write_index = 0;
      read_index = 0;
      
      repeat(20) @(posedge wr_clk);
      rst <= 1'b0;
      wait_reset_complete();
      
      // Pattern: write 2, read 2, repeat (allows indefinite operation with small FIFO)
      for (int iter = 0; iter < 20; iter++) begin
        // Write 2
        for (int i = 0; i < 2; i++) begin
          @(posedge wr_clk);
          while (full) @(posedge wr_clk);
          wr_en <= 1'b1;
          wr_data <= write_index;
          @(posedge wr_clk);
          wr_en <= 1'b0;
          write_index++;
        end
        
        repeat(5) @(posedge rd_clk);
        
        // Read 2
        for (int i = 0; i < 2; i++) begin
          @(posedge rd_clk);
          while (empty) @(posedge rd_clk);
          rd_en <= 1'b1;
          @(posedge rd_clk);
          rd_en <= 1'b0;
          @(posedge rd_clk);
          read_val = rd_data;
          `CHECK_EQUAL(read_val, read_index);
          read_index++;
        end
      end
      
      `CHECK_EQUAL(read_index, write_index);
      $display("  Total values transferred: %0d", write_index);
      
      $display("  PASS: Partial fill wraparound correct");
    end

    //--------------------------------------------------------------------------
    // Test 3: Verify Gray code at wraparound boundary
    //--------------------------------------------------------------------------
    `TEST_CASE("Gray-Code-Wraparound") begin
      logic [ADDR_WIDTH:0] prev_wr_gray, curr_wr_gray;
      integer bit_changes;
      
      $display("Testing: Gray code encoding at wraparound");
      
      rst <= 1'b1;
      wr_en <= 1'b0;
      rd_en <= 1'b0;
      
      repeat(20) @(posedge wr_clk);
      rst <= 1'b0;
      wait_reset_complete();
      
      prev_wr_gray = DUT.wr_ptr_gray;
      
      // Write entries and verify Gray code changes only 1 bit at a time
      for (int i = 0; i < DEPTH * 4; i++) begin  // Multiple wraps
        @(posedge wr_clk);
        wr_en <= 1'b1;
        wr_data <= i;
        @(posedge wr_clk);
        wr_en <= 1'b0;
        
        curr_wr_gray = DUT.wr_ptr_gray;
        
        // Count bit differences
        bit_changes = 0;
        for (int b = 0; b <= ADDR_WIDTH; b++) begin
          if (prev_wr_gray[b] != curr_wr_gray[b]) bit_changes++;
        end
        
        // Gray code should change at most 1 bit
        `CHECK_TRUE(bit_changes <= 1);
        
        if (bit_changes > 1) begin
          $display("  ERROR: Gray code changed %0d bits at wr_ptr=%0d", 
                   bit_changes, DUT.wr_ptr);
        end
        
        prev_wr_gray = curr_wr_gray;
        
        // Read to prevent full
        repeat(2) @(posedge rd_clk);
        if (!empty) begin
          rd_en <= 1'b1;
          @(posedge rd_clk);
          rd_en <= 1'b0;
        end
      end
      
      $display("  PASS: Gray code encoding correct at wraparound");
    end

    //--------------------------------------------------------------------------
    // Test 4: Full/empty detection with wrapped pointers
    //--------------------------------------------------------------------------
    `TEST_CASE("Full-Empty-Wrapped") begin
      $display("Testing: Full/empty with wrapped pointers");
      
      rst <= 1'b1;
      wr_en <= 1'b0;
      rd_en <= 1'b0;
      
      repeat(20) @(posedge wr_clk);
      rst <= 1'b0;
      wait_reset_complete();
      
      // Advance pointers to near wraparound
      for (int cycle = 0; cycle < 3; cycle++) begin
        // Fill to full
        $display("  Cycle %0d: Filling FIFO", cycle);
        while (!full) begin
          @(posedge wr_clk);
          wr_en <= 1'b1;
          wr_data <= cycle * 100;
          @(posedge wr_clk);
          wr_en <= 1'b0;
        end
        
        // Verify full
        repeat(3) @(posedge wr_clk);
        `CHECK_EQUAL(full, 1'b1);
        
        // Empty completely
        $display("  Cycle %0d: Emptying FIFO", cycle);
        repeat(5) @(posedge rd_clk);
        while (!empty) begin
          @(posedge rd_clk);
          rd_en <= 1'b1;
          @(posedge rd_clk);
          rd_en <= 1'b0;
          @(posedge rd_clk);
        end
        
        // Verify empty
        repeat(3) @(posedge rd_clk);
        `CHECK_EQUAL(empty, 1'b1);
        `CHECK_EQUAL(has_data, 1'b0);
        
        $display("  Cycle %0d: wr_ptr=%0d, rd_ptr=%0d", 
                 cycle, DUT.wr_ptr, DUT.rd_ptr);
      end
      
      $display("  PASS: Full/empty detection correct with wrapped pointers");
    end

    //--------------------------------------------------------------------------
    // Test 5: Continuous streaming across many wraps
    //--------------------------------------------------------------------------
    `TEST_CASE("Continuous-Streaming") begin
      integer stream_count = 100;  // 100 entries = 25 pointer wraps
      
      $display("Testing: Continuous streaming across %0d entries", stream_count);
      
      rst <= 1'b1;
      wr_en <= 1'b0;
      rd_en <= 1'b0;
      write_index = 0;
      read_index = 0;
      
      repeat(20) @(posedge wr_clk);
      rst <= 1'b0;
      wait_reset_complete();
      
      // Start reader process
      fork
        // Writer
        begin
          for (int i = 0; i < stream_count; i++) begin
            @(posedge wr_clk);
            while (full) @(posedge wr_clk);
            wr_en <= 1'b1;
            wr_data <= i;
            @(posedge wr_clk);
            wr_en <= 1'b0;
          end
        end
        // Reader
        begin
          repeat(10) @(posedge rd_clk);  // Initial delay
          for (int i = 0; i < stream_count; i++) begin
            @(posedge rd_clk);
            while (empty) @(posedge rd_clk);
            rd_en <= 1'b1;
            @(posedge rd_clk);
            rd_en <= 1'b0;
            @(posedge rd_clk);
            read_val = rd_data;
            `CHECK_EQUAL(read_val, i);
          end
        end
      join
      
      $display("  Total pointer wraps: ~%0d", stream_count / DEPTH);
      $display("  PASS: Continuous streaming correct");
    end

    `TEST_DONE;
  end

  `WATCHDOG(2000us);

endmodule
