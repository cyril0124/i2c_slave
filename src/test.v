module test
(
    input clk,
    input rst_n
);

reg [7:0] data;

always @(posedge clk or negedge rst_n) begin
    if(rst_n == 1'b0)
        data[7:0] <= #1 8'h00;
    else
        data[7:0] <= #1 data[7:0] + 1'b1;
end

endmodule
