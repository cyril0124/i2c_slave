`timescale 1ns/1ns

module pipe
#(
    parameter PIPE_LEN = 2,
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
    if(PIPE_LEN == -1) begin
        assign output_signal = (input_signal == 1'b0) ? 1'b0 : 1'b1;
    end
    else if(PIPE_LEN == 0) begin
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
    else if(PIPE_LEN == 1) begin
        reg input_pipe;
        reg output_signal_reg;

        assign output_signal = output_signal_reg;

        always @(posedge clk or negedge rst_n) 
        begin
            if(rst_n == 1'b0) begin
                input_pipe <= #U_DLY INIT_VAL;
                output_signal_reg <= #U_DLY INIT_VAL;
            end
            else begin
                input_pipe <= #U_DLY input_signal;
                output_signal_reg <= #U_DLY input_pipe;
            end
        end
    end
    else begin
        reg [PIPE_LEN-1:0] input_pipe;
        reg output_signal_reg;

        assign output_signal = output_signal_reg;

        always @(posedge clk or negedge rst_n) 
        begin
            if(rst_n == 1'b0) begin
                input_pipe <= #U_DLY {PIPE_LEN{INIT_VAL}};
                output_signal_reg <= #U_DLY INIT_VAL;
            end
            else begin
                input_pipe <= #U_DLY {input_pipe[PIPE_LEN-2:0],input_signal};
                output_signal_reg <= #U_DLY input_pipe[PIPE_LEN-1];
            end
        end
    end
endgenerate



endmodule