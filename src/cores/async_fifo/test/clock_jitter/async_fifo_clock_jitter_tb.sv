`timescale 1ps/1ps
`include "vunit_defines.svh"

//------------------------------------------------------------------------------
// Clock Jitter Test
//
// Verifies operation with clock period variation (jitter):
// - ±5% period jitter on write clock
// - ±5% period jitter on read clock
// - Jitter on both clocks simultaneously
// - Verify no data corruption with jitter
//------------------------------------------------------------------------------

module async_fifo_clock_jitter_tb;

  // Parameters
  localparam DATA_WIDTH = 8;
  localparam ADDR_WIDTH = 4;
  localparam DEPTH = 2**ADDR_WIDTH;
  
  // Test parameters
  localparam TRANSACTIONS = 500;
  localparam BASE_PERIOD = 10000;  // 10ns base period
  localparam JITTER_PCT = 5;       // 5% jitter

  // Signals
  logic rst;
  logic wr_clk = 1'b0;
  logic rd_clk = 1'b0;
  logic wr_en;
  logic rd_en;
  logic [DATA_WIDTH-1:0] wr_data;
  wire [DATA_WIDTH-1:0] rd_data;
  wire full, empty, has_data;

  // LFSR for jitter
  logic [15:0] lfsr_wr_jitter = 16'hABCD;
  logic [15:0] lfsr_rd_jitter = 16'h1357;

  // Test tracking
  integer write_count;
  integer read_count;
  integer error_count;
  logic [DATA_WIDTH-1:0] expected;
  logic [DATA_WIDTH-1:0] read_val;
  
  // Jitter control
  logic enable_wr_jitter = 0;
  logic enable_rd_jitter = 0;
  integer wr_jitter_amount;
  integer rd_jitter_amount;

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

  // LFSR step for write jitter
  task automatic lfsr_step_wr_jitter();
    logic feedback;
    feedback = lfsr_wr_jitter[15] ^ lfsr_wr_jitter[14] ^ lfsr_wr_jitter[12] ^ lfsr_wr_jitter[3];
    lfsr_wr_jitter = {lfsr_wr_jitter[14:0], feedback};
  endtask

  // LFSR step for read jitter
  task automatic lfsr_step_rd_jitter();
    logic feedback;
    feedback = lfsr_rd_jitter[15] ^ lfsr_rd_jitter[14] ^ lfsr_rd_jitter[12] ^ lfsr_rd_jitter[3];
    lfsr_rd_jitter = {lfsr_rd_jitter[14:0], feedback};
  endtask

  // Calculate jitter amount (-5% to +5%)
  function automatic integer calc_jitter(input logic [15:0] lfsr);
    integer range;
    integer offset;
    range = (BASE_PERIOD * JITTER_PCT * 2) / 100;
    offset = (lfsr % (range + 1)) - (range / 2);
    return offset;
  endfunction

  // Write clock generation with jitter
  initial begin
    forever begin
      lfsr_step_wr_jitter();
      if (enable_wr_jitter)
        wr_jitter_amount = calc_jitter(lfsr_wr_jitter);
      else
        wr_jitter_amount = 0;
      #(BASE_PERIOD + wr_jitter_amount) wr_clk = !wr_clk;
    end
  end

  // Read clock generation with jitter
  initial begin
    forever begin
      lfsr_step_rd_jitter();
      if (enable_rd_jitter)
        rd_jitter_amount = calc_jitter(lfsr_rd_jitter);
      else
        rd_jitter_amount = 0;
      #(BASE_PERIOD + 500 + rd_jitter_amount) rd_clk = !rd_clk;  // Slightly different base
    end
  end

  // Helper task: Wait for reset complete
  task automatic wait_reset_complete();
    while (DUT.wr_rst || DUT.rd_rst) @(posedge wr_clk);
    repeat(5) @(posedge wr_clk);
  endtask

  // Helper task: Transfer data with verification
  task automatic transfer_and_verify(input integer count, output integer errors);
    integer wr_idx, rd_idx;
    logic [DATA_WIDTH-1:0] rd_val;
    
    errors = 0;
    wr_idx = 0;
    rd_idx = 0;
    
    fork
      // Writer
      begin
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
      // Reader
      begin
        repeat(5) @(posedge rd_clk);
        while (rd_idx < count) begin
          @(posedge rd_clk);
          if (!empty) begin
            rd_en <= 1'b1;
            @(posedge rd_clk);
            rd_en <= 1'b0;
            @(posedge rd_clk);
            rd_val = rd_data;
            if (rd_val !== rd_idx[DATA_WIDTH-1:0]) begin
              errors++;
            end
            rd_idx++;
          end else begin
            rd_en <= 1'b0;
          end
        end
      end
    join
  endtask

  `TEST_SUITE begin

    //--------------------------------------------------------------------------
    // Test 1: Write clock jitter only
    //--------------------------------------------------------------------------
    `TEST_CASE("Write-Clock-Jitter") begin
      $display("Testing: ±%0d%% jitter on write clock only", JITTER_PCT);
      $display("  Transactions: %0d", TRANSACTIONS);
      
      rst <= 1'b1;
      wr_en <= 1'b0;
      rd_en <= 1'b0;
      enable_wr_jitter = 0;
      enable_rd_jitter = 0;
      
      repeat(20) @(posedge wr_clk);
      rst <= 1'b0;
      wait_reset_complete();
      
      // Enable write clock jitter
      enable_wr_jitter = 1;
      
      transfer_and_verify(TRANSACTIONS, error_count);
      
      enable_wr_jitter = 0;
      
      $display("  Errors: %0d", error_count);
      `CHECK_EQUAL(error_count, 0);
      $display("  PASS: Write clock jitter");
    end

    //--------------------------------------------------------------------------
    // Test 2: Read clock jitter only
    //--------------------------------------------------------------------------
    `TEST_CASE("Read-Clock-Jitter") begin
      $display("Testing: ±%0d%% jitter on read clock only", JITTER_PCT);
      
      rst <= 1'b1;
      wr_en <= 1'b0;
      rd_en <= 1'b0;
      enable_wr_jitter = 0;
      enable_rd_jitter = 0;
      lfsr_wr_jitter = 16'h2468;
      lfsr_rd_jitter = 16'h9ABC;
      
      repeat(20) @(posedge wr_clk);
      rst <= 1'b0;
      wait_reset_complete();
      
      // Enable read clock jitter
      enable_rd_jitter = 1;
      
      transfer_and_verify(TRANSACTIONS, error_count);
      
      enable_rd_jitter = 0;
      
      $display("  Errors: %0d", error_count);
      `CHECK_EQUAL(error_count, 0);
      $display("  PASS: Read clock jitter");
    end

    //--------------------------------------------------------------------------
    // Test 3: Both clocks with jitter
    //--------------------------------------------------------------------------
    `TEST_CASE("Both-Clocks-Jitter") begin
      $display("Testing: ±%0d%% jitter on both clocks", JITTER_PCT);
      
      rst <= 1'b1;
      wr_en <= 1'b0;
      rd_en <= 1'b0;
      enable_wr_jitter = 0;
      enable_rd_jitter = 0;
      lfsr_wr_jitter = 16'hFEDC;
      lfsr_rd_jitter = 16'h3210;
      
      repeat(20) @(posedge wr_clk);
      rst <= 1'b0;
      wait_reset_complete();
      
      // Enable both jitters
      enable_wr_jitter = 1;
      enable_rd_jitter = 1;
      
      transfer_and_verify(TRANSACTIONS, error_count);
      
      enable_wr_jitter = 0;
      enable_rd_jitter = 0;
      
      $display("  Errors: %0d", error_count);
      `CHECK_EQUAL(error_count, 0);
      $display("  PASS: Both clocks jitter");
    end

    //--------------------------------------------------------------------------
    // Test 4: Jitter with full/empty transitions
    //--------------------------------------------------------------------------
    `TEST_CASE("Jitter-Full-Empty") begin
      integer wr_idx, rd_idx;
      
      $display("Testing: Jitter during full/empty transitions");
      
      rst <= 1'b1;
      wr_en <= 1'b0;
      rd_en <= 1'b0;
      enable_wr_jitter = 0;
      enable_rd_jitter = 0;
      lfsr_wr_jitter = 16'h1111;
      lfsr_rd_jitter = 16'h2222;
      error_count = 0;
      
      repeat(20) @(posedge wr_clk);
      rst <= 1'b0;
      wait_reset_complete();
      
      enable_wr_jitter = 1;
      enable_rd_jitter = 1;
      
      // Cycle through full and empty multiple times
      for (int cycle = 0; cycle < 10; cycle++) begin
        // Fill to full
        wr_idx = 0;
        while (!full) begin
          @(posedge wr_clk);
          if (!full) begin
            wr_en <= 1'b1;
            wr_data <= wr_idx[DATA_WIDTH-1:0];
            wr_idx++;
          end
        end
        wr_en <= 1'b0;
        
        // Empty completely
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
      end
      
      enable_wr_jitter = 0;
      enable_rd_jitter = 0;
      
      $display("  Errors: %0d", error_count);
      `CHECK_EQUAL(error_count, 0);
      $display("  PASS: Jitter during full/empty transitions");
    end

    `TEST_DONE;
  end

  `WATCHDOG(30000us);

endmodule
