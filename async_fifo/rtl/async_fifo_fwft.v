//-----------------------------------------------------------------------------
//
// async_fifo_fwft.v - FIFO with separate clocks for read and write ports
//                      First word fall through version
//
// Copyright (c) 2019 
//
// Contact: 
//
// ----------------------------------------------------------------------------

module async_fifo_fwft #(
    parameter DATA_WIDTH = 8,
    parameter ADDR_WIDTH = 12,
    parameter RESERVE = 12'd0
) (   input  rst
    , input  wr_clk
    , input  wr_en
    , output full
    , input  [DATA_WIDTH-1:0] wr_data

    , input  rd_clk
    , input  rd_en
    , output empty
    , output has_data
    , output [DATA_WIDTH-1:0] rd_data
);

  wire                  rd_en_i;
  reg                   rd_en_i_d1;
  wire [DATA_WIDTH-1:0] rd_data_i;
  wire                  empty_i;
  wire                  has_data_i;
  reg                   data_in_reg;

  async_fifo #(
        .DATA_WIDTH(DATA_WIDTH)
      , .ADDR_WIDTH(ADDR_WIDTH)
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
      , .empty(empty_i)
      , .has_data(has_data_i)
  );

  assign rd_en_i =  (has_data_i & ~data_in_reg)
                  | (has_data_i & rd_en);

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
      data_in_reg <= 1'b0;
    end else begin
      if (rd_en) begin
        data_in_reg <= has_data_i;
      end else if (rd_en_i) begin
        data_in_reg <= 1'b1;
      end
    end
  end

  assign has_data = data_in_reg;
  assign empty = ~data_in_reg;

  assign rd_data = rd_data_i;

endmodule
