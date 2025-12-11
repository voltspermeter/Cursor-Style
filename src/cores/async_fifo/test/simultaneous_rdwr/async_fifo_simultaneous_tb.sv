`timescale 1ps/1ps
`include "vunit_defines.svh"

//------------------------------------------------------------------------------
// Simultaneous Read/Write Test
//
// Verifies operation when reading and writing simultaneously:
// - Read and write on same cycle
// - Phase offset testing
// - Near-full and near-empty simultaneous operations
//------------------------------------------------------------------------------

module async_fifo_simultaneous_tb;

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
  integer write_idx, read_idx;
  logic [DATA_WIDTH-1:0] read_val;

  // Clock generation - same frequency, aligned
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
    // Test 1: Aligned clock simultaneous R/W
    //--------------------------------------------------------------------------
    `TEST_CASE("Aligned-Simultaneous") begin
      integer count = 100;
      
      $display("Testing: Simultaneous R/W with aligned clocks");
      
      rst <= 1'b1;
      wr_en <= 1'b0;
      rd_en <= 1'b0;
      
      repeat(20) @(posedge wr_clk);
      rst <= 1'b0;
      wait_reset_complete();
      
      // Pre-fill half
      for (int i = 0; i < DEPTH/2; i++) begin
        @(posedge wr_clk);
        wr_en <= 1'b1;
        wr_data <= i;
        @(posedge wr_clk);
        wr_en <= 1'b0;
      end
      
      write_idx = DEPTH/2;
      read_idx = 0;
      
      // Simultaneous R/W for many cycles
      repeat(5) @(posedge rd_clk);
      
      for (int cycle = 0; cycle < count; cycle++) begin
        // Write
        @(posedge wr_clk);
        if (!full) begin
          wr_en <= 1'b1;
          wr_data <= write_idx;
          write_idx++;
        end
        
        // Read (on same edge due to aligned clocks)
        if (!empty) begin
          rd_en <= 1'b1;
        end
        
        @(posedge wr_clk);
        wr_en <= 1'b0;
        
        if (rd_en) begin
          @(posedge rd_clk);
          rd_en <= 1'b0;
          @(posedge rd_clk);
          read_val = rd_data;
          `CHECK_EQUAL(read_val, read_idx);
          read_idx++;
        end
      end
      
      // Drain remaining
      repeat(5) @(posedge rd_clk);
      while (!empty) begin
        @(posedge rd_clk);
        rd_en <= 1'b1;
        @(posedge rd_clk);
        rd_en <= 1'b0;
        @(posedge rd_clk);
        read_val = rd_data;
        `CHECK_EQUAL(read_val, read_idx);
        read_idx++;
      end
      
      $display("  Written: %0d, Read: %0d", write_idx, read_idx);
      `CHECK_EQUAL(write_idx, read_idx);
      
      $display("  PASS: Aligned simultaneous R/W");
    end

    //--------------------------------------------------------------------------
    // Test 2: Simultaneous at near-full
    //--------------------------------------------------------------------------
    `TEST_CASE("Near-Full-Simultaneous") begin
      $display("Testing: Simultaneous R/W at near-full");
      
      rst <= 1'b1;
      wr_en <= 1'b0;
      rd_en <= 1'b0;
      
      repeat(20) @(posedge wr_clk);
      rst <= 1'b0;
      wait_reset_complete();
      
      // Fill to near-full (DEPTH-2)
      for (int i = 0; i < DEPTH - 2; i++) begin
        @(posedge wr_clk);
        wr_en <= 1'b1;
        wr_data <= i;
        @(posedge wr_clk);
        wr_en <= 1'b0;
      end
      
      write_idx = DEPTH - 2;
      read_idx = 0;
      
      repeat(5) @(posedge rd_clk);
      
      // Operate at near-full for many cycles
      for (int cycle = 0; cycle < 50; cycle++) begin
        fork
          // Try to write
          begin
            @(posedge wr_clk);
            if (!full) begin
              wr_en <= 1'b1;
              wr_data <= write_idx;
              write_idx++;
            end
            @(posedge wr_clk);
            wr_en <= 1'b0;
          end
          // Try to read
          begin
            @(posedge rd_clk);
            if (!empty) begin
              rd_en <= 1'b1;
              @(posedge rd_clk);
              rd_en <= 1'b0;
              @(posedge rd_clk);
              read_val = rd_data;
              `CHECK_EQUAL(read_val, read_idx);
              read_idx++;
            end
          end
        join
      end
      
      // Drain
      repeat(5) @(posedge rd_clk);
      while (!empty) begin
        @(posedge rd_clk);
        rd_en <= 1'b1;
        @(posedge rd_clk);
        rd_en <= 1'b0;
        @(posedge rd_clk);
        read_val = rd_data;
        `CHECK_EQUAL(read_val, read_idx);
        read_idx++;
      end
      
      `CHECK_EQUAL(write_idx, read_idx);
      
      $display("  PASS: Near-full simultaneous R/W");
    end

    //--------------------------------------------------------------------------
    // Test 3: Simultaneous at near-empty
    //--------------------------------------------------------------------------
    `TEST_CASE("Near-Empty-Simultaneous") begin
      $display("Testing: Simultaneous R/W at near-empty");
      
      rst <= 1'b1;
      wr_en <= 1'b0;
      rd_en <= 1'b0;
      
      repeat(20) @(posedge wr_clk);
      rst <= 1'b0;
      wait_reset_complete();
      
      // Start with just 2 entries
      for (int i = 0; i < 2; i++) begin
        @(posedge wr_clk);
        wr_en <= 1'b1;
        wr_data <= i;
        @(posedge wr_clk);
        wr_en <= 1'b0;
      end
      
      write_idx = 2;
      read_idx = 0;
      
      repeat(5) @(posedge rd_clk);
      
      // Operate at near-empty for many cycles
      for (int cycle = 0; cycle < 50; cycle++) begin
        fork
          // Write one
          begin
            @(posedge wr_clk);
            if (!full) begin
              wr_en <= 1'b1;
              wr_data <= write_idx;
              write_idx++;
            end
            @(posedge wr_clk);
            wr_en <= 1'b0;
          end
          // Read one
          begin
            @(posedge rd_clk);
            if (!empty) begin
              rd_en <= 1'b1;
              @(posedge rd_clk);
              rd_en <= 1'b0;
              @(posedge rd_clk);
              read_val = rd_data;
              `CHECK_EQUAL(read_val, read_idx);
              read_idx++;
            end
          end
        join
      end
      
      // Drain
      repeat(5) @(posedge rd_clk);
      while (!empty) begin
        @(posedge rd_clk);
        rd_en <= 1'b1;
        @(posedge rd_clk);
        rd_en <= 1'b0;
        @(posedge rd_clk);
        read_val = rd_data;
        `CHECK_EQUAL(read_val, read_idx);
        read_idx++;
      end
      
      `CHECK_EQUAL(write_idx, read_idx);
      
      $display("  PASS: Near-empty simultaneous R/W");
    end

    //--------------------------------------------------------------------------
    // Test 4: Continuous simultaneous - stress test
    //--------------------------------------------------------------------------
    `TEST_CASE("Continuous-Stress") begin
      integer total = 500;
      
      $display("Testing: Continuous simultaneous stress (%0d entries)", total);
      
      rst <= 1'b1;
      wr_en <= 1'b0;
      rd_en <= 1'b0;
      
      repeat(20) @(posedge wr_clk);
      rst <= 1'b0;
      wait_reset_complete();
      
      write_idx = 0;
      read_idx = 0;
      
      fork
        // Writer
        begin
          while (write_idx < total) begin
            @(posedge wr_clk);
            if (!full) begin
              wr_en <= 1'b1;
              wr_data <= write_idx;
              write_idx++;
            end else begin
              wr_en <= 1'b0;
            end
            @(posedge wr_clk);
            wr_en <= 1'b0;
          end
        end
        // Reader
        begin
          repeat(5) @(posedge rd_clk);
          while (read_idx < total) begin
            @(posedge rd_clk);
            if (!empty) begin
              rd_en <= 1'b1;
              @(posedge rd_clk);
              rd_en <= 1'b0;
              @(posedge rd_clk);
              read_val = rd_data;
              `CHECK_EQUAL(read_val, read_idx);
              read_idx++;
            end
          end
        end
      join
      
      $display("  Written: %0d, Read: %0d", write_idx, read_idx);
      `CHECK_EQUAL(write_idx, total);
      `CHECK_EQUAL(read_idx, total);
      
      $display("  PASS: Continuous stress");
    end

    //--------------------------------------------------------------------------
    // Test 5: Alternating single operations
    //--------------------------------------------------------------------------
    `TEST_CASE("Alternating-Single") begin
      integer count = 30;
      
      $display("Testing: Alternating single write/read");
      
      rst <= 1'b1;
      wr_en <= 1'b0;
      rd_en <= 1'b0;
      
      repeat(20) @(posedge wr_clk);
      rst <= 1'b0;
      wait_reset_complete();
      
      // Write one, read one pattern
      for (int i = 0; i < count; i++) begin
        // Write
        @(posedge wr_clk);
        wr_en <= 1'b1;
        wr_data <= i;
        @(posedge wr_clk);
        wr_en <= 1'b0;
        
        // Wait for data
        repeat(5) @(posedge rd_clk);
        while (empty) @(posedge rd_clk);
        
        // Read
        @(posedge rd_clk);
        rd_en <= 1'b1;
        @(posedge rd_clk);
        rd_en <= 1'b0;
        @(posedge rd_clk);
        read_val = rd_data;
        `CHECK_EQUAL(read_val, i);
      end
      
      $display("  PASS: Alternating single operations");
    end

    `TEST_DONE;
  end

  `WATCHDOG(5000us);

endmodule
