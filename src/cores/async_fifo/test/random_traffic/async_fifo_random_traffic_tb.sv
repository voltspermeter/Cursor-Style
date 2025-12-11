`timescale 1ps/1ps
`include "vunit_defines.svh"

//------------------------------------------------------------------------------
// Random Traffic Test
//
// Long-running test with randomized operations:
// - Random write enable (with probability P_write)
// - Random read enable (with probability P_read)
// - Random data patterns
// - Multiple configurations
//------------------------------------------------------------------------------

module async_fifo_random_traffic_tb;

  // Parameters
  localparam DATA_WIDTH = 8;
  localparam ADDR_WIDTH = 4;
  localparam DEPTH = 2**ADDR_WIDTH;
  
  // Test parameters - number of transactions
  localparam TRANSACTIONS = 5000;  // Reduced for simulation time

  // Signals
  logic rst;
  logic wr_clk = 1'b0;
  logic rd_clk = 1'b0;
  logic wr_en;
  logic rd_en;
  logic [DATA_WIDTH-1:0] wr_data;
  wire [DATA_WIDTH-1:0] rd_data;
  wire full, empty, has_data;

  // LFSR for pseudo-random generation
  logic [15:0] lfsr_wr = 16'hACE1;
  logic [15:0] lfsr_rd = 16'h5A5A;
  logic [15:0] lfsr_data = 16'h1234;

  // Test tracking
  logic [DATA_WIDTH-1:0] expected_queue[0:DEPTH];
  integer queue_head;
  integer queue_tail;
  integer queue_count;
  
  integer write_count;
  integer read_count;
  integer error_count;
  logic [DATA_WIDTH-1:0] read_val;

  // Clock generation - slightly different periods for CDC stress
  always #10000 wr_clk <= !wr_clk;
  always #10500 rd_clk <= !rd_clk;

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

  // LFSR update tasks
  task automatic lfsr_step_wr();
    logic feedback;
    feedback = lfsr_wr[15] ^ lfsr_wr[14] ^ lfsr_wr[12] ^ lfsr_wr[3];
    lfsr_wr <= {lfsr_wr[14:0], feedback};
  endtask

  task automatic lfsr_step_rd();
    logic feedback;
    feedback = lfsr_rd[15] ^ lfsr_rd[14] ^ lfsr_rd[12] ^ lfsr_rd[3];
    lfsr_rd <= {lfsr_rd[14:0], feedback};
  endtask

  task automatic lfsr_step_data();
    logic feedback;
    feedback = lfsr_data[15] ^ lfsr_data[14] ^ lfsr_data[12] ^ lfsr_data[3];
    lfsr_data <= {lfsr_data[14:0], feedback};
  endtask

  // Queue management
  task automatic queue_init();
    queue_head = 0;
    queue_tail = 0;
    queue_count = 0;
  endtask

  task automatic queue_push(input logic [DATA_WIDTH-1:0] data);
    expected_queue[queue_tail] = data;
    queue_tail = (queue_tail + 1) % (DEPTH + 1);
    queue_count++;
  endtask

  function automatic logic [DATA_WIDTH-1:0] queue_pop();
    logic [DATA_WIDTH-1:0] data;
    data = expected_queue[queue_head];
    queue_head = (queue_head + 1) % (DEPTH + 1);
    queue_count--;
    return data;
  endfunction

  // Helper task: Wait for reset complete
  task automatic wait_reset_complete();
    while (DUT.wr_rst || DUT.rd_rst) @(posedge wr_clk);
    repeat(5) @(posedge wr_clk);
  endtask

  `TEST_SUITE begin

    //--------------------------------------------------------------------------
    // Test 1: Balanced random traffic (P=0.5, P=0.5)
    //--------------------------------------------------------------------------
    `TEST_CASE("Random-Balanced") begin
      integer threshold = 32768;  // 50% probability (0-65535)
      
      $display("Testing: Balanced random traffic (P_wr=0.5, P_rd=0.5)");
      $display("  Transactions: %0d", TRANSACTIONS);
      
      rst <= 1'b1;
      wr_en <= 1'b0;
      rd_en <= 1'b0;
      write_count = 0;
      read_count = 0;
      error_count = 0;
      queue_init();
      
      repeat(20) @(posedge wr_clk);
      rst <= 1'b0;
      wait_reset_complete();
      
      fork
        // Writer
        begin
          while (write_count < TRANSACTIONS) begin
            @(posedge wr_clk);
            lfsr_step_wr();
            lfsr_step_data();
            
            if (lfsr_wr < threshold && !full) begin
              wr_en <= 1'b1;
              wr_data <= lfsr_data[DATA_WIDTH-1:0];
              queue_push(lfsr_data[DATA_WIDTH-1:0]);
              write_count++;
            end else begin
              wr_en <= 1'b0;
            end
          end
          wr_en <= 1'b0;
        end
        // Reader
        begin
          repeat(5) @(posedge rd_clk);
          while (read_count < TRANSACTIONS) begin
            @(posedge rd_clk);
            lfsr_step_rd();
            
            if (lfsr_rd < threshold && !empty) begin
              rd_en <= 1'b1;
            end else begin
              rd_en <= 1'b0;
            end
            
            @(posedge rd_clk);
            if (rd_en) begin
              rd_en <= 1'b0;
              @(posedge rd_clk);
              read_val = rd_data;
              if (queue_count > 0) begin
                if (read_val !== queue_pop()) begin
                  error_count++;
                  if (error_count <= 5) $display("  ERROR at read %0d", read_count);
                end
              end
              read_count++;
            end
          end
        end
      join
      
      $display("  Writes: %0d, Reads: %0d, Errors: %0d", write_count, read_count, error_count);
      `CHECK_EQUAL(error_count, 0);
      $display("  PASS: Balanced random traffic");
    end

    //--------------------------------------------------------------------------
    // Test 2: Write-heavy random traffic (P=0.8, P=0.5)
    //--------------------------------------------------------------------------
    `TEST_CASE("Random-Write-Heavy") begin
      integer wr_threshold = 52428;  // ~80% probability
      integer rd_threshold = 32768;  // 50% probability
      
      $display("Testing: Write-heavy random traffic (P_wr=0.8, P_rd=0.5)");
      
      rst <= 1'b1;
      wr_en <= 1'b0;
      rd_en <= 1'b0;
      write_count = 0;
      read_count = 0;
      error_count = 0;
      queue_init();
      lfsr_wr = 16'hBEEF;
      lfsr_rd = 16'hCAFE;
      lfsr_data = 16'hDEAD;
      
      repeat(20) @(posedge wr_clk);
      rst <= 1'b0;
      wait_reset_complete();
      
      fork
        // Writer
        begin
          while (write_count < TRANSACTIONS) begin
            @(posedge wr_clk);
            lfsr_step_wr();
            lfsr_step_data();
            
            if (lfsr_wr < wr_threshold && !full) begin
              wr_en <= 1'b1;
              wr_data <= lfsr_data[DATA_WIDTH-1:0];
              queue_push(lfsr_data[DATA_WIDTH-1:0]);
              write_count++;
            end else begin
              wr_en <= 1'b0;
            end
          end
          wr_en <= 1'b0;
        end
        // Reader
        begin
          repeat(5) @(posedge rd_clk);
          while (read_count < TRANSACTIONS) begin
            @(posedge rd_clk);
            lfsr_step_rd();
            
            if (lfsr_rd < rd_threshold && !empty) begin
              rd_en <= 1'b1;
            end else begin
              rd_en <= 1'b0;
            end
            
            @(posedge rd_clk);
            if (rd_en) begin
              rd_en <= 1'b0;
              @(posedge rd_clk);
              read_val = rd_data;
              if (queue_count > 0) begin
                if (read_val !== queue_pop()) begin
                  error_count++;
                end
              end
              read_count++;
            end
          end
        end
      join
      
      $display("  Writes: %0d, Reads: %0d, Errors: %0d", write_count, read_count, error_count);
      `CHECK_EQUAL(error_count, 0);
      $display("  PASS: Write-heavy random traffic");
    end

    //--------------------------------------------------------------------------
    // Test 3: Read-heavy random traffic (P=0.5, P=0.8)
    //--------------------------------------------------------------------------
    `TEST_CASE("Random-Read-Heavy") begin
      integer wr_threshold = 32768;  // 50% probability
      integer rd_threshold = 52428;  // ~80% probability
      
      $display("Testing: Read-heavy random traffic (P_wr=0.5, P_rd=0.8)");
      
      rst <= 1'b1;
      wr_en <= 1'b0;
      rd_en <= 1'b0;
      write_count = 0;
      read_count = 0;
      error_count = 0;
      queue_init();
      lfsr_wr = 16'hF00D;
      lfsr_rd = 16'hBABE;
      lfsr_data = 16'hFACE;
      
      repeat(20) @(posedge wr_clk);
      rst <= 1'b0;
      wait_reset_complete();
      
      fork
        // Writer
        begin
          while (write_count < TRANSACTIONS) begin
            @(posedge wr_clk);
            lfsr_step_wr();
            lfsr_step_data();
            
            if (lfsr_wr < wr_threshold && !full) begin
              wr_en <= 1'b1;
              wr_data <= lfsr_data[DATA_WIDTH-1:0];
              queue_push(lfsr_data[DATA_WIDTH-1:0]);
              write_count++;
            end else begin
              wr_en <= 1'b0;
            end
          end
          wr_en <= 1'b0;
        end
        // Reader
        begin
          repeat(5) @(posedge rd_clk);
          while (read_count < TRANSACTIONS) begin
            @(posedge rd_clk);
            lfsr_step_rd();
            
            if (lfsr_rd < rd_threshold && !empty) begin
              rd_en <= 1'b1;
            end else begin
              rd_en <= 1'b0;
            end
            
            @(posedge rd_clk);
            if (rd_en) begin
              rd_en <= 1'b0;
              @(posedge rd_clk);
              read_val = rd_data;
              if (queue_count > 0) begin
                if (read_val !== queue_pop()) begin
                  error_count++;
                end
              end
              read_count++;
            end
          end
        end
      join
      
      $display("  Writes: %0d, Reads: %0d, Errors: %0d", write_count, read_count, error_count);
      `CHECK_EQUAL(error_count, 0);
      $display("  PASS: Read-heavy random traffic");
    end

    //--------------------------------------------------------------------------
    // Test 4: Maximum throughput (P=1.0, P=1.0)
    //--------------------------------------------------------------------------
    `TEST_CASE("Random-Max-Throughput") begin
      $display("Testing: Maximum throughput (continuous read/write)");
      
      rst <= 1'b1;
      wr_en <= 1'b0;
      rd_en <= 1'b0;
      write_count = 0;
      read_count = 0;
      error_count = 0;
      queue_init();
      lfsr_data = 16'h9999;
      
      repeat(20) @(posedge wr_clk);
      rst <= 1'b0;
      wait_reset_complete();
      
      fork
        // Writer - continuous when not full
        begin
          while (write_count < TRANSACTIONS) begin
            @(posedge wr_clk);
            lfsr_step_data();
            
            if (!full) begin
              wr_en <= 1'b1;
              wr_data <= lfsr_data[DATA_WIDTH-1:0];
              queue_push(lfsr_data[DATA_WIDTH-1:0]);
              write_count++;
            end else begin
              wr_en <= 1'b0;
            end
          end
          wr_en <= 1'b0;
        end
        // Reader - continuous when not empty
        begin
          repeat(5) @(posedge rd_clk);
          while (read_count < TRANSACTIONS) begin
            @(posedge rd_clk);
            
            if (!empty) begin
              rd_en <= 1'b1;
            end else begin
              rd_en <= 1'b0;
            end
            
            @(posedge rd_clk);
            if (rd_en) begin
              rd_en <= 1'b0;
              @(posedge rd_clk);
              read_val = rd_data;
              if (queue_count > 0) begin
                if (read_val !== queue_pop()) begin
                  error_count++;
                end
              end
              read_count++;
            end
          end
        end
      join
      
      $display("  Writes: %0d, Reads: %0d, Errors: %0d", write_count, read_count, error_count);
      `CHECK_EQUAL(error_count, 0);
      $display("  PASS: Maximum throughput");
    end

    `TEST_DONE;
  end

  `WATCHDOG(50000us);

endmodule
