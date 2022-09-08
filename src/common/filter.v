`timescale 1ns/1ns

module filter
#(
    parameter FILTER_LEN = 8'h05,
    parameter INIT_VAL = 1'b0
)
(
    input wire clk,
    input wire rst_n,
    input wire input_signal,
    output wire output_signal
);

parameter U_DLY = 1;

generate
    if(FILTER_LEN == -1) begin 
        assign output_signal = (input_signal == 1'b0) ? 1'b0 : 1'b1;
    end
    else if(FILTER_LEN == 0) begin
        reg output_signal_reg;
        
        assign output_signal = output_signal_reg;

        always @(posedge clk or negedge rst_n) 
        begin
            if(rst_n == 1'b0) begin
                output_signal_reg <= #U_DLY INIT_VAL;
            end
            else begin 
                output_signal_reg <= #U_DLY input_signal;
            end
        end
    end
    else begin 
        reg [FILTER_LEN:0] filter_pipe;
        reg output_signal_reg;

        assign output_signal = output_signal_reg;

        always @(posedge clk or negedge rst_n) 
        begin
            if(rst_n == 1'b0) begin
                output_signal_reg <= #U_DLY INIT_VAL;
                filter_pipe[FILTER_LEN:0] <= #U_DLY {FILTER_LEN{1'b0}};
            end
            else begin 
                filter_pipe[FILTER_LEN:0] <= #U_DLY {filter_pipe[FILTER_LEN-1:0],input_signal};
                if(&filter_pipe[FILTER_LEN-1:0] == 1'b1) begin
                    output_signal_reg <= #U_DLY 1'b1;
                end
                if(|filter_pipe[FILTER_LEN-1:0] == 1'b0)begin
                    output_signal_reg <= #U_DLY 1'b0;
                end
            end
        end
    end
endgenerate


endmodule
