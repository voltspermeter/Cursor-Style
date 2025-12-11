`timescale 1ps/1ps
`include "vunit_defines.svh"

module async_fifo_writepast_tb;

logic rst, wr_clk = 1'b0, rd_clk = 1'b0;
logic wr_allow, wr_allow_r, wr_expect, wr_expect_r, rd_allow, rd_allow_r;
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

always begin
  #10000;
  wr_clk <= !wr_clk;
end

async_fifo #(
      .DATA_WIDTH( 8 )
    , .ADDR_WIDTH( 4 )
    , .RESERVE( 8 )
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

assign rd_en = rd_allow_r & has_data;
assign wr_en = wr_allow_r;

always @(posedge wr_clk) begin
  wr_allow_r <= wr_allow;
  wr_expect_r <= wr_expect;
  if( rst ) begin
    wr_data <= 8'd0;
  end else if( wr_en ) begin
    $display( "Input data was %d  while %s", wr_data, full ? "FULL":"NOT full" );
    data_rec = wr_data;
    if(wr_expect_r) begin
      data_queue.push_back(data_rec);
    end
    write_count = write_count + 1;
    wr_data <= wr_data + 1;
  end
end

always @(posedge rd_clk) begin
  rd_en_d1 <= rd_en;
  rd_allow_r <= rd_allow;
  if( rd_en_d1 ) begin
    if( data_queue.size() == 0) begin
      $display( "NO DATA IN RECORD QUEUE" );
      `CHECK_EQUAL( 8'hXX, rd_data );
    end else begin
      data_rec_out = data_queue.pop_front();
      $display( "Output data was %d, %s", rd_data, data_rec_out == rd_data ? "MATCH" : "NO MATCH!!!!!!!" );
      `CHECK_EQUAL( data_rec_out, rd_data );
    end
  end
end

`TEST_SUITE begin

  `TEST_CASE("Write-Past") begin
    $dumpfile("test_case_1.vcd");
    $dumpvars();

    wr_allow <= 1'b0;
    rd_allow <= 1'b0;
    wr_expect <= 1'b0;

    rst <= 1'b1;
    repeat(20) begin
      @(posedge wr_clk);
    end
    rst <= 1'b0;
    repeat(20) begin
      @(posedge wr_clk);
    end


    $display( "----STARTING THE TESTBENCH-----" );
    wr_allow <= 1'b1;
    wr_expect <= 1'b1;
    repeat(16) begin
      @(posedge wr_clk);
    end
    wr_expect <= 1'b0;
    repeat(4) begin
      @(posedge wr_clk);
    end
    wr_allow <= 1'b0;

    repeat(20) begin
      @(posedge wr_clk);
    end
    rd_allow <= 1'b1;

    repeat(100) begin
      @(posedge wr_clk);
    end
    rd_allow <= 1'b0;

    wr_allow <= 1'b1;
    wr_expect <= 1'b1;
    repeat(16) begin
      @(posedge wr_clk);
    end
    wr_expect <= 1'b0;
    repeat(4) begin
      @(posedge wr_clk);
    end
    wr_allow <= 1'b0;

    repeat(20) begin
      @(posedge wr_clk);
    end
    rd_allow <= 1'b1;

    repeat(100) begin
      @(posedge wr_clk);
    end



    #(64'd5000000);
    `CHECK_EQUAL( 1'b1, 1'b1 );
  end

  `TEST_DONE;
end

`WATCHDOG(10000us);

endmodule
