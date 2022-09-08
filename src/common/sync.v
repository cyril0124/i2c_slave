`timescale 1ns/1ns

module sync
#(
    parameter  DLY_NUM =  1,
    parameter  INIT_VAL = 1'b0
)
(
    input  wire clk,
    input  wire rst_n,
    input  wire input_signal,
    output wire output_signal
);

parameter U_DLY = 1;
generate
    //output directly
    if(DLY_NUM == -1) begin
        assign output_signal = (input_signal == 1'b0 ) ? 1'b0 : 1'b1;
    end
    //dly one cycle
    else if(DLY_NUM == 0) begin
        reg output_signal_reg;
        
        assign output_signal = output_signal_reg;

        always @(posedge clk or negedge rst_n) 
        begin
            if(rst_n == 1'b0) begin
                output_signal_reg <= #U_DLY INIT_VAL;
            end
            else
                output_signal_reg <= #U_DLY input_signal;
        end
    end
    //dly more than one cycles
    else begin
        reg output_signal_reg;
        reg [DLY_NUM-1:0] output_signal_dly;

        assign output_signal = output_signal_reg;

        always @(posedge clk or negedge rst_n) 
        begin
            if(rst_n == 1'b0) begin
                output_signal_dly[DLY_NUM:0] <= #U_DLY {DLY_NUM{INIT_VAL}};
            end
            else begin
                output_signal_dly[DLY_NUM:0] <= #U_DLY {output_signal_dly[DLY_NUM-1:0],input_signal};
            end
        end

        always @(posedge clk or negedge rst_n) 
        begin
            if(rst_n == 1'b0) begin
                output_signal_reg <= #U_DLY INIT_VAL;
            end
            else if(output_signal_dly[DLY_NUM-1] == !INIT_VAL) begin
                output_signal_reg <= #U_DLY !INIT_VAL;
            end
            else begin
                output_signal_reg <= #U_DLY INIT_VAL;
            end
        end
    end
endgenerate



endmodule

