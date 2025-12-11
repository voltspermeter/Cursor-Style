`timescale 1ps/1ps
`include "vunit_defines.svh"

//------------------------------------------------------------------------------
// Back-to-Back Operations Test
//
// Verifies continuous streaming operation:
// - Continuous writes until full, reads until empty
// - Simultaneous read/write at steady state
// - Burst transfers
// - Single-cycle gaps
//------------------------------------------------------------------------------

module async_fifo_back_to_back_tb;

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
  integer write_count, read_count;
  integer expected_read;
  logic [DATA_WIDTH-1:0] read_val;

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
    // Test 1: Continuous writes until full
    //--------------------------------------------------------------------------
    `TEST_CASE("Fill-To-Full") begin
      $display("Testing: Continuous writes until full");
      
      rst <= 1'b1;
      wr_en <= 1'b0;
      rd_en <= 1'b0;
      write_count = 0;
      
      repeat(20) @(posedge wr_clk);
      rst <= 1'b0;
      wait_reset_complete();
      
      // Write continuously until full
      while (!full && write_count < DEPTH + 5) begin
        @(posedge wr_clk);
        wr_en <= 1'b1;
        wr_data <= write_count;
        @(posedge wr_clk);
        wr_en <= 1'b0;
        write_count++;
      end
      
      $display("  Wrote %0d entries before full", write_count);
      `CHECK_EQUAL(full, 1'b1);
      `CHECK_TRUE(write_count >= DEPTH - 1 && write_count <= DEPTH + 1);
      
      // Now drain completely
      repeat(5) @(posedge rd_clk);
      read_count = 0;
      expected_read = 0;
      
      while (!empty) begin
        @(posedge rd_clk);
        rd_en <= 1'b1;
        @(posedge rd_clk);
        rd_en <= 1'b0;
        @(posedge rd_clk);
        read_val = rd_data;
        `CHECK_EQUAL(read_val, expected_read);
        expected_read++;
        read_count++;
      end
      
      $display("  Read %0d entries", read_count);
      `CHECK_EQUAL(read_count, write_count);
      
      $display("  PASS: Fill to full");
    end

    //--------------------------------------------------------------------------
    // Test 2: Steady-state streaming
    //--------------------------------------------------------------------------
    `TEST_CASE("Steady-State-Stream") begin
      integer stream_count = 200;
      
      $display("Testing: Steady-state streaming (%0d entries)", stream_count);
      
      rst <= 1'b1;
      wr_en <= 1'b0;
      rd_en <= 1'b0;
      
      repeat(20) @(posedge wr_clk);
      rst <= 1'b0;
      wait_reset_complete();
      
      // Pre-fill half the FIFO
      for (int i = 0; i < DEPTH/2; i++) begin
        @(posedge wr_clk);
        wr_en <= 1'b1;
        wr_data <= i;
        @(posedge wr_clk);
        wr_en <= 1'b0;
      end
      
      write_count = DEPTH/2;
      read_count = 0;
      expected_read = 0;
      
      // Simultaneous read/write
      fork
        // Writer
        begin
          for (int i = DEPTH/2; i < stream_count; i++) begin
            @(posedge wr_clk);
            while (full) @(posedge wr_clk);
            wr_en <= 1'b1;
            wr_data <= i;
            @(posedge wr_clk);
            wr_en <= 1'b0;
            write_count++;
          end
        end
        // Reader
        begin
          repeat(5) @(posedge rd_clk);
          for (int i = 0; i < stream_count; i++) begin
            @(posedge rd_clk);
            while (empty) @(posedge rd_clk);
            rd_en <= 1'b1;
            @(posedge rd_clk);
            rd_en <= 1'b0;
            @(posedge rd_clk);
            read_val = rd_data;
            `CHECK_EQUAL(read_val, expected_read);
            expected_read++;
            read_count++;
          end
        end
      join
      
      $display("  Wrote: %0d, Read: %0d", write_count, read_count);
      `CHECK_EQUAL(write_count, stream_count);
      `CHECK_EQUAL(read_count, stream_count);
      
      $display("  PASS: Steady-state streaming");
    end

    //--------------------------------------------------------------------------
    // Test 3: Burst write, burst read
    //--------------------------------------------------------------------------
    `TEST_CASE("Burst-Transfer") begin
      integer burst_size = DEPTH - 2;
      integer num_bursts = 5;
      
      $display("Testing: Burst transfers (%0d x %0d entries)", num_bursts, burst_size);
      
      rst <= 1'b1;
      wr_en <= 1'b0;
      rd_en <= 1'b0;
      
      repeat(20) @(posedge wr_clk);
      rst <= 1'b0;
      wait_reset_complete();
      
      expected_read = 0;
      
      for (int burst = 0; burst < num_bursts; burst++) begin
        // Write burst
        for (int i = 0; i < burst_size; i++) begin
          @(posedge wr_clk);
          wr_en <= 1'b1;
          wr_data <= burst * burst_size + i;
          @(posedge wr_clk);
          wr_en <= 1'b0;
        end
        
        // Read burst
        repeat(5) @(posedge rd_clk);
        for (int i = 0; i < burst_size; i++) begin
          while (empty) @(posedge rd_clk);
          @(posedge rd_clk);
          rd_en <= 1'b1;
          @(posedge rd_clk);
          rd_en <= 1'b0;
          @(posedge rd_clk);
          read_val = rd_data;
          `CHECK_EQUAL(read_val, expected_read);
          expected_read++;
        end
      end
      
      `CHECK_EQUAL(expected_read, num_bursts * burst_size);
      
      $display("  PASS: Burst transfers");
    end

    //--------------------------------------------------------------------------
    // Test 4: Single-cycle write gaps
    //--------------------------------------------------------------------------
    `TEST_CASE("Write-Gaps") begin
      integer count = 50;
      
      $display("Testing: Single-cycle gaps in write stream");
      
      rst <= 1'b1;
      wr_en <= 1'b0;
      rd_en <= 1'b0;
      
      repeat(20) @(posedge wr_clk);
      rst <= 1'b0;
      wait_reset_complete();
      
      expected_read = 0;
      
      fork
        // Writer with gaps
        begin
          for (int i = 0; i < count; i++) begin
            @(posedge wr_clk);
            wr_en <= 1'b1;
            wr_data <= i;
            @(posedge wr_clk);
            wr_en <= 1'b0;
            @(posedge wr_clk);  // Gap cycle
          end
        end
        // Continuous reader
        begin
          repeat(10) @(posedge rd_clk);
          for (int i = 0; i < count; i++) begin
            while (empty) @(posedge rd_clk);
            @(posedge rd_clk);
            rd_en <= 1'b1;
            @(posedge rd_clk);
            rd_en <= 1'b0;
            @(posedge rd_clk);
            read_val = rd_data;
            `CHECK_EQUAL(read_val, expected_read);
            expected_read++;
          end
        end
      join
      
      `CHECK_EQUAL(expected_read, count);
      
      $display("  PASS: Write gaps");
    end

    //--------------------------------------------------------------------------
    // Test 5: Single-cycle read gaps
    //--------------------------------------------------------------------------
    `TEST_CASE("Read-Gaps") begin
      integer count = 50;
      
      $display("Testing: Single-cycle gaps in read stream");
      
      rst <= 1'b1;
      wr_en <= 1'b0;
      rd_en <= 1'b0;
      
      repeat(20) @(posedge wr_clk);
      rst <= 1'b0;
      wait_reset_complete();
      
      expected_read = 0;
      
      fork
        // Continuous writer
        begin
          for (int i = 0; i < count; i++) begin
            @(posedge wr_clk);
            while (full) @(posedge wr_clk);
            wr_en <= 1'b1;
            wr_data <= i;
            @(posedge wr_clk);
            wr_en <= 1'b0;
          end
        end
        // Reader with gaps
        begin
          repeat(10) @(posedge rd_clk);
          for (int i = 0; i < count; i++) begin
            while (empty) @(posedge rd_clk);
            @(posedge rd_clk);
            rd_en <= 1'b1;
            @(posedge rd_clk);
            rd_en <= 1'b0;
            @(posedge rd_clk);
            read_val = rd_data;
            `CHECK_EQUAL(read_val, expected_read);
            expected_read++;
            @(posedge rd_clk);  // Gap cycle
          end
        end
      join
      
      `CHECK_EQUAL(expected_read, count);
      
      $display("  PASS: Read gaps");
    end

    //--------------------------------------------------------------------------
    // Test 6: Maximum throughput
    //--------------------------------------------------------------------------
    `TEST_CASE("Max-Throughput") begin
      integer count = 100;
      time start_time, end_time;
      
      $display("Testing: Maximum throughput");
      
      rst <= 1'b1;
      wr_en <= 1'b0;
      rd_en <= 1'b0;
      
      repeat(20) @(posedge wr_clk);
      rst <= 1'b0;
      wait_reset_complete();
      
      // Pre-fill
      for (int i = 0; i < DEPTH/2; i++) begin
        @(posedge wr_clk);
        wr_en <= 1'b1;
        wr_data <= i;
        @(posedge wr_clk);
        wr_en <= 1'b0;
      end
      
      repeat(5) @(posedge rd_clk);
      expected_read = 0;
      start_time = $time;
      
      // Back-to-back operations
      fork
        // Writer - continuous
        begin
          for (int i = DEPTH/2; i < count; i++) begin
            @(posedge wr_clk);
            if (!full) begin
              wr_en <= 1'b1;
              wr_data <= i;
            end else begin
              wr_en <= 1'b0;
              i--;  // Retry
            end
            @(posedge wr_clk);
            wr_en <= 1'b0;
          end
        end
        // Reader - continuous
        begin
          for (int i = 0; i < count; i++) begin
            @(posedge rd_clk);
            if (!empty) begin
              rd_en <= 1'b1;
              @(posedge rd_clk);
              rd_en <= 1'b0;
              @(posedge rd_clk);
              read_val = rd_data;
              `CHECK_EQUAL(read_val, expected_read);
              expected_read++;
            end else begin
              rd_en <= 1'b0;
              i--;  // Retry
            end
          end
        end
      join
      
      end_time = $time;
      $display("  Transferred %0d entries in %0t", count, end_time - start_time);
      `CHECK_EQUAL(expected_read, count);
      
      $display("  PASS: Maximum throughput");
    end

    `TEST_DONE;
  end

  `WATCHDOG(3000us);

endmodule
