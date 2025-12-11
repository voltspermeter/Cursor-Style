//-----------------------------------------------------------------------------
//
// async_fifo_asymm_concat_fwft.v - FIFO with separate clocks for read and
//                      write ports and asymmetric port sizes read port is
//                                                                      wider
//                      First word fall through version
//
// Copyright (c) 2019 
//
// Contact: 
//
// ----------------------------------------------------------------------------

module async_fifo_asymm_concat_fwft #(
    parameter WR_WIDTH_BYTES = 1,
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
    , output [8*WR_WIDTH_BYTES*(2**WIDTH_RATIO_LOG2)-1:0] rd_data
);

  localparam WRITE_WIDTH = 8*WR_WIDTH_BYTES;
  localparam READ_WIDTH = WRITE_WIDTH*(2**WIDTH_RATIO_LOG2);
  localparam RD_ADDR_WIDTH = WR_ADDR_WIDTH-WIDTH_RATIO_LOG2;
  localparam RD_RESERVE = RESERVE/(2**WIDTH_RATIO_LOG2);

  reg [WIDTH_RATIO_LOG2-1:0] write_cnt;
  reg [READ_WIDTH-1:0] wr_data_r;
  wire [READ_WIDTH-1:0] wr_data_i;
  wire wr_en_i;

  reg [2:0] wr_rst_cnt;
  reg wr_rst;

  always @(posedge wr_clk or posedge rst) begin
    if (rst) begin
      wr_rst_cnt <= 3'd7;
      wr_rst <= 1'b1;
    end else begin
      if (|wr_rst_cnt) begin
        wr_rst_cnt <= wr_rst_cnt - 1'b1;
        wr_rst <= 1'b1;
      end else begin
        wr_rst <= 1'b0;
      end
    end
  end

  always @(posedge wr_clk) begin
    if(wr_rst) begin
      write_cnt <= {WIDTH_RATIO_LOG2{1'b0}};
    end else if(wr_en) begin
      write_cnt <= write_cnt + 1'b1;
      wr_data_r <= {wr_data, wr_data_r[READ_WIDTH-1:WRITE_WIDTH]};
    end
  end

  assign wr_en_i = (write_cnt=={WIDTH_RATIO_LOG2{1'b1}}) ? (wr_en) : 1'b0;
  assign wr_data_i = {wr_data, wr_data_r[READ_WIDTH-1:WRITE_WIDTH]};

  async_fifo_fwft #(
        .DATA_WIDTH(READ_WIDTH)
      , .ADDR_WIDTH(RD_ADDR_WIDTH)
      , .RESERVE(RD_RESERVE)
  ) FIFO_INST (
      .rst(rst)

      , .wr_clk(wr_clk)
      , .wr_en(wr_en_i)
      , .wr_data(wr_data_i)
      , .full(full)

      , .rd_clk(rd_clk)
      , .rd_en(rd_en)
      , .rd_data(rd_data)
      , .empty(empty)
      , .has_data(has_data)
  );


endmodule
