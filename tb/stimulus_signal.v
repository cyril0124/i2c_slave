`timescale 1ns/1ns

module stimulus_signal ( );

reg  clk;
reg  rst_n;

reg a;
reg b;
reg c;

parameter CLK_FREQ = 20;
parameter U_DLY = 1;

initial begin
    #0 clk = 1'b0;
    forever #(CLK_FREQ/2) clk = ~clk;
end

initial begin
    #0 rst_n = 1'b1;
    repeat(1) @(posedge clk); #5
    rst_n = 1'b0;
    repeat(1) @(posedge clk);
    rst_n = 1'b1;
end

initial begin
    #0 a = 1'b0;
    repeat(10) @(posedge clk); #18
    a = 1'b1;
    @(posedge clk); #1
    a = 1'b0;
end

initial begin
    #0 b = 1'b0;
    repeat(10) @(posedge clk); #1
    b = 1'b1;
    repeat(20) @(posedge clk); #1
    b = 1'b0;
end

initial begin
    #0 c = 1'b0;
    repeat(10) @(posedge clk); #1
    c = 1'b1;
    repeat(20) @(posedge clk); #1
    c = 1'b0;
    repeat(10) @(posedge clk); #1
    c = 1'b1;
    repeat(20) @(posedge clk); #1
    c = 1'b0;
end


reg m_i2c_rw;
reg m_i2c_begin;
reg m_init_finish;
reg m_conti_write;
reg m_conti_receive;
reg [7:0] m_slave_addr;
reg [7:0] m_write_data;
reg m_write_en;

wire [7:0] m_read_data;
wire m_read_en;
wire m_flag_start;
wire m_flag_restar;
wire m_flag_ack;
wire m_flag_nack;
wire m_flag_stop;

wire m_scl_in;
wire m_sda_in;
wire m_scl_oen;
wire m_sda_oen;

initial begin 
    #0 begin 
        m_i2c_rw = 1'b1;
        m_i2c_begin = 1'b0;
        m_init_finish = 1'b0;
        m_slave_addr = 8'ha0;
    end
end

initial begin 
    repeat(5) @(posedge clk);
    m_init_finish = 1'b1;

    m_write_data = 8'h54;
    m_write_en = 1'b1;
end

task m_generate_i2c_start;
    begin
        m_i2c_begin = 1'b1;
        @(posedge clk); #1
        m_i2c_begin = 1'b0;
    end
endtask

task m_i2c_send_bytes;
    input [7:0] addr;
    input [63:0] bytes;
    input [7:0] num;
    reg [63:0] temp_bytes;
    integer i;
    begin
        #0 begin
            m_conti_write = 1'b1;
            temp_bytes[63:0] = bytes[63:0];
            m_i2c_rw = 1'b0;
        end
        m_generate_i2c_start;
        wait(m_flag_start);

        m_slave_addr[7:0] = addr[7:0];
        @(posedge m_flag_ack);

        for(i=0;i<num;i++) begin
            m_write_data[7:0] <= bytes[7:0];
            bytes[63:0] <= bytes[63:0] >> 8;

            @(posedge clk) #U_DLY
            m_write_en = 1'b1;
            @(posedge clk) #U_DLY
            m_write_en = 1'b0;

            if(i==num-1) begin
                m_conti_write = 1'b0;
                @(posedge m_flag_nack);
            end
            else begin
                m_conti_write = 1'b1;
                @(posedge m_flag_ack);
            end
        end
        
        wait(m_flag_stop);
        $strobe("\n[%d]addr:0x%h byte:0x%h i2c_send_bytes done!\n",$time,addr,temp_bytes);
    end
endtask

task m_i2c_recv_bytes;
    input [7:0] addr;
    input [7:0] num;
    reg [7:0] recv_data;
    integer i;
    begin
        #0 begin
            recv_data[7:0] = 8'h00;
            m_i2c_rw = 1'b1;
            m_conti_receive = 1'b1;
        end
        $strobe("\n[%d]addr:0x%h num:0x%h i2c_recv_bytes start!>>>",$time,addr,num);
        m_generate_i2c_start;
        wait(m_flag_start);

        m_slave_addr[7:0] = addr[7:0];
        @(posedge m_flag_ack);

        for(i=0;i<num-1;i++) begin
            wait(m_read_en);
            recv_data[7:0] <= m_read_data[7:0];
            $strobe("[%d]byte:0x%h",$time,recv_data);
            @(posedge m_scl_oen); //等待下一波数据
        end

        m_conti_receive = 1'b0;

        @(posedge m_flag_nack);
        wait(m_flag_stop);
        $strobe("[%d]i2c_recv_bytes done!<<<\n",$time);
    end
endtask

task s_i2c_wr_bytes;
    input [63:0] bytes;
    input [7:0] num;
    begin
        
    end
endtask

endmodule