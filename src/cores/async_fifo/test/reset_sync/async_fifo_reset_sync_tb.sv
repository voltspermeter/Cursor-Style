`timescale 1ps/1ps
`include "vunit_defines.svh"

//------------------------------------------------------------------------------
// Reset Synchronization Test
//
// Verifies proper reset behavior across both clock domains:
// - Reset while FIFO contains data
// - Reset during active write/read
// - Reset release timing (8-cycle counter)
// - rd_rst and wr_rst synchronization
// - Multiple reset pulses
// - Short reset pulse behavior
//------------------------------------------------------------------------------

module async_fifo_reset_sync_tb;

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
  integer errors = 0;

  // Clock generation - 50 MHz each, phase offset
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

  // Helper task: Write data to FIFO
  task automatic write_data(input [DATA_WIDTH-1:0] data);
    @(posedge wr_clk);
    wr_en <= 1'b1;
    wr_data <= data;
    @(posedge wr_clk);
    wr_en <= 1'b0;
  endtask

  // Helper task: Read data from FIFO
  task automatic read_data(output [DATA_WIDTH-1:0] data);
    @(posedge rd_clk);
    rd_en <= 1'b1;
    @(posedge rd_clk);
    rd_en <= 1'b0;
    @(posedge rd_clk);
    data = rd_data;
  endtask

  // VCD generation
  initial begin
    $dumpfile("test_case_1.vcd");
    $dumpvars();
  end

  // Helper task: Wait for internal reset to complete
  task automatic wait_reset_complete();
    // Wait for both wr_rst and rd_rst to deassert
    fork
      begin
        while (DUT.wr_rst) @(posedge wr_clk);
      end
      begin
        while (DUT.rd_rst) @(posedge rd_clk);
      end
    join
    // Extra margin
    repeat(5) @(posedge wr_clk);
  endtask

  `TEST_SUITE begin

    //--------------------------------------------------------------------------
    // Test 1: Reset clears FIFO data
    //--------------------------------------------------------------------------
    `TEST_CASE("Reset-Clears-Data") begin
      $display("Testing: Assert reset while FIFO contains data");
      
      // Initialize
      rst <= 1'b1;
      wr_en <= 1'b0;
      rd_en <= 1'b0;
      wr_data <= 8'd0;
      
      repeat(20) @(posedge wr_clk);
      rst <= 1'b0;
      wait_reset_complete();
      
      // Write some data
      for (int i = 0; i < 8; i++) begin
        write_data(i);
      end
      
      // Verify FIFO has data
      repeat(5) @(posedge rd_clk);
      `CHECK_EQUAL(has_data, 1'b1);
      `CHECK_EQUAL(empty, 1'b0);
      
      // Assert reset
      $display("  Asserting reset with data in FIFO");
      rst <= 1'b1;
      repeat(10) @(posedge wr_clk);
      
      // Verify full is asserted during reset
      `CHECK_EQUAL(full, 1'b1);
      
      // Release reset
      rst <= 1'b0;
      wait_reset_complete();
      
      // Verify FIFO is now empty
      repeat(5) @(posedge rd_clk);
      `CHECK_EQUAL(empty, 1'b1);
      `CHECK_EQUAL(has_data, 1'b0);
      
      // Verify pointers are reset
      `CHECK_EQUAL(DUT.wr_ptr, 0);
      `CHECK_EQUAL(DUT.rd_ptr, 0);
      
      $display("  PASS: Reset cleared FIFO data");
    end

    //--------------------------------------------------------------------------
    // Test 2: Reset during active write
    //--------------------------------------------------------------------------
    `TEST_CASE("Reset-During-Write") begin
      $display("Testing: Assert reset during active write");
      
      rst <= 1'b1;
      wr_en <= 1'b0;
      rd_en <= 1'b0;
      
      repeat(20) @(posedge wr_clk);
      rst <= 1'b0;
      wait_reset_complete();
      
      // Start continuous writes
      wr_en <= 1'b1;
      wr_data <= 8'hAA;
      
      repeat(3) @(posedge wr_clk);
      
      // Assert reset mid-write
      $display("  Asserting reset during write");
      rst <= 1'b1;
      
      repeat(5) @(posedge wr_clk);
      wr_en <= 1'b0;
      
      repeat(10) @(posedge wr_clk);
      rst <= 1'b0;
      wait_reset_complete();
      
      // Verify pointers are reset
      `CHECK_EQUAL(DUT.wr_ptr, 0);
      `CHECK_EQUAL(DUT.rd_ptr, 0);
      `CHECK_EQUAL(empty, 1'b1);
      
      $display("  PASS: Reset during write handled correctly");
    end

    //--------------------------------------------------------------------------
    // Test 3: Reset during active read
    //--------------------------------------------------------------------------
    `TEST_CASE("Reset-During-Read") begin
      $display("Testing: Assert reset during active read");
      
      rst <= 1'b1;
      wr_en <= 1'b0;
      rd_en <= 1'b0;
      
      repeat(20) @(posedge wr_clk);
      rst <= 1'b0;
      wait_reset_complete();
      
      // Write data
      for (int i = 0; i < 8; i++) begin
        write_data(i);
      end
      
      repeat(5) @(posedge rd_clk);
      
      // Start continuous reads
      rd_en <= 1'b1;
      
      repeat(3) @(posedge rd_clk);
      
      // Assert reset mid-read
      $display("  Asserting reset during read");
      rst <= 1'b1;
      
      repeat(5) @(posedge rd_clk);
      rd_en <= 1'b0;
      
      repeat(10) @(posedge wr_clk);
      rst <= 1'b0;
      wait_reset_complete();
      
      // Verify pointers are reset
      `CHECK_EQUAL(DUT.wr_ptr, 0);
      `CHECK_EQUAL(DUT.rd_ptr, 0);
      
      $display("  PASS: Reset during read handled correctly");
    end

    //--------------------------------------------------------------------------
    // Test 4: Reset release timing (8-cycle counter + synchronizer delay)
    //--------------------------------------------------------------------------
    `TEST_CASE("Reset-Release-Timing") begin
      integer wr_rst_cycles, rd_rst_cycles;
      
      $display("Testing: Reset release timing");
      
      rst <= 1'b1;
      wr_en <= 1'b0;
      rd_en <= 1'b0;
      
      repeat(20) @(posedge wr_clk);
      rst <= 1'b0;
      
      // Count cycles until wr_rst deasserts
      wr_rst_cycles = 0;
      while (DUT.wr_rst && wr_rst_cycles < 30) begin
        @(posedge wr_clk);
        wr_rst_cycles++;
      end
      
      $display("  wr_rst deasserted after %0d cycles", wr_rst_cycles);
      
      // Reset again and count rd_rst
      rst <= 1'b1;
      repeat(10) @(posedge rd_clk);
      rst <= 1'b0;
      
      rd_rst_cycles = 0;
      while (DUT.rd_rst && rd_rst_cycles < 30) begin
        @(posedge rd_clk);
        rd_rst_cycles++;
      end
      
      $display("  rd_rst deasserted after %0d cycles", rd_rst_cycles);
      
      // Reset timing includes: 8-cycle counter + 2-3 cycle synchronizer delay
      // Allow range 8-15 cycles for complete reset release
      `CHECK_TRUE(wr_rst_cycles >= 8 && wr_rst_cycles <= 15);
      `CHECK_TRUE(rd_rst_cycles >= 8 && rd_rst_cycles <= 15);
      
      $display("  PASS: Reset release timing correct");
    end

    //--------------------------------------------------------------------------
    // Test 5: Multiple reset pulses
    //--------------------------------------------------------------------------
    `TEST_CASE("Multiple-Reset-Pulses") begin
      $display("Testing: Multiple reset pulses in succession");
      
      rst <= 1'b1;
      wr_en <= 1'b0;
      rd_en <= 1'b0;
      
      repeat(20) @(posedge wr_clk);
      rst <= 1'b0;
      wait_reset_complete();
      
      // Multiple rapid reset pulses
      for (int pulse = 0; pulse < 3; pulse++) begin
        $display("  Reset pulse %0d", pulse + 1);
        
        // Write some data
        for (int i = 0; i < 4; i++) begin
          write_data(pulse * 16 + i);
        end
        
        repeat(3) @(posedge wr_clk);
        
        // Quick reset
        rst <= 1'b1;
        repeat(5) @(posedge wr_clk);
        rst <= 1'b0;
        wait_reset_complete();
        
        // Verify clean state
        `CHECK_EQUAL(DUT.wr_ptr, 0);
        `CHECK_EQUAL(DUT.rd_ptr, 0);
        `CHECK_EQUAL(empty, 1'b1);
      end
      
      $display("  PASS: Multiple reset pulses handled correctly");
    end

    //--------------------------------------------------------------------------
    // Test 6: Short reset pulse (< 8 cycles)
    //--------------------------------------------------------------------------
    `TEST_CASE("Short-Reset-Pulse") begin
      $display("Testing: Short reset pulse behavior");
      
      rst <= 1'b1;
      wr_en <= 1'b0;
      rd_en <= 1'b0;
      
      repeat(20) @(posedge wr_clk);
      rst <= 1'b0;
      wait_reset_complete();
      
      // Write data
      for (int i = 0; i < 4; i++) begin
        write_data(i);
      end
      
      repeat(3) @(posedge wr_clk);
      
      // Very short reset pulse (2 cycles)
      $display("  Applying 2-cycle reset pulse");
      rst <= 1'b1;
      repeat(2) @(posedge wr_clk);
      rst <= 1'b0;
      
      // The reset should still be processed due to synchronizers
      wait_reset_complete();
      
      // Verify FIFO was reset
      `CHECK_EQUAL(DUT.wr_ptr, 0);
      `CHECK_EQUAL(DUT.rd_ptr, 0);
      
      $display("  PASS: Short reset pulse handled correctly");
    end

    //--------------------------------------------------------------------------
    // Test 7: Full flag during reset
    //--------------------------------------------------------------------------
    `TEST_CASE("Full-Flag-During-Reset") begin
      $display("Testing: Full flag asserted during reset");
      
      rst <= 1'b1;
      wr_en <= 1'b0;
      rd_en <= 1'b0;
      
      // During reset, full should be asserted
      repeat(5) @(posedge wr_clk);
      `CHECK_EQUAL(full, 1'b1);
      
      repeat(15) @(posedge wr_clk);
      rst <= 1'b0;
      
      // Wait for internal reset
      while (DUT.wr_rst) @(posedge wr_clk);
      
      // After reset complete, full should deassert (FIFO is empty)
      repeat(3) @(posedge wr_clk);
      `CHECK_EQUAL(full, 1'b0);
      
      $display("  PASS: Full flag behavior during reset correct");
    end

    //--------------------------------------------------------------------------
    // Test 8: Functional operation after reset
    //--------------------------------------------------------------------------
    `TEST_CASE("Operation-After-Reset") begin
      logic [DATA_WIDTH-1:0] read_val;
      
      $display("Testing: FIFO functional after reset");
      
      rst <= 1'b1;
      wr_en <= 1'b0;
      rd_en <= 1'b0;
      
      repeat(20) @(posedge wr_clk);
      rst <= 1'b0;
      wait_reset_complete();
      
      // Write sequential data
      for (int i = 0; i < 8; i++) begin
        write_data(i + 100);
      end
      
      // Wait for data to propagate
      repeat(10) @(posedge rd_clk);
      
      // Read and verify
      for (int i = 0; i < 8; i++) begin
        read_data(read_val);
        `CHECK_EQUAL(read_val, i + 100);
      end
      
      $display("  PASS: FIFO functional after reset");
    end

    `TEST_DONE;
  end

  `WATCHDOG(500us);

endmodule
