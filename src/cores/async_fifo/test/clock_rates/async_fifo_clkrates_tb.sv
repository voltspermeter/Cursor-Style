`timescale 1ps/1ps
`include "vunit_defines.svh"

module async_fifo_clkrates_tb;

logic rst, wr_clk = 1'b0, rd_clk = 1'b0, wr_allow, wr_allow_r;
wire  full, empty, has_data, rd_en, wr_en;
logic [7:0] wr_data;
wire  [7:0] rd_data;
reg         rd_en_d1;

logic [7:0] data_queue[$];
logic [7:0] data_rec;
logic [7:0] data_rec_out;

integer write_count = 0;

always begin
  #10000;
  rd_clk <= !rd_clk;
end

async_fifo_fwft #(
      .DATA_WIDTH( 8 )
    , .ADDR_WIDTH( 4 )
    , .RESERVE( 3 )
) DUT (   .rst      ( rst     )
        , .wr_clk   ( wr_clk  )
        , .wr_en    ( wr_en   )
        , .full     ( full    )
        , .wr_data  ( wr_data )

        , .rd_clk   ( rd_clk   )
        , .rd_en    ( rd_en    )
        , .empty    ( empty    )
        , .has_data ( has_data )
        , .rd_data  ( rd_data  )
);

assign rd_en = has_data;
assign wr_en = wr_allow_r & ~full;

always @(posedge wr_clk) begin
  wr_allow_r <= wr_allow;
  if( rst ) begin
    wr_data <= 8'd0;
  end else if( wr_en ) begin
    $display( "Input data was %d ", wr_data );
    data_rec = wr_data;
    data_queue.push_back(data_rec);
    write_count = write_count + 1;
    wr_data <= $urandom;
  end
end

always @(posedge rd_clk) begin
  rd_en_d1 <= rd_en;
  if( rd_en ) begin
    if( data_queue.size() == 0) begin
      $display( "NO DATA IN RECORD QUEUE" );
    end else begin
      data_rec_out = data_queue.pop_front();
      $display( "Output data was %d, %s", rd_data, data_rec_out == rd_data ? "MATCH" : "NO MATCH!!!!!!!" );
      `CHECK_EQUAL( data_rec_out, rd_data );
    end
  end
end

`TEST_SUITE begin

  `TEST_CASE("Multiple-clock-ratios") begin
    $dumpfile("test_case_1.vcd");
    $dumpvars();

    wr_allow <= 1'b0;
    wr_data <= 8'd0;
    wr_clk <= 1'b0;

    rst <= 1'b1;
    repeat(10) begin
      #6250;
      wr_clk <= !wr_clk;
    end
    rst <= 1'b0;
    while(DUT.FIFO_INST.rd_rst) begin
      #6250;
      wr_clk <= !wr_clk;
    end
    repeat(300) begin
      #6250;
      wr_clk <= !wr_clk;
    end
    wr_allow <= 1'b1;

    $display( "----STARTING THE TESTBENCH-----" );
    $display( "----- Read clock is 50 MHz -----" );
    $display( "----- Setting write clock to 80 MHz -----" );

    while( write_count < 200 ) begin
      #6250;
      wr_clk <= !wr_clk;
    end
    $display( "----- Setting write clock to 40.81 MHz -----" );
    while( write_count < 400 ) begin
      #12250;
      wr_clk <= !wr_clk;
    end
    $display( "----- Setting write clock to 199.92 MHz -----" );
    while( write_count < 600 ) begin
      #2501;
      wr_clk <= !wr_clk;
    end
    $display( "----- Setting write clock to 250 MHz -----" );
    while( write_count < 800 ) begin
        #2000;
        wr_clk <= !wr_clk;
    end
    $display( "----- Setting write clock to 50 MHz -----" );
    while( write_count < 1000 ) begin
        #10000;
        wr_clk <= !wr_clk;
    end

    wr_allow <= 1'b0;
    $display( "----- Flushing -----" );
    repeat( 100 ) begin
        #100000;
        wr_clk <= !wr_clk;
    end
    wr_allow <= 1'b1;
    $display( "----- Starting -----" );
    while( write_count < 2000 ) begin
        #1000;
        wr_clk <= !wr_clk;
    end
    wr_allow <= 1'b0;

    #(64'd500000);
    `CHECK_EQUAL( 1'b1, 1'b1 );
  end

  `TEST_DONE;
end

`WATCHDOG(10000us);

endmodule
