`timescale 1ps/1ps
`include "vunit_defines.svh"

//------------------------------------------------------------------------------
// Clock Switching Test
//
// Verifies operation when clock frequency changes:
// - Frequency change mid-transfer
// - Frequency change while FIFO is full
// - Frequency change while FIFO is empty
// - Clock stopping and restarting
//------------------------------------------------------------------------------

module async_fifo_clock_switching_tb;

  // Parameters
  localparam DATA_WIDTH = 8;
  localparam ADDR_WIDTH = 4;
  localparam DEPTH = 2**ADDR_WIDTH;
  
  // Clock periods
  localparam FAST_PERIOD = 8000;   // 8ns (125MHz)
  localparam SLOW_PERIOD = 20000;  // 20ns (50MHz)
  localparam MED_PERIOD = 10000;   // 10ns (100MHz)

  // Signals
  logic rst;
  logic wr_clk = 1'b0;
  logic rd_clk = 1'b0;
  logic wr_en;
  logic rd_en;
  logic [DATA_WIDTH-1:0] wr_data;
  wire [DATA_WIDTH-1:0] rd_data;
  wire full, empty, has_data;

  // Clock control
  integer wr_period = MED_PERIOD;
  integer rd_period = MED_PERIOD;
  logic wr_clk_en = 1;
  logic rd_clk_en = 1;

  // Test tracking
  integer write_count;
  integer read_count;
  integer error_count;
  logic [DATA_WIDTH-1:0] read_val;

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

  // Write clock generation with variable period
  initial begin
    forever begin
      if (wr_clk_en) begin
        #(wr_period) wr_clk = !wr_clk;
      end else begin
        #1000;  // Wait while clock is disabled
      end
    end
  end

  // Read clock generation with variable period
  initial begin
    forever begin
      if (rd_clk_en) begin
        #(rd_period) rd_clk = !rd_clk;
      end else begin
        #1000;  // Wait while clock is disabled
      end
    end
  end

  // Helper task: Wait for reset complete
  task automatic wait_reset_complete();
    while (DUT.wr_rst || DUT.rd_rst) @(posedge wr_clk);
    repeat(5) @(posedge wr_clk);
  endtask

  `TEST_SUITE begin

    //--------------------------------------------------------------------------
    // Test 1: Frequency change mid-transfer
    //--------------------------------------------------------------------------
    `TEST_CASE("Freq-Change-Mid-Transfer") begin
      integer wr_idx, rd_idx;
      integer count = 100;
      
      $display("Testing: Frequency change during data transfer");
      
      rst <= 1'b1;
      wr_en <= 1'b0;
      rd_en <= 1'b0;
      wr_period = MED_PERIOD;
      rd_period = MED_PERIOD;
      error_count = 0;
      
      repeat(20) @(posedge wr_clk);
      rst <= 1'b0;
      wait_reset_complete();
      
      fork
        // Writer with frequency changes
        begin
          wr_idx = 0;
          while (wr_idx < count) begin
            @(posedge wr_clk);
            if (!full) begin
              wr_en <= 1'b1;
              wr_data <= wr_idx[DATA_WIDTH-1:0];
              wr_idx++;
              
              // Change write frequency at various points
              if (wr_idx == 25) wr_period = FAST_PERIOD;
              if (wr_idx == 50) wr_period = SLOW_PERIOD;
              if (wr_idx == 75) wr_period = MED_PERIOD;
            end else begin
              wr_en <= 1'b0;
            end
          end
          wr_en <= 1'b0;
        end
        // Reader with frequency changes
        begin
          rd_idx = 0;
          repeat(5) @(posedge rd_clk);
          while (rd_idx < count) begin
            @(posedge rd_clk);
            if (!empty) begin
              rd_en <= 1'b1;
              @(posedge rd_clk);
              rd_en <= 1'b0;
              @(posedge rd_clk);
              read_val = rd_data;
              if (read_val !== rd_idx[DATA_WIDTH-1:0]) begin
                error_count++;
              end
              rd_idx++;
              
              // Change read frequency at various points
              if (rd_idx == 30) rd_period = SLOW_PERIOD;
              if (rd_idx == 60) rd_period = FAST_PERIOD;
              if (rd_idx == 90) rd_period = MED_PERIOD;
            end else begin
              rd_en <= 1'b0;
            end
          end
        end
      join
      
      $display("  Errors: %0d", error_count);
      `CHECK_EQUAL(error_count, 0);
      $display("  PASS: Frequency change mid-transfer");
    end

    //--------------------------------------------------------------------------
    // Test 2: Frequency change while FIFO is full
    //--------------------------------------------------------------------------
    `TEST_CASE("Freq-Change-Full") begin
      integer rd_idx;
      
      $display("Testing: Frequency change while FIFO is full");
      
      rst <= 1'b1;
      wr_en <= 1'b0;
      rd_en <= 1'b0;
      wr_period = MED_PERIOD;
      rd_period = MED_PERIOD;
      error_count = 0;
      
      repeat(20) @(posedge wr_clk);
      rst <= 1'b0;
      wait_reset_complete();
      
      // Fill FIFO
      write_count = 0;
      while (!full) begin
        @(posedge wr_clk);
        if (!full) begin
          wr_en <= 1'b1;
          wr_data <= write_count[DATA_WIDTH-1:0];
          write_count++;
        end
      end
      wr_en <= 1'b0;
      
      $display("  FIFO full with %0d entries", write_count);
      
      // Change both frequencies while full
      wr_period = FAST_PERIOD;
      rd_period = SLOW_PERIOD;
      repeat(20) @(posedge wr_clk);
      
      wr_period = SLOW_PERIOD;
      rd_period = FAST_PERIOD;
      repeat(20) @(posedge wr_clk);
      
      // Empty and verify
      rd_idx = 0;
      repeat(5) @(posedge rd_clk);
      while (!empty) begin
        @(posedge rd_clk);
        if (!empty) begin
          rd_en <= 1'b1;
          @(posedge rd_clk);
          rd_en <= 1'b0;
          @(posedge rd_clk);
          read_val = rd_data;
          if (read_val !== rd_idx[DATA_WIDTH-1:0]) begin
            error_count++;
          end
          rd_idx++;
        end
      end
      
      $display("  Read %0d entries, errors: %0d", rd_idx, error_count);
      `CHECK_EQUAL(error_count, 0);
      $display("  PASS: Frequency change while full");
    end

    //--------------------------------------------------------------------------
    // Test 3: Frequency change while FIFO is empty
    //--------------------------------------------------------------------------
    `TEST_CASE("Freq-Change-Empty") begin
      integer wr_idx, rd_idx;
      integer count = 50;
      
      $display("Testing: Frequency change while FIFO is empty");
      
      rst <= 1'b1;
      wr_en <= 1'b0;
      rd_en <= 1'b0;
      wr_period = MED_PERIOD;
      rd_period = MED_PERIOD;
      error_count = 0;
      
      repeat(20) @(posedge wr_clk);
      rst <= 1'b0;
      wait_reset_complete();
      
      // Verify empty
      `CHECK_EQUAL(empty, 1'b1);
      
      // Change frequencies while empty
      wr_period = FAST_PERIOD;
      rd_period = SLOW_PERIOD;
      repeat(20) @(posedge wr_clk);
      
      wr_period = SLOW_PERIOD;
      rd_period = FAST_PERIOD;
      repeat(20) @(posedge wr_clk);
      
      // Now transfer data
      wr_period = MED_PERIOD;
      rd_period = MED_PERIOD;
      
      fork
        begin
          wr_idx = 0;
          while (wr_idx < count) begin
            @(posedge wr_clk);
            if (!full) begin
              wr_en <= 1'b1;
              wr_data <= wr_idx[DATA_WIDTH-1:0];
              wr_idx++;
            end else begin
              wr_en <= 1'b0;
            end
          end
          wr_en <= 1'b0;
        end
        begin
          rd_idx = 0;
          repeat(5) @(posedge rd_clk);
          while (rd_idx < count) begin
            @(posedge rd_clk);
            if (!empty) begin
              rd_en <= 1'b1;
              @(posedge rd_clk);
              rd_en <= 1'b0;
              @(posedge rd_clk);
              read_val = rd_data;
              if (read_val !== rd_idx[DATA_WIDTH-1:0]) begin
                error_count++;
              end
              rd_idx++;
            end else begin
              rd_en <= 1'b0;
            end
          end
        end
      join
      
      $display("  Errors: %0d", error_count);
      `CHECK_EQUAL(error_count, 0);
      $display("  PASS: Frequency change while empty");
    end

    //--------------------------------------------------------------------------
    // Test 4: Clock pause and resume (write clock)
    //--------------------------------------------------------------------------
    `TEST_CASE("Write-Clock-Pause") begin
      integer wr_idx, rd_idx;
      integer count = 40;
      
      $display("Testing: Write clock pause and resume");
      
      rst <= 1'b1;
      wr_en <= 1'b0;
      rd_en <= 1'b0;
      wr_period = MED_PERIOD;
      rd_period = MED_PERIOD;
      wr_clk_en = 1;
      rd_clk_en = 1;
      error_count = 0;
      
      repeat(20) @(posedge wr_clk);
      rst <= 1'b0;
      wait_reset_complete();
      
      fork
        // Writer with pause
        begin
          wr_idx = 0;
          while (wr_idx < count) begin
            @(posedge wr_clk);
            if (!full) begin
              wr_en <= 1'b1;
              wr_data <= wr_idx[DATA_WIDTH-1:0];
              wr_idx++;
              
              // Pause write clock at 20
              if (wr_idx == 20) begin
                @(posedge wr_clk);
                wr_en <= 1'b0;
                wr_clk_en = 0;
                #100000;  // 100ns pause
                wr_clk_en = 1;
              end
            end else begin
              wr_en <= 1'b0;
            end
          end
          wr_en <= 1'b0;
        end
        // Reader
        begin
          rd_idx = 0;
          repeat(5) @(posedge rd_clk);
          while (rd_idx < count) begin
            @(posedge rd_clk);
            if (!empty) begin
              rd_en <= 1'b1;
              @(posedge rd_clk);
              rd_en <= 1'b0;
              @(posedge rd_clk);
              read_val = rd_data;
              if (read_val !== rd_idx[DATA_WIDTH-1:0]) begin
                error_count++;
              end
              rd_idx++;
            end else begin
              rd_en <= 1'b0;
            end
          end
        end
      join
      
      $display("  Errors: %0d", error_count);
      `CHECK_EQUAL(error_count, 0);
      $display("  PASS: Write clock pause and resume");
    end

    //--------------------------------------------------------------------------
    // Test 5: Clock pause and resume (read clock)
    //--------------------------------------------------------------------------
    `TEST_CASE("Read-Clock-Pause") begin
      integer wr_idx, rd_idx;
      integer count = 40;
      
      $display("Testing: Read clock pause and resume");
      
      rst <= 1'b1;
      wr_en <= 1'b0;
      rd_en <= 1'b0;
      wr_period = MED_PERIOD;
      rd_period = MED_PERIOD;
      wr_clk_en = 1;
      rd_clk_en = 1;
      error_count = 0;
      
      repeat(20) @(posedge wr_clk);
      rst <= 1'b0;
      wait_reset_complete();
      
      fork
        // Writer
        begin
          wr_idx = 0;
          while (wr_idx < count) begin
            @(posedge wr_clk);
            if (!full) begin
              wr_en <= 1'b1;
              wr_data <= wr_idx[DATA_WIDTH-1:0];
              wr_idx++;
            end else begin
              wr_en <= 1'b0;
            end
          end
          wr_en <= 1'b0;
        end
        // Reader with pause
        begin
          rd_idx = 0;
          repeat(5) @(posedge rd_clk);
          while (rd_idx < count) begin
            @(posedge rd_clk);
            if (!empty) begin
              rd_en <= 1'b1;
              @(posedge rd_clk);
              rd_en <= 1'b0;
              @(posedge rd_clk);
              read_val = rd_data;
              if (read_val !== rd_idx[DATA_WIDTH-1:0]) begin
                error_count++;
              end
              rd_idx++;
              
              // Pause read clock at 20
              if (rd_idx == 20) begin
                rd_clk_en = 0;
                #100000;  // 100ns pause
                rd_clk_en = 1;
              end
            end else begin
              rd_en <= 1'b0;
            end
          end
        end
      join
      
      $display("  Errors: %0d", error_count);
      `CHECK_EQUAL(error_count, 0);
      $display("  PASS: Read clock pause and resume");
    end

    `TEST_DONE;
  end

  `WATCHDOG(20000us);

endmodule
