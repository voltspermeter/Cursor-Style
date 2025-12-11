//-----------------------------------------------------------------------------
//
// async_fifo_asymm_split_fwft.v - FIFO with separate clocks for read and
//                      write ports and asymmetric port sizes write port
//                                                               is wider
//                      First word fall through version
//
// Copyright (c) 2019 
//
// Contact: 
//
// ----------------------------------------------------------------------------

module async_fifo_asymm_split_fwft #(
    parameter WR_WIDTH_BYTES = 4,
    parameter WR_ADDR_WIDTH = 12,
    parameter WIDTH_RATIO_LOG2 = 2,
    parameter RESERVE = 12'd0
) (   input  rst
    , input  wr_clk
    , input  wr_en
    , output full
    , input  [8*WR_WIDTH_BYTES-1:0] wr_data

    , input  rd_clk
    , input  rd_en
    , output empty
    , output has_data
    , output [8*WR_WIDTH_BYTES/(2**WIDTH_RATIO_LOG2)-1:0] rd_data
);

  localparam WRITE_WIDTH = 8*WR_WIDTH_BYTES;
  localparam READ_WIDTH = WRITE_WIDTH/(2**WIDTH_RATIO_LOG2);
  localparam RD_ADDR_WIDTH = WR_ADDR_WIDTH+WIDTH_RATIO_LOG2;

  reg [WIDTH_RATIO_LOG2-1:0] read_count;
  wire rd_en_i;
  wire [WRITE_WIDTH-1:0] rd_data_i;

  async_fifo_fwft #(
        .DATA_WIDTH(WRITE_WIDTH)
      , .ADDR_WIDTH(WR_ADDR_WIDTH)
      , .RESERVE(RESERVE)
  ) FIFO_INST (
      .rst(rst)

      , .wr_clk(wr_clk)
      , .wr_en(wr_en)
      , .wr_data(wr_data)
      , .full(full)

      , .rd_clk(rd_clk)
      , .rd_en(rd_en_i)
      , .rd_data(rd_data_i)
      , .empty(empty)
      , .has_data(has_data)
  );

  reg [2:0] rd_rst_cnt;
  reg rd_rst;

  always @(posedge rd_clk or posedge rst) begin
    if (rst) begin
      rd_rst_cnt <= 3'd7;
      rd_rst <= 1'b1;
    end else begin
      if (|rd_rst_cnt) begin
        rd_rst_cnt <= rd_rst_cnt - 1'b1;
        rd_rst <= 1'b1;
      end else begin
        rd_rst <= 1'b0;
      end
    end
  end

  always @(posedge rd_clk) begin
    if(rd_rst) begin
      read_count <= {WIDTH_RATIO_LOG2{1'b0}};
    end else if(rd_en && has_data) begin
      read_count <= read_count + 1'b1;
    end
  end

  assign rd_en_i = (read_count == {WIDTH_RATIO_LOG2{1'b1}}) ? (rd_en && has_data) : 1'b0;
  assign rd_data = rd_data_i[read_count*READ_WIDTH +: READ_WIDTH];

endmodule
