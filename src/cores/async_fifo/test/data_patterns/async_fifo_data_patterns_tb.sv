`timescale 1ps/1ps
`include "vunit_defines.svh"

//------------------------------------------------------------------------------
// Data Pattern Test
//
// Verifies data integrity with various bit patterns:
// - All zeros, all ones
// - Alternating bits
// - Walking ones/zeros
// - Sequential count
// - Pseudo-random (LFSR)
//------------------------------------------------------------------------------

module async_fifo_data_patterns_tb;

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

  // Test data
  logic [DATA_WIDTH-1:0] test_pattern;
  logic [DATA_WIDTH-1:0] read_val;
  integer pattern_count;

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

  // Helper task: Write and verify pattern
  task automatic write_and_verify_pattern(input [DATA_WIDTH-1:0] pattern);
    // Write pattern
    @(posedge wr_clk);
    wr_en <= 1'b1;
    wr_data <= pattern;
    @(posedge wr_clk);
    wr_en <= 1'b0;
    
    // Wait for data
    repeat(5) @(posedge rd_clk);
    while (empty) @(posedge rd_clk);
    
    // Read and verify
    @(posedge rd_clk);
    rd_en <= 1'b1;
    @(posedge rd_clk);
    rd_en <= 1'b0;
    @(posedge rd_clk);
    read_val = rd_data;
    `CHECK_EQUAL(read_val, pattern);
  endtask

  // Helper task: Write batch then read and verify
  task automatic batch_write_verify(input [DATA_WIDTH-1:0] patterns[], input int count);
    // Write all patterns
    for (int i = 0; i < count; i++) begin
      @(posedge wr_clk);
      while (full) @(posedge wr_clk);
      wr_en <= 1'b1;
      wr_data <= patterns[i];
      @(posedge wr_clk);
      wr_en <= 1'b0;
    end
    
    // Wait for data to propagate
    repeat(10) @(posedge rd_clk);
    
    // Read and verify all
    for (int i = 0; i < count; i++) begin
      while (empty) @(posedge rd_clk);
      @(posedge rd_clk);
      rd_en <= 1'b1;
      @(posedge rd_clk);
      rd_en <= 1'b0;
      @(posedge rd_clk);
      read_val = rd_data;
      `CHECK_EQUAL(read_val, patterns[i]);
    end
  endtask

  `TEST_SUITE begin

    //--------------------------------------------------------------------------
    // Test 1: All zeros pattern
    //--------------------------------------------------------------------------
    `TEST_CASE("All-Zeros") begin
      $display("Testing: All zeros pattern (0x00)");
      
      rst <= 1'b1;
      wr_en <= 1'b0;
      rd_en <= 1'b0;
      
      repeat(20) @(posedge wr_clk);
      rst <= 1'b0;
      wait_reset_complete();
      
      // Write and verify multiple times
      for (int i = 0; i < 10; i++) begin
        write_and_verify_pattern(8'h00);
      end
      
      $display("  PASS: All zeros pattern");
    end

    //--------------------------------------------------------------------------
    // Test 2: All ones pattern
    //--------------------------------------------------------------------------
    `TEST_CASE("All-Ones") begin
      $display("Testing: All ones pattern (0xFF)");
      
      rst <= 1'b1;
      wr_en <= 1'b0;
      rd_en <= 1'b0;
      
      repeat(20) @(posedge wr_clk);
      rst <= 1'b0;
      wait_reset_complete();
      
      for (int i = 0; i < 10; i++) begin
        write_and_verify_pattern(8'hFF);
      end
      
      $display("  PASS: All ones pattern");
    end

    //--------------------------------------------------------------------------
    // Test 3: Alternating bits
    //--------------------------------------------------------------------------
    `TEST_CASE("Alternating-Bits") begin
      $display("Testing: Alternating bits (0xAA, 0x55)");
      
      rst <= 1'b1;
      wr_en <= 1'b0;
      rd_en <= 1'b0;
      
      repeat(20) @(posedge wr_clk);
      rst <= 1'b0;
      wait_reset_complete();
      
      for (int i = 0; i < 10; i++) begin
        write_and_verify_pattern(8'hAA);
        write_and_verify_pattern(8'h55);
      end
      
      $display("  PASS: Alternating bits pattern");
    end

    //--------------------------------------------------------------------------
    // Test 4: Walking ones
    //--------------------------------------------------------------------------
    `TEST_CASE("Walking-Ones") begin
      $display("Testing: Walking ones pattern");
      
      rst <= 1'b1;
      wr_en <= 1'b0;
      rd_en <= 1'b0;
      
      repeat(20) @(posedge wr_clk);
      rst <= 1'b0;
      wait_reset_complete();
      
      // Walk a single 1 bit through all positions
      for (int round = 0; round < 2; round++) begin
        for (int bitpos = 0; bitpos < DATA_WIDTH; bitpos++) begin
          test_pattern = (1 << bitpos);
          write_and_verify_pattern(test_pattern);
        end
      end
      
      $display("  PASS: Walking ones pattern");
    end

    //--------------------------------------------------------------------------
    // Test 5: Walking zeros
    //--------------------------------------------------------------------------
    `TEST_CASE("Walking-Zeros") begin
      $display("Testing: Walking zeros pattern");
      
      rst <= 1'b1;
      wr_en <= 1'b0;
      rd_en <= 1'b0;
      
      repeat(20) @(posedge wr_clk);
      rst <= 1'b0;
      wait_reset_complete();
      
      // Walk a single 0 bit through all positions
      for (int round = 0; round < 2; round++) begin
        for (int bitpos = 0; bitpos < DATA_WIDTH; bitpos++) begin
          test_pattern = ~(1 << bitpos);
          write_and_verify_pattern(test_pattern);
        end
      end
      
      $display("  PASS: Walking zeros pattern");
    end

    //--------------------------------------------------------------------------
    // Test 6: Sequential count
    //--------------------------------------------------------------------------
    `TEST_CASE("Sequential-Count") begin
      $display("Testing: Sequential count pattern");
      
      rst <= 1'b1;
      wr_en <= 1'b0;
      rd_en <= 1'b0;
      
      repeat(20) @(posedge wr_clk);
      rst <= 1'b0;
      wait_reset_complete();
      
      // Write sequential values 0-255
      pattern_count = 0;
      for (int batch = 0; batch < 16; batch++) begin
        // Write a batch
        for (int i = 0; i < DEPTH; i++) begin
          @(posedge wr_clk);
          while (full) @(posedge wr_clk);
          wr_en <= 1'b1;
          wr_data <= pattern_count;
          @(posedge wr_clk);
          wr_en <= 1'b0;
          pattern_count++;
          if (pattern_count >= 256) pattern_count = 0;
        end
        
        // Read and verify batch
        repeat(5) @(posedge rd_clk);
        for (int i = 0; i < DEPTH; i++) begin
          while (empty) @(posedge rd_clk);
          @(posedge rd_clk);
          rd_en <= 1'b1;
          @(posedge rd_clk);
          rd_en <= 1'b0;
          @(posedge rd_clk);
          read_val = rd_data;
          `CHECK_EQUAL(read_val, (batch * DEPTH + i) & 8'hFF);
        end
      end
      
      $display("  PASS: Sequential count pattern");
    end

    //--------------------------------------------------------------------------
    // Test 7: Pseudo-random (LFSR)
    //--------------------------------------------------------------------------
    `TEST_CASE("LFSR-Random") begin
      logic [DATA_WIDTH-1:0] lfsr_wr, lfsr_rd;
      logic feedback;
      integer num_values = 100;
      
      $display("Testing: LFSR pseudo-random pattern");
      
      rst <= 1'b1;
      wr_en <= 1'b0;
      rd_en <= 1'b0;
      
      repeat(20) @(posedge wr_clk);
      rst <= 1'b0;
      wait_reset_complete();
      
      // Initialize LFSR with non-zero seed
      lfsr_wr = 8'hA5;
      lfsr_rd = 8'hA5;
      
      // Write LFSR values
      for (int i = 0; i < num_values; i++) begin
        @(posedge wr_clk);
        while (full) @(posedge wr_clk);
        wr_en <= 1'b1;
        wr_data <= lfsr_wr;
        @(posedge wr_clk);
        wr_en <= 1'b0;
        
        // LFSR feedback: x^8 + x^6 + x^5 + x^4 + 1
        feedback = lfsr_wr[7] ^ lfsr_wr[5] ^ lfsr_wr[4] ^ lfsr_wr[3];
        lfsr_wr = {lfsr_wr[6:0], feedback};
      end
      
      // Read and verify using same LFSR sequence
      repeat(10) @(posedge rd_clk);
      for (int i = 0; i < num_values; i++) begin
        while (empty) @(posedge rd_clk);
        @(posedge rd_clk);
        rd_en <= 1'b1;
        @(posedge rd_clk);
        rd_en <= 1'b0;
        @(posedge rd_clk);
        read_val = rd_data;
        `CHECK_EQUAL(read_val, lfsr_rd);
        
        // Advance read LFSR
        feedback = lfsr_rd[7] ^ lfsr_rd[5] ^ lfsr_rd[4] ^ lfsr_rd[3];
        lfsr_rd = {lfsr_rd[6:0], feedback};
      end
      
      $display("  PASS: LFSR random pattern");
    end

    //--------------------------------------------------------------------------
    // Test 8: Boundary patterns
    //--------------------------------------------------------------------------
    `TEST_CASE("Boundary-Patterns") begin
      $display("Testing: Boundary value patterns");
      
      rst <= 1'b1;
      wr_en <= 1'b0;
      rd_en <= 1'b0;
      
      repeat(20) @(posedge wr_clk);
      rst <= 1'b0;
      wait_reset_complete();
      
      // Test boundary values
      write_and_verify_pattern(8'h00);  // Min
      write_and_verify_pattern(8'hFF);  // Max
      write_and_verify_pattern(8'h01);  // Min + 1
      write_and_verify_pattern(8'hFE);  // Max - 1
      write_and_verify_pattern(8'h7F);  // Mid - 1
      write_and_verify_pattern(8'h80);  // Mid
      write_and_verify_pattern(8'h81);  // Mid + 1
      
      $display("  PASS: Boundary patterns");
    end

    `TEST_DONE;
  end

  `WATCHDOG(2000us);

endmodule
