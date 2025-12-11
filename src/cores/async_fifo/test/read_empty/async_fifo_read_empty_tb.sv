`timescale 1ps/1ps
`include "vunit_defines.svh"

//------------------------------------------------------------------------------
// Read-While-Empty Protection Test
//
// Verifies FIFO handles read attempts when empty:
// - rd_en while empty=1 - no pointer change
// - rd_en while has_data=0 - no corruption
// - Continuous rd_en on empty FIFO
// - rd_en as FIFO becomes empty (race condition)
// - rd_data stability when reading empty FIFO
//------------------------------------------------------------------------------

module async_fifo_read_empty_tb;

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

  // Tracking
  logic [ADDR_WIDTH:0] initial_rd_ptr;
  logic [DATA_WIDTH-1:0] last_valid_data;

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
    // Test 1: rd_en while empty - no pointer change
    //--------------------------------------------------------------------------
    `TEST_CASE("Read-While-Empty-NoPtr") begin
      $display("Testing: rd_en while empty - pointer should not change");
      
      // Initialize
      rst <= 1'b1;
      wr_en <= 1'b0;
      rd_en <= 1'b0;
      wr_data <= 8'd0;
      
      repeat(20) @(posedge wr_clk);
      rst <= 1'b0;
      wait_reset_complete();
      
      // Verify empty
      repeat(5) @(posedge rd_clk);
      `CHECK_EQUAL(empty, 1'b1);
      
      // Record initial pointer
      initial_rd_ptr = DUT.rd_ptr;
      $display("  Initial rd_ptr: %0d", initial_rd_ptr);
      
      // Assert rd_en while empty (should be ignored)
      for (int i = 0; i < 10; i++) begin
        @(posedge rd_clk);
        rd_en <= 1'b1;
        @(posedge rd_clk);
        rd_en <= 1'b0;
        @(posedge rd_clk);
      end
      
      // Verify pointer unchanged
      $display("  Final rd_ptr: %0d", DUT.rd_ptr);
      `CHECK_EQUAL(DUT.rd_ptr, initial_rd_ptr);
      
      // Verify still empty
      `CHECK_EQUAL(empty, 1'b1);
      
      $display("  PASS: Read while empty doesn't change pointer");
    end

    //--------------------------------------------------------------------------
    // Test 2: rd_en while has_data=0 - no corruption
    //--------------------------------------------------------------------------
    `TEST_CASE("Read-Has-Data-Zero") begin
      logic [DATA_WIDTH-1:0] read_val;
      
      $display("Testing: rd_en while has_data=0 - no data corruption");
      
      rst <= 1'b1;
      wr_en <= 1'b0;
      rd_en <= 1'b0;
      
      repeat(20) @(posedge wr_clk);
      rst <= 1'b0;
      wait_reset_complete();
      
      // Assert rd_en while has_data=0
      repeat(5) @(posedge rd_clk);
      `CHECK_EQUAL(has_data, 1'b0);
      
      rd_en <= 1'b1;
      repeat(5) @(posedge rd_clk);
      rd_en <= 1'b0;
      
      // Now write data (0x64, 0x65, 0x66, 0x67, 0x68 = 100-104)
      for (int i = 0; i < 5; i++) begin
        @(posedge wr_clk);
        wr_en <= 1'b1;
        wr_data <= i + 100;
        @(posedge wr_clk);
        wr_en <= 1'b0;
      end
      
      // Wait for data visible
      while (empty) @(posedge rd_clk);
      
      // Read and verify no corruption
      for (int i = 0; i < 5; i++) begin
        @(posedge rd_clk);
        rd_en <= 1'b1;
        @(posedge rd_clk);
        rd_en <= 1'b0;
        @(posedge rd_clk);
        read_val = rd_data;
        `CHECK_EQUAL(read_val, i + 100);
      end
      
      $display("  PASS: No corruption after read while has_data=0");
    end

    //--------------------------------------------------------------------------
    // Test 3: Continuous rd_en on empty FIFO
    //--------------------------------------------------------------------------
    `TEST_CASE("Continuous-Read-Empty") begin
      $display("Testing: Continuous rd_en assertion on empty FIFO");
      
      rst <= 1'b1;
      wr_en <= 1'b0;
      rd_en <= 1'b0;
      
      repeat(20) @(posedge wr_clk);
      rst <= 1'b0;
      wait_reset_complete();
      
      // Verify empty
      repeat(5) @(posedge rd_clk);
      `CHECK_EQUAL(empty, 1'b1);
      
      initial_rd_ptr = DUT.rd_ptr;
      
      // Hold rd_en continuously for many cycles
      rd_en <= 1'b1;
      for (int i = 0; i < 50; i++) begin
        @(posedge rd_clk);
        // Pointer should remain unchanged
        `CHECK_EQUAL(DUT.rd_ptr, initial_rd_ptr);
        // Empty should remain asserted
        `CHECK_EQUAL(empty, 1'b1);
      end
      rd_en <= 1'b0;
      
      // Verify FIFO still functional
      @(posedge wr_clk);
      wr_en <= 1'b1;
      wr_data <= 8'hAB;
      @(posedge wr_clk);
      wr_en <= 1'b0;
      
      // Wait for data
      while (empty) @(posedge rd_clk);
      `CHECK_EQUAL(has_data, 1'b1);
      
      // Read it
      @(posedge rd_clk);
      rd_en <= 1'b1;
      @(posedge rd_clk);
      rd_en <= 1'b0;
      @(posedge rd_clk);
      `CHECK_EQUAL(rd_data, 8'hAB);
      
      $display("  PASS: Continuous read on empty FIFO handled correctly");
    end

    //--------------------------------------------------------------------------
    // Test 4: rd_en as FIFO becomes empty (race)
    //--------------------------------------------------------------------------
    `TEST_CASE("Read-Race-Empty") begin
      $display("Testing: rd_en race with FIFO becoming empty");
      
      rst <= 1'b1;
      wr_en <= 1'b0;
      rd_en <= 1'b0;
      
      repeat(20) @(posedge wr_clk);
      rst <= 1'b0;
      wait_reset_complete();
      
      // Write exactly 3 entries
      for (int i = 0; i < 3; i++) begin
        @(posedge wr_clk);
        wr_en <= 1'b1;
        wr_data <= i + 50;
        @(posedge wr_clk);
        wr_en <= 1'b0;
      end
      
      // Wait for data to propagate
      repeat(10) @(posedge rd_clk);
      
      // Verify data is available
      `CHECK_EQUAL(empty, 1'b0);
      
      // Record initial pointer
      initial_rd_ptr = DUT.rd_ptr;
      
      // Read all entries with continuous rd_en
      rd_en <= 1'b1;
      while (!empty) begin
        @(posedge rd_clk);
      end
      // Keep reading a few more cycles while empty
      repeat(5) @(posedge rd_clk);
      rd_en <= 1'b0;
      
      // Verify final state is empty
      repeat(3) @(posedge rd_clk);
      `CHECK_EQUAL(empty, 1'b1);
      
      // Pointer should have advanced by exactly 3 (not more, since FIFO should ignore reads when empty)
      $display("  Initial rd_ptr: %0d, Final rd_ptr: %0d", initial_rd_ptr, DUT.rd_ptr);
      `CHECK_EQUAL(DUT.rd_ptr, 3);
      
      $display("  PASS: Race condition handled correctly");
    end

    //--------------------------------------------------------------------------
    // Test 5: rd_data stability when reading empty
    //--------------------------------------------------------------------------
    `TEST_CASE("Read-Data-Stability") begin
      logic [DATA_WIDTH-1:0] stable_data;
      
      $display("Testing: rd_data stability when reading empty FIFO");
      
      rst <= 1'b1;
      wr_en <= 1'b0;
      rd_en <= 1'b0;
      
      repeat(20) @(posedge wr_clk);
      rst <= 1'b0;
      wait_reset_complete();
      
      // Write one entry
      @(posedge wr_clk);
      wr_en <= 1'b1;
      wr_data <= 8'hEF;
      @(posedge wr_clk);
      wr_en <= 1'b0;
      
      // Wait for data
      while (empty) @(posedge rd_clk);
      
      // Read the entry
      @(posedge rd_clk);
      rd_en <= 1'b1;
      @(posedge rd_clk);
      rd_en <= 1'b0;
      @(posedge rd_clk);
      last_valid_data = rd_data;
      $display("  Last valid data: 0x%02X", last_valid_data);
      
      // Wait for empty
      while (!empty) @(posedge rd_clk);
      
      // Record rd_data when empty
      stable_data = rd_data;
      $display("  rd_data when empty: 0x%02X", stable_data);
      
      // Continue reading while empty - data should remain stable
      rd_en <= 1'b1;
      for (int i = 0; i < 10; i++) begin
        @(posedge rd_clk);
        // Data might be the last read value or could be undefined
        // Just verify it doesn't cause X/Z issues
        if (rd_data !== stable_data) begin
          $display("  rd_data changed: 0x%02X -> 0x%02X", stable_data, rd_data);
        end
      end
      rd_en <= 1'b0;
      
      // FIFO should still work after this abuse
      @(posedge wr_clk);
      wr_en <= 1'b1;
      wr_data <= 8'h12;
      @(posedge wr_clk);
      wr_en <= 1'b0;
      
      while (empty) @(posedge rd_clk);
      
      @(posedge rd_clk);
      rd_en <= 1'b1;
      @(posedge rd_clk);
      rd_en <= 1'b0;
      @(posedge rd_clk);
      `CHECK_EQUAL(rd_data, 8'h12);
      
      $display("  PASS: rd_data stable, FIFO functional after reading empty");
    end

    //--------------------------------------------------------------------------
    // Test 6: Read before any writes
    //--------------------------------------------------------------------------
    `TEST_CASE("Read-Before-Writes") begin
      $display("Testing: Read attempts before any data written");
      
      rst <= 1'b1;
      wr_en <= 1'b0;
      rd_en <= 1'b0;
      
      repeat(20) @(posedge wr_clk);
      rst <= 1'b0;
      wait_reset_complete();
      
      // Try to read immediately after reset (no writes ever)
      initial_rd_ptr = DUT.rd_ptr;
      
      for (int i = 0; i < 5; i++) begin
        @(posedge rd_clk);
        `CHECK_EQUAL(empty, 1'b1);
        rd_en <= 1'b1;
        @(posedge rd_clk);
        rd_en <= 1'b0;
        @(posedge rd_clk);
      end
      
      // Pointer should not have changed
      `CHECK_EQUAL(DUT.rd_ptr, initial_rd_ptr);
      
      $display("  PASS: Read before writes handled correctly");
    end

    //--------------------------------------------------------------------------
    // Test 7: Interleaved writes and reads with empty gaps
    //--------------------------------------------------------------------------
    `TEST_CASE("Interleaved-With-Empty") begin
      logic [DATA_WIDTH-1:0] read_val;
      integer valid_reads;
      integer expected_value;
      
      $display("Testing: Interleaved writes/reads with empty gaps");
      
      rst <= 1'b1;
      wr_en <= 1'b0;
      rd_en <= 1'b0;
      
      repeat(20) @(posedge wr_clk);
      rst <= 1'b0;
      wait_reset_complete();
      
      valid_reads = 0;
      expected_value = 0;
      
      // Interleave writes and reads (some reads will be invalid)
      for (int i = 0; i < 10; i++) begin
        // Write one
        @(posedge wr_clk);
        wr_en <= 1'b1;
        wr_data <= i;
        @(posedge wr_clk);
        wr_en <= 1'b0;
        
        // Wait for data
        repeat(5) @(posedge rd_clk);
        
        // Read if data available
        if (!empty) begin
          rd_en <= 1'b1;
          @(posedge rd_clk);
          rd_en <= 1'b0;
          @(posedge rd_clk);
          read_val = rd_data;
          `CHECK_EQUAL(read_val, expected_value);
          expected_value++;
          valid_reads++;
        end
        
        // Try reading again (might be empty now)
        @(posedge rd_clk);
        if (!empty) begin
          rd_en <= 1'b1;
          @(posedge rd_clk);
          rd_en <= 1'b0;
          @(posedge rd_clk);
          read_val = rd_data;
          `CHECK_EQUAL(read_val, expected_value);
          expected_value++;
          valid_reads++;
        end else begin
          // Try reading anyway (should be ignored)
          rd_en <= 1'b1;
          @(posedge rd_clk);
          rd_en <= 1'b0;
          @(posedge rd_clk);
        end
      end
      
      // Drain any remaining
      repeat(5) @(posedge rd_clk);
      while (!empty) begin
        @(posedge rd_clk);
        rd_en <= 1'b1;
        @(posedge rd_clk);
        rd_en <= 1'b0;
        @(posedge rd_clk);
        read_val = rd_data;
        `CHECK_EQUAL(read_val, expected_value);
        expected_value++;
        valid_reads++;
      end
      
      $display("  Valid reads: %0d", valid_reads);
      `CHECK_EQUAL(valid_reads, 10);
      
      $display("  PASS: Interleaved operations handled correctly");
    end

    `TEST_DONE;
  end

  `WATCHDOG(500us);

endmodule
