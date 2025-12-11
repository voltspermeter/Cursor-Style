`timescale 1ps/1ps
`include "vunit_defines.svh"

//------------------------------------------------------------------------------
// Flag Consistency Test
//
// Verifies flag relationships are always consistent:
// - full=1 implies prog_full=1 (always)
// - prog_full=0 implies full=0 (always)
// - empty=1 implies has_data=0 (always)
// - has_data=1 implies empty=0 (always)
// - Never full=1 and empty=1 simultaneously (except during reset)
//------------------------------------------------------------------------------

module async_fifo_flag_consistency_tb;

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
  wire full, prog_full, empty, has_data;

  // Test tracking
  integer violation_count;
  integer sample_count;
  logic in_reset;

  // Clock generation
  always #10000 wr_clk <= !wr_clk;
  always #10500 rd_clk <= !rd_clk;

  // DUT instantiation
  async_fifo_flags #(
        .DATA_WIDTH(DATA_WIDTH)
      , .ADDR_WIDTH(ADDR_WIDTH)
      , .RESERVE(4)
  ) DUT (
        .rst(rst)
      , .wr_clk(wr_clk)
      , .wr_en(wr_en)
      , .wr_data(wr_data)
      , .full(full)
      , .prog_full(prog_full)
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

  // Check invariants
  task automatic check_invariants();
    // full=1 implies prog_full=1
    if (full && !prog_full && !in_reset) begin
      $display("  VIOLATION: full=1 but prog_full=0 at time %0t", $time);
      violation_count++;
    end
    
    // prog_full=0 implies full=0
    if (!prog_full && full && !in_reset) begin
      $display("  VIOLATION: prog_full=0 but full=1 at time %0t", $time);
      violation_count++;
    end
    
    // empty=1 implies has_data=0
    if (empty && has_data && !in_reset) begin
      $display("  VIOLATION: empty=1 but has_data=1 at time %0t", $time);
      violation_count++;
    end
    
    // has_data=1 implies empty=0
    if (has_data && empty && !in_reset) begin
      $display("  VIOLATION: has_data=1 but empty=1 at time %0t", $time);
      violation_count++;
    end
    
    // Never full=1 and empty=1 simultaneously (except reset)
    if (full && empty && !in_reset) begin
      $display("  VIOLATION: full=1 and empty=1 simultaneously at time %0t", $time);
      violation_count++;
    end
    
    sample_count++;
  endtask

  `TEST_SUITE begin

    //--------------------------------------------------------------------------
    // Test 1: Fill and empty with continuous monitoring
    //--------------------------------------------------------------------------
    `TEST_CASE("Fill-Empty-Monitor") begin
      $display("Testing: Flag invariants during fill and empty cycle");
      
      rst <= 1'b1;
      wr_en <= 1'b0;
      rd_en <= 1'b0;
      violation_count = 0;
      sample_count = 0;
      in_reset = 1;
      
      repeat(20) @(posedge wr_clk);
      rst <= 1'b0;
      wait_reset_complete();
      in_reset = 0;
      
      // Fill FIFO while monitoring
      for (int i = 0; i < DEPTH; i++) begin
        @(posedge wr_clk);
        check_invariants();
        wr_en <= 1'b1;
        wr_data <= i;
        @(posedge wr_clk);
        check_invariants();
        wr_en <= 1'b0;
      end
      
      repeat(10) @(posedge wr_clk);
      check_invariants();
      
      // Empty FIFO while monitoring
      repeat(5) @(posedge rd_clk);
      for (int i = 0; i < DEPTH; i++) begin
        while (empty) begin
          @(posedge rd_clk);
          check_invariants();
        end
        @(posedge rd_clk);
        check_invariants();
        rd_en <= 1'b1;
        @(posedge rd_clk);
        check_invariants();
        rd_en <= 1'b0;
      end
      
      repeat(10) @(posedge rd_clk);
      check_invariants();
      
      $display("  Samples checked: %0d, Violations: %0d", sample_count, violation_count);
      `CHECK_EQUAL(violation_count, 0);
      $display("  PASS: Fill/empty flag consistency");
    end

    //--------------------------------------------------------------------------
    // Test 2: Random operations with continuous monitoring
    //--------------------------------------------------------------------------
    `TEST_CASE("Random-Monitor") begin
      logic [15:0] lfsr = 16'hACE1;
      logic feedback;
      integer ops = 500;
      
      $display("Testing: Flag invariants during random operations");
      
      rst <= 1'b1;
      wr_en <= 1'b0;
      rd_en <= 1'b0;
      violation_count = 0;
      sample_count = 0;
      in_reset = 1;
      
      repeat(20) @(posedge wr_clk);
      rst <= 1'b0;
      wait_reset_complete();
      in_reset = 0;
      
      fork
        // Random writer
        begin
          for (int i = 0; i < ops; i++) begin
            @(posedge wr_clk);
            feedback = lfsr[15] ^ lfsr[14] ^ lfsr[12] ^ lfsr[3];
            lfsr = {lfsr[14:0], feedback};
            
            if (lfsr[0] && !full) begin
              wr_en <= 1'b1;
              wr_data <= lfsr[7:0];
            end else begin
              wr_en <= 1'b0;
            end
            check_invariants();
          end
          wr_en <= 1'b0;
        end
        // Random reader
        begin
          for (int i = 0; i < ops; i++) begin
            @(posedge rd_clk);
            feedback = lfsr[15] ^ lfsr[13] ^ lfsr[11] ^ lfsr[5];
            
            if (lfsr[1] && !empty) begin
              rd_en <= 1'b1;
            end else begin
              rd_en <= 1'b0;
            end
            check_invariants();
            
            @(posedge rd_clk);
            if (rd_en) begin
              rd_en <= 1'b0;
            end
          end
        end
      join
      
      $display("  Samples checked: %0d, Violations: %0d", sample_count, violation_count);
      `CHECK_EQUAL(violation_count, 0);
      $display("  PASS: Random operation flag consistency");
    end

    //--------------------------------------------------------------------------
    // Test 3: Boundary transitions
    //--------------------------------------------------------------------------
    `TEST_CASE("Boundary-Transitions") begin
      $display("Testing: Flag invariants at boundary transitions");
      
      rst <= 1'b1;
      wr_en <= 1'b0;
      rd_en <= 1'b0;
      violation_count = 0;
      sample_count = 0;
      in_reset = 1;
      
      repeat(20) @(posedge wr_clk);
      rst <= 1'b0;
      wait_reset_complete();
      in_reset = 0;
      
      // Repeat boundary transitions
      for (int cycle = 0; cycle < 5; cycle++) begin
        // Fill to near-full threshold
        while (!prog_full) begin
          @(posedge wr_clk);
          check_invariants();
          if (!full) begin
            wr_en <= 1'b1;
            wr_data <= cycle;
          end else begin
            wr_en <= 1'b0;
          end
        end
        wr_en <= 1'b0;
        
        // Check at prog_full boundary
        repeat(5) @(posedge wr_clk);
        check_invariants();
        
        // Continue to full
        while (!full) begin
          @(posedge wr_clk);
          check_invariants();
          wr_en <= 1'b1;
          wr_data <= cycle;
          @(posedge wr_clk);
          wr_en <= 1'b0;
        end
        
        // Check at full
        repeat(5) @(posedge wr_clk);
        check_invariants();
        
        // Empty to near-empty
        repeat(5) @(posedge rd_clk);
        while (!empty) begin
          @(posedge rd_clk);
          check_invariants();
          rd_en <= 1'b1;
          @(posedge rd_clk);
          rd_en <= 1'b0;
        end
        
        // Check at empty
        repeat(5) @(posedge rd_clk);
        check_invariants();
      end
      
      $display("  Samples checked: %0d, Violations: %0d", sample_count, violation_count);
      `CHECK_EQUAL(violation_count, 0);
      $display("  PASS: Boundary transition flag consistency");
    end

    //--------------------------------------------------------------------------
    // Test 4: Reset transitions
    //--------------------------------------------------------------------------
    `TEST_CASE("Reset-Transitions") begin
      $display("Testing: Flag invariants during reset transitions");
      
      rst <= 1'b1;
      wr_en <= 1'b0;
      rd_en <= 1'b0;
      violation_count = 0;
      sample_count = 0;
      in_reset = 1;
      
      repeat(20) @(posedge wr_clk);
      rst <= 1'b0;
      wait_reset_complete();
      in_reset = 0;
      
      // Fill partially
      for (int i = 0; i < DEPTH / 2; i++) begin
        @(posedge wr_clk);
        wr_en <= 1'b1;
        wr_data <= i;
        @(posedge wr_clk);
        wr_en <= 1'b0;
      end
      
      // Assert reset
      @(posedge wr_clk);
      rst <= 1'b1;
      in_reset = 1;
      
      repeat(10) @(posedge wr_clk);
      
      // Release reset
      rst <= 1'b0;
      wait_reset_complete();
      in_reset = 0;
      
      // Verify flags are consistent after reset
      check_invariants();
      $display("  After reset: full=%b, prog_full=%b, empty=%b, has_data=%b", 
               full, prog_full, empty, has_data);
      
      // empty should be 1, has_data should be 0
      `CHECK_EQUAL(empty, 1'b1);
      `CHECK_EQUAL(has_data, 1'b0);
      
      $display("  Samples checked: %0d, Violations: %0d", sample_count, violation_count);
      `CHECK_EQUAL(violation_count, 0);
      $display("  PASS: Reset transition flag consistency");
    end

    //--------------------------------------------------------------------------
    // Test 5: has_data vs empty always inverse
    //--------------------------------------------------------------------------
    `TEST_CASE("Has-Data-Empty-Inverse") begin
      $display("Testing: has_data is always inverse of empty");
      
      rst <= 1'b1;
      wr_en <= 1'b0;
      rd_en <= 1'b0;
      violation_count = 0;
      sample_count = 0;
      in_reset = 1;
      
      repeat(20) @(posedge wr_clk);
      rst <= 1'b0;
      wait_reset_complete();
      in_reset = 0;
      
      // Multiple fill/empty cycles checking has_data == ~empty
      for (int cycle = 0; cycle < 3; cycle++) begin
        // Fill
        for (int i = 0; i < DEPTH; i++) begin
          @(posedge wr_clk);
          wr_en <= 1'b1;
          wr_data <= i;
          @(posedge wr_clk);
          wr_en <= 1'b0;
          
          repeat(3) @(posedge rd_clk);
          if (has_data !== ~empty && !in_reset) begin
            $display("  VIOLATION: has_data=%b, empty=%b at time %0t", has_data, empty, $time);
            violation_count++;
          end
          sample_count++;
        end
        
        // Empty
        repeat(5) @(posedge rd_clk);
        while (!empty) begin
          @(posedge rd_clk);
          rd_en <= 1'b1;
          @(posedge rd_clk);
          rd_en <= 1'b0;
          
          @(posedge rd_clk);
          if (has_data !== ~empty && !in_reset) begin
            $display("  VIOLATION: has_data=%b, empty=%b at time %0t", has_data, empty, $time);
            violation_count++;
          end
          sample_count++;
        end
      end
      
      $display("  Samples checked: %0d, Violations: %0d", sample_count, violation_count);
      `CHECK_EQUAL(violation_count, 0);
      $display("  PASS: has_data always inverse of empty");
    end

    `TEST_DONE;
  end

  `WATCHDOG(5000us);

endmodule
