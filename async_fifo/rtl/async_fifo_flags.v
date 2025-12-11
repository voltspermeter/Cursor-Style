//-----------------------------------------------------------------------------
//
// async_fifo_flags_.v - FIFO with separate clocks for read and write ports
//                        Programmable full and true full both exposed
//
// Copyright (c) 2019 
//
// Contact: 
//
// ----------------------------------------------------------------------------

module async_fifo_flags #(
    parameter DATA_WIDTH = 8,
    parameter ADDR_WIDTH = 12,
    parameter RESERVE = 0
) (   input rst

    , input wr_clk
    , input wr_en
    , input [DATA_WIDTH-1:0] wr_data
    , output full
    , output prog_full

    , input  rd_clk
    , input  rd_en
    , output reg [DATA_WIDTH-1:0] rd_data
    , output empty
    , output has_data
);

    wire rst_sw, rst_sr;

    sync_reg #( .WIDTH(1), .RST_ST(1)
    ) SYNC_WR ( .clk ( wr_clk ), .rst ( rst )
        , .din   ( rst   )
        , .dout  ( rst_sw  )
    );

    sync_reg #( .WIDTH(1), .RST_ST(1)
    ) SYNC_RR ( .clk ( rd_clk ), .rst ( rst )
        , .din   ( rst   )
        , .dout  ( rst_sr  )
    );

    localparam DEPTH = 2**ADDR_WIDTH;
    localparam RAM_TYPE = (ADDR_WIDTH > 5) ? "BLOCK" : "DISTRIBUTED";
    (* RAM_STYLE = RAM_TYPE *) reg [DATA_WIDTH-1:0] ram[0:DEPTH-1];

    reg [ADDR_WIDTH:0] wr_ptr;
    reg [ADDR_WIDTH:0] rd_ptr;

    wire [ADDR_WIDTH:0] occup;
    wire [ADDR_WIDTH+1:0] space;

    wire [ADDR_WIDTH:0] wr_ptr_gray;
    wire [ADDR_WIDTH:0] rd_ptr_gray;

    wire [ADDR_WIDTH:0] wr_ptr_dec;
    wire [ADDR_WIDTH:0] rd_ptr_dec;

    reg [ADDR_WIDTH:0] wr_ptr_sync;
    reg [ADDR_WIDTH:0] rd_ptr_sync;

    reg [ADDR_WIDTH:0] wr_ptr_s1;
    reg [ADDR_WIDTH:0] rd_ptr_s1;

    reg [ADDR_WIDTH:0] wr_ptr_s2;
    reg [ADDR_WIDTH:0] rd_ptr_s2;

    reg [2:0] wr_rst_cnt;
    reg [2:0] rd_rst_cnt;

    reg wr_rst;
    reg rd_rst;
    reg not_empty;

    wire full_i;

    function[ADDR_WIDTH:0] binary2gray;
        input[ADDR_WIDTH:0] input_value;
        integer i;
        begin
            binary2gray[ADDR_WIDTH] = input_value[ADDR_WIDTH];
            for (i=0; i<ADDR_WIDTH; i = i+1)
                binary2gray[i] = input_value[i] ^ input_value[i + 1];
        end
    endfunction

    function[ADDR_WIDTH:0] gray2binary;
        input[ADDR_WIDTH:0] input_value;
        integer i;
        begin
            gray2binary[ADDR_WIDTH] = input_value[ADDR_WIDTH];
            for (i=ADDR_WIDTH; i>0; i=i-1)
                gray2binary[i-1] = input_value[i-1] ^ gray2binary[i];
        end
    endfunction

    assign wr_ptr_gray = binary2gray(wr_ptr);
    assign rd_ptr_gray = binary2gray(rd_ptr);

    assign wr_ptr_dec = gray2binary(wr_ptr_s2);
    assign rd_ptr_dec = gray2binary(rd_ptr_s2);

     always @(posedge rd_clk) begin
       if (rd_rst) begin
        wr_ptr_s1 <= 'b0;
        wr_ptr_s2 <= 'b0;
        wr_ptr_sync <= 'b0;
      end else begin
        wr_ptr_s1 <= wr_ptr_gray;
        wr_ptr_s2 <= wr_ptr_s1;
        wr_ptr_sync <= wr_ptr_dec;
      end
    end

    always @(posedge wr_clk) begin
      if (wr_rst) begin
        rd_ptr_s1 <= 'b0;
        rd_ptr_s2 <= 'b0;
        rd_ptr_sync <= 'b0;
      end else begin
        rd_ptr_s1 <= rd_ptr_gray;
        rd_ptr_s2 <= rd_ptr_s1;
        rd_ptr_sync <= rd_ptr_dec;
      end
    end

    assign empty = (rd_ptr == wr_ptr_sync) ? 1'b1 : rd_rst;
    assign has_data = (rd_ptr == wr_ptr_sync) ? 1'b0 : (~rd_rst);

    assign occup = (wr_ptr - rd_ptr_sync);
    assign space =  DEPTH - {1'b0, occup};

    reg    full_reg;
    assign full_i  = ((wr_ptr[ADDR_WIDTH-1:0] == rd_ptr_sync[ADDR_WIDTH-1:0])
                      && (wr_ptr[ADDR_WIDTH] != rd_ptr_sync[ADDR_WIDTH])) ? 1'b1 : 1'b0;
    /* verilator lint_off WIDTH */
    assign prog_full    = (space <= RESERVE) ? 1'b1 : full_reg | wr_rst;
    /* verilator lint_on WIDTH */
    assign full = full_i;

    always @(posedge wr_clk) begin
      if(wr_rst) begin
        full_reg <= 1'b1;
      end else begin
        full_reg <= 1'b0;
      end
    end


    always @(posedge wr_clk ) begin
      if (rst_sw) begin
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
      if (wr_rst) begin
        wr_ptr <= 'b0;
      end else if (wr_en && !full_i) begin
        wr_ptr <= wr_ptr + 1'b1;
      end
    end

    always @(posedge wr_clk) begin
      if (wr_en && !full_i) begin
          ram[wr_ptr[ADDR_WIDTH-1:0]] <= wr_data;
      end
    end

    always @(posedge rd_clk ) begin
        if (rst_sr) begin
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
        if (rd_rst) begin
            rd_ptr <= 'b0;
        end else if (rd_en && !empty) begin
            rd_ptr <= rd_ptr + 1'b1;
        end
    end

    always @(posedge rd_clk) begin
      if (rd_en && !empty) begin
         rd_data <= ram[rd_ptr[ADDR_WIDTH-1:0]];
      end
    end

endmodule
