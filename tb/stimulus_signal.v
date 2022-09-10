`timescale 1ns/1ns

module stimulus_signal ( );

reg  clk;
reg  rst_n;

reg a;
reg b;
reg c;
reg d;

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

initial begin
    #0 d = 1'b0;
    forever begin
        repeat(5) @(negedge clk); 
        #9 d = ~d;
    end

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
wire m_write_rdy;
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

    m_write_data = 8'hFF;
    m_write_en = 1'b0;
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

        m_slave_addr[7:0] = addr[7:0];

        for(i=0;i<num;i++) begin
            @(posedge m_write_rdy);
            m_write_data[7:0] <= bytes[7:0];
            bytes[63:0] <= bytes[63:0] >> 8;

            @(posedge clk) #U_DLY
            m_write_en = 1'b1;
            @(posedge clk) #U_DLY
            m_write_en = 1'b0;

            if(i==num-1)
                m_conti_write = 1'b0;
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

        m_slave_addr[7:0] = addr[7:0];

        for(i=0;i<num;i=i) begin
            @(posedge m_read_en);
            recv_data[7:0] <= m_read_data[7:0];
            $strobe("[%d]byte:0x%h",$time,recv_data);
            i=i+1;
            if(i==num-1)
                m_conti_receive = 1'b0;
        end

        @(posedge m_flag_stop);
        $strobe("[%d]i2c_recv_bytes done!<<<\n",$time);
    end
endtask

task m_i2c_eeprom_random_read;
    input [7:0] addr;
    input [15:0] word_address;
    input [7:0] word_addr_num;
    reg [7:0] recv_data;
    begin
        #0 begin
            m_i2c_rw = 1'b0; //写
            m_conti_write = 1'b1;
        end
        m_generate_i2c_start;

        m_slave_addr[7:0] = addr[7:0];
        // @(posedge m_flag_ack);
        
        if(word_addr_num[7:0] == 8'h02) begin
            @(posedge m_write_rdy);
            m_write_data[7:0] = word_address[15:8];
            @(posedge clk) #U_DLY
            m_write_en = 1'b1;
            @(posedge clk) #U_DLY
            m_write_en = 1'b0;
            // @(posedge m_flag_ack);
        end
        
        if(word_addr_num[7:0] == 8'h02 || word_addr_num[7:0] == 8'h01) begin
            @(posedge m_write_rdy);
            m_write_data[7:0] = word_address[7:0];
            @(posedge clk) #U_DLY
            m_write_en = 1'b1;
            @(posedge clk) #U_DLY
            m_write_en = 1'b0;
            // @(posedge m_flag_ack);
        end

        @(posedge m_write_rdy);
        m_i2c_rw = 1'b1; //读

        wait(m_flag_restar);

        @(posedge m_flag_ack); //等待i2c发送读地址
        m_conti_write = 1'b0;

        wait(m_read_en);
        recv_data[7:0] = m_read_data[7:0];

        wait(m_flag_stop);
        if(word_addr_num[7:0] == 8'h02)
            $strobe("\n[%d]addr:0x%h word_addr:0x%h byte:0x%h i2c_eeprom_random_read done!\n",$time,addr,word_address,recv_data);
        if(word_addr_num[7:0] == 8'h01)
            $strobe("\n[%d]addr:0x%h word_addr:0x%h byte:0x%h i2c_eeprom_random_read done!\n",$time,addr,word_address[7:0],recv_data);
    end
endtask


wire s_write_rdy;
wire s_flag_stop;
wire s_flag_err;
reg [7:0] s_write_data;
reg s_write_en;

initial begin 
    #0 begin 
        s_write_data = 8'hff;
        s_write_en = 1'b0;
    end
end

task s_i2c_wr_bytes;
    input [63:0] bytes;
    input [7:0] num;
    integer i;
    begin
        for(i=0;i<num;i++) begin
            @(posedge s_write_rdy);
            s_write_data <= bytes[7:0];
            bytes[63:0] <= bytes[63:0] >> 8;
            s_write_en <= 1'b1;
            @(posedge clk) #1
            s_write_en <= 1'b0;
        end
        @(posedge s_flag_stop);
    end
endtask

endmodule