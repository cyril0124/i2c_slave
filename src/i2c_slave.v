`timescale 1ns/1ns

module i2c_slave 
#(
    parameter SLAVE_ADDR = 8'hA0
)
(
    input wire  clk,
    input wire  rst_n,

    input wire  scl_in,
    input wire  sda_in,
    output reg  sda_oen,

    input wire [7:0] write_data,
    input wire  write_en,

    output reg [7:0] read_data,
    output reg  read_en,

    output reg  hitar,
    output reg  flag_start,
    output reg  flag_ack,
    output reg  flag_restart,
    output reg  flag_stop
);

parameter U_DLY = 1;

//**************************************************************************
//                wire defines
//**************************************************************************
wire sda_filter;
wire scl_filter;
wire sda_pos;
wire sda_neg;
wire scl_pos;
wire scl_neg;

//**************************************************************************
//                reg defines
//**************************************************************************
reg i2c_rw; //0:write 1:read
reg sda_oen_pre;
reg [7:0] cnt_sda;
reg [7:0] shift_sda;
reg [7:0] data_send;

//**************************************************************************
//                state machine
//**************************************************************************
reg [7:0] curr_state;
reg [7:0] next_state;

localparam STATE_IDLE   = 8'h00;
localparam STATE_START  = 8'h01;
localparam STATE_ADDR   = 8'h02;
localparam STATE_ACK0   = 8'h03;
localparam STATE_WR_DAT = 8'h04;
localparam STATE_ACK1   = 8'h05;
localparam STATE_RD_DAT = 8'h06;
localparam STATE_ACK2   = 8'h07;
localparam STATE_STOP   = 8'h08;
localparam STATE_RESTART = 8'h09;
localparam STATE_NACK   = 8'h0a;

always @(posedge clk or negedge rst_n) 
begin
    if(rst_n == 1'b0) begin
        curr_state <= #U_DLY STATE_IDLE;
    end
    else begin
        curr_state <= #U_DLY next_state;
    end
end

always @(*)
begin
    case (curr_state)
        STATE_IDLE: begin //8'h00
            if(scl_filter == 1'b1 && sda_neg == 1'b1)
                next_state = STATE_START;
            else
                next_state = STATE_IDLE;
        end
        STATE_START: begin //8'h01
            if(scl_neg == 1'b1)
                next_state = STATE_ADDR;
            else
                next_state = STATE_START;
        end
        STATE_ADDR: begin //8'h02
            if(cnt_sda[7:0] == 8'h07 && scl_neg == 1'b1)
                next_state = STATE_ACK0;
            else
                next_state = STATE_ADDR;
        end
        STATE_ACK0: begin //8'h03
            if(cnt_sda[7:0] == 8'h08 && scl_neg == 1'b1) begin
                if(hitar == 1'b1 && i2c_rw == 1'b0)
                    next_state = STATE_WR_DAT;
                else if(hitar == 1'b1 && i2c_rw == 1'b1)
                    next_state = STATE_RD_DAT;
                else
                    next_state = STATE_STOP;
            end
            else
                next_state = STATE_ACK0;
        end
        STATE_WR_DAT: begin //8'h04
            if(cnt_sda[7:0] == 8'h00 && scl_filter == 1'b1) begin
                if(sda_pos == 1'b1)
                    next_state = STATE_STOP;
                else if(sda_neg == 1'b1)
                    next_state = STATE_RESTART;
            end
            else if(cnt_sda[7:0] == 8'h07 && scl_neg == 1'b1)
                next_state = STATE_ACK1;
            else
                next_state = STATE_WR_DAT;
        end
        STATE_ACK1: begin //8'h05
            if(cnt_sda[7:0] == 8'h08 && scl_neg == 1'b1)
                next_state = STATE_WR_DAT;
            else
                next_state = STATE_ACK1;
        end
        STATE_RD_DAT: begin //8'h06
            if(cnt_sda[7:0] == 8'h00 && scl_filter == 1'b1 && sda_pos == 1'b1)
                next_state = STATE_STOP;
            else if(cnt_sda[7:0] == 8'h07 && scl_neg == 1'b1)
                next_state = STATE_ACK2;
            else
                next_state = STATE_RD_DAT;
        end
        STATE_ACK2: begin //8'h07
            if(cnt_sda[7:0] == 8'h08 && scl_neg == 1'b1) begin
                if(flag_ack == 1'b1)
                    next_state = STATE_RD_DAT;
                else
                    next_state = STATE_NACK;
            end
            else
                next_state = STATE_ACK2;
        end
        STATE_STOP: begin //8'h08
            next_state = STATE_IDLE;
        end
        STATE_RESTART: begin //8'h09
            if(scl_neg == 1'b1)
                next_state = STATE_ADDR;
            else
                next_state = STATE_START;
        end
        STATE_NACK: begin //8'h0a
            if(cnt_sda[7:0] == 8'h00 && scl_filter == 1'b1) begin
                if(sda_pos == 1'b1)
                    next_state = STATE_STOP;
                else if(sda_neg == 1'b1)
                    next_state = STATE_NACK;
            end
        end
        default: next_state = STATE_IDLE;
    endcase
end

always @(posedge clk or negedge rst_n) 
begin
    if(rst_n == 1'b0) begin
    
    end
    else begin
    
    end
end

//**************************************************************************
//                i2c slave write data(master read data)
//**************************************************************************
always @(posedge clk or negedge rst_n) 
begin
    if(rst_n == 1'b0) begin
        data_send[7:0] <= #U_DLY 8'hff;
    end
    else if(write_en == 1'b1) begin
        data_send[7:0] <= #U_DLY write_data[7:0];
    end
end

//**************************************************************************
//                i2c slave read data(master write data)
//**************************************************************************
always @(posedge clk or negedge rst_n) 
begin
    if(rst_n == 1'b0) begin
        read_data[7:0] <= #U_DLY 8'hff; 
    end
    else if(curr_state == STATE_WR_DAT && scl_pos == 1'b1)begin
        read_data[7:0] <= #U_DLY {read_data[6:0],sda_filter};
    end
    else if(curr_state == STATE_IDLE) begin
        read_data[7:0] <= #U_DLY 8'hff;
    end
    else ;
end

always @(posedge clk or negedge rst_n) 
begin
    if(rst_n == 1'b0) begin
        read_en <= #U_DLY 1'b0;
    end
    else if(curr_state == STATE_WR_DAT && next_state == STATE_ACK1) begin
        read_en <= #U_DLY 1'b1;
    end
    else begin
        read_en <= #U_DLY 1'b0;
    end
end

//**************************************************************************
//                i2c address recognize
//**************************************************************************
always @(posedge clk or negedge rst_n) 
begin
    if(rst_n == 1'b0) begin
        shift_sda[7:0] <= #U_DLY 8'hff;
    end
    else if(curr_state == STATE_ADDR && scl_pos == 1'b1) begin
        shift_sda[7:0] <= #U_DLY {shift_sda[6:0],sda_filter};
    end
end

always @(posedge clk or negedge rst_n) 
begin
    if(rst_n == 1'b0) begin
        hitar <= #U_DLY 1'b0;
        i2c_rw <= #U_DLY 1'b0;
    end
    else if(curr_state == STATE_ADDR && next_state == STATE_ACK0 &&
            shift_sda[7:1] == SLAVE_ADDR[7:1]
            ) begin
        hitar <= #U_DLY 1'b1;
        i2c_rw <= #U_DLY shift_sda[0];
    end
    else if(curr_state == STATE_IDLE)begin
        hitar <= #U_DLY 1'b0;
    end
    else ;
end

//**************************************************************************
//                sda bit counter
//**************************************************************************
always @(posedge clk or negedge rst_n) 
begin
    if(rst_n == 1'b0) begin
        cnt_sda[7:0] <= #U_DLY 8'h00;
    end
    else if(cnt_sda[7:0] == 8'h08 && scl_neg == 1'b1) begin
        cnt_sda[7:0] <= #U_DLY 8'h00;
    end
    else if((curr_state == STATE_ADDR || curr_state == STATE_WR_DAT || 
            curr_state == STATE_RD_DAT || curr_state == STATE_NACK) && 
            scl_neg == 1'b1) begin
        cnt_sda[7:0] <= #U_DLY cnt_sda[7:0] + 1'b1;
    end
    else if(curr_state == STATE_IDLE) begin 
        cnt_sda[7:0] <= #U_DLY 8'h00;
    end
end

//**************************************************************************
//                flags signal
//**************************************************************************
always @(posedge clk or negedge rst_n) 
begin
    if(rst_n == 1'b0) begin
        flag_ack <= #U_DLY 1'b0;
    end
    else if(curr_state == STATE_ACK0|| 
            curr_state == STATE_ACK1) begin
        flag_ack <= #U_DLY 1'b1;
    end
    else if(curr_state == STATE_ACK2) begin
        if(scl_pos == 1'b1 && sda_filter == 1'b0) 
            flag_ack <= #U_DLY 1'b1;
        else
            flag_ack <= #U_DLY 1'b0;
    end
    else begin
        flag_ack <= #U_DLY 1'b0;
    end
end

always @(posedge clk or negedge rst_n) 
begin
    if(rst_n == 1'b0) begin
        flag_start <= #U_DLY 1'b0;
    end
    else if(curr_state == STATE_IDLE && next_state == STATE_START) begin
        flag_start <= #U_DLY 1'b1;
    end
    else begin
        flag_start <= #U_DLY 1'b0;
    end
end

always @(posedge clk or negedge rst_n) 
begin
    if(rst_n == 1'b0) begin
        flag_restart <= #U_DLY 1'b0;
    end
    else if(curr_state == STATE_WR_DAT && next_state == STATE_RESTART) begin
        flag_restart <= #U_DLY 1'b1;
    end
    else begin
        flag_restart <= #U_DLY 1'b0;
    end
end

always @(posedge clk or negedge rst_n) 
begin
    if(rst_n == 1'b0) begin
        flag_stop <= #U_DLY 1'b0;
    end
    else if((curr_state == STATE_WR_DAT || curr_state == STATE_RD_DAT || curr_state == STATE_NACK) && 
            next_state == STATE_STOP) begin
        flag_stop <= #U_DLY 1'b1;
    end
    else begin
        flag_stop <= #U_DLY 1'b0;
    end
end

//**************************************************************************
//                sda output signal
//**************************************************************************
always @(posedge clk or negedge rst_n) 
begin
    if(rst_n == 1'b0) begin
        sda_oen <= #U_DLY 1'b1;
    end
    else if(curr_state == STATE_ACK0 || 
            curr_state == STATE_ACK1 ||
            curr_state == STATE_ACK2 )begin
        sda_oen <= #U_DLY 1'b0;
    end
    else begin
        sda_oen <= #U_DLY 1'b1;
    end
end

//**************************************************************************
//                modules define
//**************************************************************************
filter#(
    .FILTER_LEN   ( 8'h02 ),
    .INIT_VAL     ( 1'b0 )
)u_filter_scl(
    .clk           ( clk          ),
    .rst_n         ( rst_n        ),
    .input_signal  ( scl_in       ),
    .output_signal ( scl_filter   )
);

filter#(
    .FILTER_LEN   ( 8'h02 ),
    .INIT_VAL     ( 1'b0 )
)u_filter_sda(
    .clk           ( clk          ),
    .rst_n         ( rst_n        ),
    .input_signal  ( sda_in       ),
    .output_signal ( sda_filter   )
);

edge_detect#(
    .POS_ENABLE   ( 1 ),
    .NEG_ENABLE   ( 1 ),
    .INIT_VAL     ( 1'b0 )
)u_edge_detect_scl(
    .clk          ( clk          ),
    .rst_n        ( rst_n        ),
    .input_signal ( scl_filter   ),
    .pos          ( scl_pos      ),
    .neg          ( scl_neg      )
);

edge_detect#(
    .POS_ENABLE   ( 1 ),
    .NEG_ENABLE   ( 1 ),
    .INIT_VAL     ( 1'b0 )
)u_edge_detect_sda(
    .clk          ( clk          ),
    .rst_n        ( rst_n        ),
    .input_signal ( sda_filter   ),
    .pos          ( sda_pos      ),
    .neg          ( sda_neg      )
);




endmodule


