`timescale 1ns/1ns

module edge_detect
#(
    parameter POS_ENABLE = 1,
    parameter NEG_ENABLE = 1,
    parameter INIT_VAL = 1'b0
)
(
    input wire clk,
    input wire rst_n,
    input wire input_signal,
    output wire pos,
    output wire neg
);

parameter U_DLY = 1;

reg input_signal_dly;

always @(posedge clk or negedge rst_n) 
begin
    if(rst_n == 1'b0) begin
        input_signal_dly <= #U_DLY INIT_VAL;
    end
    else begin 
        input_signal_dly <= #U_DLY input_signal;
    end
end

generate
    if(POS_ENABLE == 1) begin
        reg pos_reg;

        assign pos = pos_reg;

        always @(posedge clk or negedge rst_n) 
        begin
            if(rst_n == 1'b0) begin
                pos_reg <= #U_DLY 1'b0;
            end
            else if(input_signal == 1'b1 && input_signal_dly == 1'b0) begin
                pos_reg <= #U_DLY 1'b1;
            end
            else begin 
                pos_reg <= #U_DLY 1'b0;
            end
        end
    end
    else begin 
        assign pos = 1'b0;
    end
endgenerate

generate
    if(NEG_ENABLE == 1) begin
        reg neg_reg;
        
        assign neg = neg_reg;

        always @(posedge clk or negedge rst_n) 
        begin
            if(rst_n == 1'b0) begin
                neg_reg <= #U_DLY 1'b0;
            end
            else if(input_signal == 1'b0 && input_signal_dly == 1'b1) begin
                neg_reg <= #U_DLY 1'b1;
            end
            else begin 
                neg_reg <= #U_DLY 1'b0;
            end
        end
    end
    else begin 
        assign neg = 1'b0;
    end
endgenerate


endmodule