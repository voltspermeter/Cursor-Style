//------------------------------------------------------------------------------
// sync_reg.v - Synchronizer register stub for testing
//
// This is a stub implementation. Replace with actual sync_reg for production.
//------------------------------------------------------------------------------

module sync_reg #(
    parameter WIDTH = 1,
    parameter RST_ST = 0
) (
    input wire clk,
    input wire rst,
    input wire [WIDTH-1:0] din,
    output reg [WIDTH-1:0] dout
);

    reg [WIDTH-1:0] sync_r1;
    reg [WIDTH-1:0] sync_r2;

    always @(posedge clk or posedge rst) begin
        if (rst) begin
            sync_r1 <= RST_ST;
            sync_r2 <= RST_ST;
            dout <= RST_ST;
        end else begin
            sync_r1 <= din;
            sync_r2 <= sync_r1;
            dout <= sync_r2;
        end
    end

endmodule
