`timescale 1ns/1ns

module i2c_master
#(
    parameter FILTER = 1,
    parameter FILTER_WIDTH = 2,
    parameter U_DLY = 1,
    parameter PRESCALER = 7 //400KHz = 2500ns = 1250ns *2 = 83ns *15 *2 = 312.5ns *4 *2 = 4*clk(83ns) *4 *2 = 30*clk(10ns) *4 *2
                            //400KHz = 1250ns *2 = 156.25ns *8 *2 = 2*clk(83ns) *8 *2
)
(
    input   wire        clk           , 
    input   wire        rst_n         ,

    input   wire        init_finish   , //外部初始化完成标志

    input   wire        scl_in        ,
    output  reg         scl_oen       ,
    input   wire        sda_in        ,
    output  reg         sda_oen       ,

    input   wire [7:0]  slave_addr    , //从器件地址，8bit，最低位为0,读写由i2c_rw控制
    input   wire        i2c_rw        , //i2c读写标志 1：读 0:写
    input   wire        i2c_begin     , //i2c启动信号

    input   wire        conti_write   , //连续发送标志
    input   wire        conti_receive , //连续接收标志

    input   wire [7:0]  write_data    , //写入数据 send data
    input   wire        write_en      , //允许写入数据标志
    output  reg         write_rdy     , //数据写入准备信号

    output  reg  [7:0]  read_data     , //读取数据
    output  reg         read_en       , //允许读取数据标志

    output  reg         flag_start    ,
    output  reg         flag_restar   ,
    output  reg         flag_ack      ,
    output  reg         flag_nack     ,
    output  reg         flag_stretch  ,
    output  reg         flag_stop
);

/*
always @(posedge clk or negedge rst_n) 
begin
    if(rst_n == 1'b0) begin
    
    end
    else begin

    end
end
*/

reg [3:0]   i2c_begin_dly ;
reg [3:0]   scl_cnt       ; //scl分段计数
reg [7:0]   cnt_clk       ; //scl时钟计数
reg         clk_en        ; //代表每个scl_cnt的结束
reg [7:0]   num_bit       ; //数据个数
reg [7:0]   data_send     ; //待发送数据
reg         scl_oen_pre   ; //scl输出暂存
reg         sda_oen_pre   ; //sda输出暂存

wire        scl_filter    ; //scl输入滤波
wire        sda_filter    ; //sda输入滤波
wire        i2c_begin_sig ; //i2c开始信号
wire        bit_end       ; //i2c写一个bit信号结束标志

reg [7:0]   curr_state    ; //状态机 现态
reg [7:0]   next_state    ; //状态机 次态

localparam STATE_IDLE    = 4'h0;
localparam STATE_START   = 4'h1;
localparam STATE_ADDR    = 4'h2;
localparam STATE_ACK0    = 4'h3;
localparam STATE_WR_DAT  = 4'h4;
localparam STATE_ACK1    = 4'h5;
localparam STATE_RD_DAT  = 4'h6;
localparam STATE_ACK2    = 4'h7;
localparam STATE_NACK    = 4'h8;
localparam STATE_STOP    = 4'h9; 
localparam STATE_RESTART = 4'ha;


//**************************************************************************
//                状态机
//**************************************************************************

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
    case(curr_state)
        STATE_IDLE: begin //8'h0
            if(i2c_begin_sig == 1'b1 && init_finish==1'b1)
                next_state = STATE_START;
            else
                next_state = STATE_IDLE;
        end
        STATE_START: begin //8'h1
            if(scl_cnt[3:0] == 4'b1111 && clk_en == 1'b1)
                next_state = STATE_ADDR;
            else
                next_state = STATE_START;
        end
        STATE_ADDR: begin //8'h2
            if( num_bit[7:0] == 8'h7 && bit_end == 1'b1)
                next_state = STATE_ACK0;
            else
                next_state =STATE_ADDR;
        end
        STATE_ACK0: begin //8'h3
            if(num_bit[7:0] == 8'h8 && bit_end ==1'b1) begin
                if (flag_ack == 1'b1) begin
                    if(i2c_rw == 1'b0)
                        next_state = STATE_WR_DAT;
                    else    
                        next_state = STATE_RD_DAT;
                end
                else begin
                    next_state = STATE_STOP;
                end
            end
            else begin
                next_state = STATE_ACK0;
            end
        end
        STATE_WR_DAT: begin //8'h4
            if(num_bit[7:0] == 8'h7 && bit_end == 1'b1) begin
                if(conti_write == 1'b1)
                    next_state = STATE_ACK1;
                else
                    next_state = STATE_NACK;
            end
            else
                next_state =STATE_WR_DAT;
        end
        STATE_ACK1: begin //8'h5
            if(num_bit[7:0] == 8'h8 && bit_end ==1'b1) begin 
                if(flag_ack == 1'b1) begin //slave有响应
                    if(i2c_rw == 1'b0) //写状态
                        next_state = STATE_WR_DAT;
                    else //写完数据后，想立即读数据，需要restart
                        next_state = STATE_RESTART;
                end
                else begin //slave无响应
                    next_state = STATE_STOP;
                end
            end
            else begin
                next_state = STATE_ACK1;
            end
        end
        STATE_RD_DAT: begin //8'h6
            if(num_bit[7:0] == 8'h7 && bit_end == 1'b1) begin
                if(conti_receive == 1'b1)
                    next_state = STATE_ACK2;
                else
                    next_state = STATE_NACK;
            end
            else
                next_state = STATE_RD_DAT;
        end
        STATE_ACK2: begin //8'h7
            if(num_bit[7:0] == 8'h8 && bit_end ==1'b1)
                next_state = STATE_RD_DAT;
            else
                next_state = STATE_ACK2;
        end
        STATE_NACK: begin //8'h8
            if(num_bit[7:0]==8'h8 && bit_end ==1'b1 && flag_nack == 1'b1)
                next_state = STATE_STOP;
            else
                next_state = STATE_NACK;
        end
        STATE_STOP: begin //8'h9
            if(num_bit[7:0]==8'h0 && bit_end == 1'b1)
                next_state = STATE_IDLE;
            else
                next_state = STATE_STOP;
        end
        STATE_RESTART: begin //8'ha restart和start处理方式相同
            next_state = STATE_START;
        end
        default: next_state = STATE_IDLE;
    endcase
end


//scl、sda输出
//一个有效的i2c bit，以一个SCL下将沿开始，下一个SCL下降沿结束
/*
            ____
      \____/    \
*/
always @(posedge clk or negedge rst_n) 
begin
    if(rst_n == 1'b0) begin
        scl_oen_pre <= #U_DLY 1'b1;
        sda_oen_pre <= #U_DLY 1'b1;
    end
    else if(clk_en == 1'b1) begin
        case(curr_state) 
            STATE_START: begin
                case(scl_cnt[3:0])
                    4'b0001: begin
                        scl_oen_pre <= #U_DLY 1'b1;
                        sda_oen_pre <= #U_DLY 1'b1;
                    end
                    4'b0011: begin
                        scl_oen_pre <= #U_DLY 1'b1;
                        sda_oen_pre <= #U_DLY 1'b1;
                    end
                    4'b0111: begin
                        scl_oen_pre <= #U_DLY 1'b1;
                        sda_oen_pre <= #U_DLY 1'b0;
                    end
                    4'b1111: begin
                        scl_oen_pre <= #U_DLY 1'b0;
                        sda_oen_pre <= #U_DLY 1'b0;
                    end
                    default: begin
                        scl_oen_pre <= #U_DLY 1'b1;
                        sda_oen_pre <= #U_DLY 1'b1;
                    end
                endcase
            end
            STATE_WR_DAT,
            STATE_ADDR: begin
                case(scl_cnt[3:0])
                    4'b0001: begin
                        scl_oen_pre <= #U_DLY 1'b0;
                        sda_oen_pre <= #U_DLY data_send[7];
                    end
                    4'b0011: begin
                        scl_oen_pre <= #U_DLY 1'b1;
                        sda_oen_pre <= #U_DLY data_send[7];
                    end
                    4'b0111: begin
                        scl_oen_pre <= #U_DLY 1'b1;
                        sda_oen_pre <= #U_DLY data_send[7];
                    end
                    4'b1111: begin
                        scl_oen_pre <= #U_DLY 1'b0;
                        sda_oen_pre <= #U_DLY data_send[7];
                    end
                    default: begin
                        scl_oen_pre <= #U_DLY 1'b1;
                        sda_oen_pre <= #U_DLY 1'b1;
                    end
                endcase                
            end
            STATE_NACK,
            STATE_ACK1,
            STATE_ACK0: begin //从机slave响应
                case(scl_cnt[3:0])
                    4'b0001: begin
                        scl_oen_pre <= #U_DLY 1'b0;
                        sda_oen_pre <= #U_DLY 1'b1;
                    end
                    4'b0011: begin
                        scl_oen_pre <= #U_DLY 1'b1;
                        sda_oen_pre <= #U_DLY 1'b1;
                    end
                    4'b0111: begin
                        scl_oen_pre <= #U_DLY 1'b1;
                        sda_oen_pre <= #U_DLY 1'b1;
                    end
                    4'b1111: begin
                        scl_oen_pre <= #U_DLY 1'b0;
                        sda_oen_pre <= #U_DLY 1'b1;
                    end
                    default: begin
                        scl_oen_pre <= #U_DLY 1'b1;
                        sda_oen_pre <= #U_DLY 1'b1;
                    end
                endcase    
            end
            STATE_ACK2: begin //主机master响应
                case(scl_cnt[3:0])
                    4'b0001: begin
                        scl_oen_pre <= #U_DLY 1'b0;
                        sda_oen_pre <= #U_DLY 1'b1;
                    end
                    4'b0011: begin
                        scl_oen_pre <= #U_DLY 1'b1;
                        sda_oen_pre <= #U_DLY 1'b0;
                    end
                    4'b0111: begin
                        scl_oen_pre <= #U_DLY 1'b1;
                        sda_oen_pre <= #U_DLY 1'b0;
                    end
                    4'b1111: begin
                        scl_oen_pre <= #U_DLY 1'b0;
                        sda_oen_pre <= #U_DLY 1'b0;
                    end
                    default: begin
                        scl_oen_pre <= #U_DLY 1'b1;
                        sda_oen_pre <= #U_DLY 1'b1;
                    end
                endcase    
            end
            STATE_STOP: begin
                case(scl_cnt[3:0])
                    4'b0001: begin
                        scl_oen_pre <= #U_DLY 1'b0;
                        sda_oen_pre <= #U_DLY 1'b0;
                    end
                    4'b0011: begin
                        scl_oen_pre <= #U_DLY 1'b1;
                        sda_oen_pre <= #U_DLY 1'b0;
                    end
                    4'b0111: begin
                        scl_oen_pre <= #U_DLY 1'b1;
                        sda_oen_pre <= #U_DLY 1'b1;
                    end
                    4'b1111: begin
                        scl_oen_pre <= #U_DLY 1'b1;
                        sda_oen_pre <= #U_DLY 1'b1;
                    end
                    default: begin
                        scl_oen_pre <= #U_DLY 1'b1;
                        sda_oen_pre <= #U_DLY 1'b1;
                    end
                endcase    
            end
            STATE_RD_DAT: begin
                case(scl_cnt[3:0])
                    4'b0001: begin
                        scl_oen_pre <= #U_DLY 1'b0;
                        sda_oen_pre <= #U_DLY 1'b1;
                    end
                    4'b0011: begin
                        scl_oen_pre <= #U_DLY 1'b1;
                        sda_oen_pre <= #U_DLY 1'b1;
                    end
                    4'b0111: begin
                        scl_oen_pre <= #U_DLY 1'b1;
                        sda_oen_pre <= #U_DLY 1'b1;
                    end
                    4'b1111: begin
                        scl_oen_pre <= #U_DLY 1'b0;
                        sda_oen_pre <= #U_DLY 1'b1;
                    end
                    default: begin
                        scl_oen_pre <= #U_DLY 1'b1;
                        sda_oen_pre <= #U_DLY 1'b1;
                    end
                endcase
            end
            default: begin
                scl_oen_pre <= #U_DLY 1'b1;
                sda_oen_pre <= #U_DLY 1'b1;
            end
        endcase
    end
end

//**************************************************************************
//                scl、sda数据输出
//**************************************************************************

always @(posedge clk or negedge rst_n) 
begin
    if(rst_n == 1'b0) begin
        scl_oen <= #U_DLY 1'b1;
        sda_oen <= #U_DLY 1'b1;
    end
    else begin
        scl_oen <= #U_DLY scl_oen_pre;
        sda_oen <= #U_DLY sda_oen_pre;
    end
end

always @(posedge clk or negedge rst_n) 
begin
    if(rst_n == 1'b0) begin
        data_send[7:0] <= #U_DLY 8'h00;
    end
    else begin
        case (curr_state)
            STATE_START: begin 
                data_send[7:0] <= #U_DLY {slave_addr[7:1],i2c_rw};
            end
            STATE_WR_DAT,
            STATE_ADDR: begin
                if(scl_cnt[3:0] == 4'b1111 && clk_en == 1'b1)
                    data_send[7:0] <= #U_DLY {data_send[6:0],1'b1}; 
            end
            STATE_ACK0,
            STATE_ACK1: begin
                if(write_en == 1'b1)
                    data_send[7:0] <= #U_DLY write_data[7:0];
                else
                    data_send[7:0] <= #U_DLY data_send[7:0];
            end
        endcase
    end
end


always @(posedge clk or negedge rst_n) 
begin
    if(rst_n == 1'b0) begin
        write_rdy <= #U_DLY 1'b0;
    end
    else  if(curr_state == STATE_WR_DAT && next_state == STATE_ACK1 && i2c_rw == 1'b0) begin
        write_rdy <= #U_DLY 1'b1;
    end
    else if(curr_state == STATE_ADDR && next_state == STATE_ACK0 && i2c_rw == 1'b0) begin
        write_rdy <= #U_DLY 1'b1;
    end
    else begin
        write_rdy <= #U_DLY 1'b0;
    end
end


//**************************************************************************
//                i2c_begin
//**************************************************************************
assign i2c_begin_sig = i2c_begin;
// assign i2c_begin_sig = (~i2c_begin_dly[3]&i2c_begin_dly[2]);

// always @(posedge clk or negedge rst_n) 
// begin
//     if(rst_n == 1'b0) begin
//         i2c_begin_dly[3:0] <= #U_DLY 4'b0000;
//     end
//     else if(i2c_begin == 1'b1) begin
//         i2c_begin_dly[3:0] <= #U_DLY {i2c_begin_dly[2:0],1'b1};
//     end
//     else begin
//         i2c_begin_dly[3:0] <= #U_DLY {i2c_begin_dly[2:0],1'b0};
//     end
// end


//**************************************************************************
//                scl信号
//**************************************************************************
always @(posedge clk or negedge rst_n) 
begin
    if(rst_n == 1'b0) begin
        cnt_clk[7:0] <= #U_DLY 8'h00;
    end
    else if(curr_state == STATE_IDLE) begin
        cnt_clk[7:0] <= #U_DLY 8'h00;
    end    
    else if(cnt_clk[7:0] == PRESCALER) begin
        cnt_clk[7:0] <= #U_DLY 8'h00;
    end
    else begin
        cnt_clk[7:0] <= #U_DLY cnt_clk[7:0] + 1'b1;
    end
end

always @(posedge clk or negedge rst_n) 
begin
    if(rst_n == 1'b0) begin
        clk_en <= #U_DLY 1'b0;
    end
    else if(cnt_clk[7:0] == PRESCALER-1'b1 && curr_state != STATE_IDLE) begin
        clk_en <= #U_DLY 1'b1;
    end
    else begin
        clk_en <= #U_DLY 1'b0;
    end
end

always @(posedge clk or negedge rst_n) 
begin
    if(rst_n == 1'b0) begin
        scl_cnt[3:0] <= #U_DLY 4'b0001;
    end
    else if(cnt_clk[7:0] == PRESCALER && scl_cnt[3:0] == 4'b1111) begin
        scl_cnt[3:0] <= #U_DLY 4'b0001;
    end
    else if(cnt_clk[7:0] == PRESCALER && ~flag_stretch) begin //clock streching状态下，需要等待clock streching状态结束
        scl_cnt[3:0] <= #U_DLY {scl_cnt[2:0],1'b1};
    end
    else begin
        scl_cnt[3:0] <= #U_DLY scl_cnt[3:0];
    end
end

//**************************************************************************
//                sda数据计数
//**************************************************************************

assign bit_end = (scl_cnt[3:0] == 4'b1111 && clk_en);

always @(posedge clk or negedge rst_n) 
begin
    if(rst_n == 1'b0) begin
        num_bit[7:0] <= #U_DLY 8'h00;
    end
    else if(num_bit[7:0] == 8'h8 && bit_end == 1'b1 ) begin
        num_bit[7:0] <= #U_DLY 8'h0;
    end
    else if( curr_state != STATE_IDLE && curr_state != STATE_START && bit_end == 1'b1) begin
        num_bit[7:0] <= #U_DLY num_bit[7:0] + 1'b1;
    end 
    else if(curr_state == STATE_START || curr_state == STATE_RESTART) begin
        num_bit[7:0] <= #U_DLY 8'h0;
    end
end

//**************************************************************************
//                sda_in、scl_in滤波 scl_filter
//**************************************************************************
generate
    if(FILTER == 1'b1) begin
        reg sda_filter_reg;
        reg scl_filter_reg;

        assign sda_filter = sda_filter_reg;
        assign scl_filter = scl_filter_reg;

        reg [FILTER_WIDTH-1:0] sda_pipe;
        reg [FILTER_WIDTH-1:0] scl_pipe; 

        always @(posedge clk or negedge rst_n) 
        begin
            if(rst_n == 1'b0) begin
                sda_pipe[FILTER_WIDTH-1:0] <= #U_DLY {FILTER_WIDTH{1'b1}};
                scl_pipe[FILTER_WIDTH-1:0] <= #U_DLY {FILTER_WIDTH{1'b1}};

                sda_filter_reg <= #U_DLY 1'b1;
                scl_filter_reg <= #U_DLY 1'b1;
            end
            else begin
                sda_pipe[FILTER_WIDTH-1:0] <= #U_DLY {sda_pipe[FILTER_WIDTH-2:0],sda_in};
                scl_pipe[FILTER_WIDTH-1:0] <= #U_DLY {scl_pipe[FILTER_WIDTH-2:0],scl_in};

                if(&sda_pipe[FILTER_WIDTH-1:0] == 1'b1)
                    sda_filter_reg <=  #U_DLY 1'b1;
                else if(|sda_pipe[FILTER_WIDTH-1:0] == 1'b0)
                    sda_filter_reg <= #U_DLY 1'b0;

                if(&scl_pipe[FILTER_WIDTH-1:0] == 1'b1)
                    scl_filter_reg <=  #U_DLY 1'b1;
                else if(|scl_pipe[FILTER_WIDTH-1:0] == 1'b0)
                    scl_filter_reg <= #U_DLY 1'b0;
            end
        end
    end
    else begin
        assign sda_filter = sda_in;
        assign scl_filter = scl_in;
    end
endgenerate

//**************************************************************************
//                sda数据读取
//**************************************************************************
always @(posedge clk or negedge rst_n) 
begin
    if(rst_n == 1'b0) begin
        read_data[7:0] <= #U_DLY 8'h00;
    end
    else if(curr_state == STATE_RD_DAT && scl_cnt[3:0] == 4'b0011 && clk_en == 1'b1) 
        read_data[7:0] <= #U_DLY {read_data[6:0],sda_filter};
    else if(curr_state == STATE_IDLE)
        read_data[7:0] <= #U_DLY 8'h00;
    else
        read_data[7:0] <= #U_DLY read_data[7:0];
end

always @(posedge clk or negedge rst_n) 
begin
    if(rst_n == 1'b0) begin
        read_en <= #U_DLY 1'b0;
    end
    else if(curr_state == STATE_RD_DAT && (next_state == STATE_ACK2 || next_state == STATE_NACK))
        read_en <= #U_DLY 1'b1;
    else
        read_en <= #U_DLY 1'b0;
end


//**************************************************************************
//                flag信号输出
//**************************************************************************

always @(posedge clk or negedge rst_n) 
begin
    if(rst_n == 1'b0) begin
        flag_ack <= #U_DLY 1'b0;
        flag_nack <= #U_DLY 1'b0;
    end
    else if (
            (curr_state == STATE_ACK0 ) ||
            (curr_state == STATE_ACK1 ) ||
            (curr_state == STATE_ACK2 )
    ) begin
        if(scl_cnt[3:0] == 4'b0011 && clk_en == 1'b1 && sda_filter == 1'b0)
            flag_ack <= #U_DLY 1'b1;
    end
    else if(curr_state == STATE_NACK) begin
        if(scl_cnt[3:0] == 4'b0011 && clk_en == 1'b1)
            flag_nack <= #U_DLY 1'b1;
    end
    else begin
        flag_ack <= #U_DLY 1'b0;
        flag_nack <= #U_DLY 1'b0;
    end
end

always @(posedge clk or negedge rst_n) 
begin
    if(rst_n == 1'b0) begin
        flag_start <= #U_DLY 1'b0;
    end
    else if(curr_state == STATE_IDLE && next_state == STATE_START)
        flag_start <= #U_DLY 1'b1;
    else
        flag_start <= #U_DLY 1'b0;
end

always @(posedge clk or negedge rst_n) 
begin
    if(rst_n == 1'b0) begin
        flag_stop <= #U_DLY 1'b0;
    end
    else if(curr_state == STATE_STOP && next_state == STATE_IDLE)
        flag_stop <= #U_DLY 1'b1;
    else   
        flag_stop <= #U_DLY 1'b0;
end

always @(posedge clk or negedge rst_n) 
begin
    if(rst_n == 1'b0) begin 
        flag_restar <= #U_DLY 1'b0;
    end
    else if(curr_state == STATE_ACK1 && next_state == STATE_RESTART)
        flag_restar <= #U_DLY 1'b1;
    else
        flag_restar <= #U_DLY 1'b0;
end

always @(posedge clk or negedge rst_n) 
begin
    if(rst_n == 1'b0) begin 
        flag_stretch <= #U_DLY 1'b0;
    end
    else if(scl_filter == 1'b0 && sda_oen_pre == 1'b1)
        flag_stretch <= #U_DLY 1'b1;
    else
        flag_stretch <= #U_DLY 1'b0;
end


endmodule

