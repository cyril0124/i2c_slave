`timescale 1ns/1ns
`include "stimulus_signal.v"

module test_tb();


// initial begin
//     #1000
//     $display("\n[%d]simulation done!\n",$time);
//     $stop;
// end

stimulus_signal ss();

sync
#(
    .DLY_NUM(-1),
    .INIT_VAL(0)
)
u_sync
(
    .clk(ss.clk),
    .rst_n(ss.rst_n),
    .input_signal(ss.a),
    .output_signal()
);

sync
#(
    .DLY_NUM(1),
    .INIT_VAL(1)
)
u_sync_2
(
    .clk(ss.clk),
    .rst_n(ss.rst_n),
    .input_signal(!ss.a),
    .output_signal()
);

sync
#(
    .DLY_NUM(2),
    .INIT_VAL(0)
)
u_sync_3
(
    .clk(ss.clk),
    .rst_n(ss.rst_n),
    .input_signal(ss.a),
    .output_signal()
);

filter#(
    .FILTER_LEN   ( 2 )
)u_filter(
    .clk           ( ss.clk    ),
    .rst_n         ( ss.rst_n  ),
    .input_signal  ( ss.b      ),
    .output_signal (   )
);

filter#(
    .FILTER_LEN   ( 5 ),
    .INIT_VAL     ( 1'b0 )
)u_filter_1(
    .clk           ( ss.clk    ),
    .rst_n         ( ss.rst_n  ),
    .input_signal  ( ss.b      ),
    .output_signal (   )
);

edge_detect#(
    .POS_ENABLE   ( 1 ),
    .NEG_ENABLE   ( 1 ),
    .INIT_VAL     ( 1'b0 )
)u_edge_detect(
    .clk          ( ss.clk       ),
    .rst_n        ( ss.rst_n     ),
    .input_signal ( ss.c         ),
    .pos          (   ),
    .neg          (   )
);

test u_test
(
    .clk(ss.clk),
    .rst_n(ss.rst_n)
);

initial begin
    wait(ss.m_init_finish == 1'b1);
    ss.m_i2c_send_bytes(8'hA0,64'h01_02,2);
    ss.m_i2c_send_bytes(8'hA0,64'hC0_B0_A0_CC_EF_CD_B2_A0,8);
    ss.m_i2c_recv_bytes(8'hA0,1);
    $stop;
end

i2c_master u_i2c_master(
    .clk           ( ss.clk        ),
    .rst_n         ( ss.rst_n      ),

    // .scl_in        ( m_scl_in      ),
    .scl_oen       ( ss.m_scl_oen     ),
    .sda_in        ( ss.m_sda_in      ),
    .sda_oen       ( ss.m_sda_oen     ),

    .slave_addr    ( ss.m_slave_addr  ),
    .i2c_rw        ( ss.m_i2c_rw      ),
    .i2c_begin     ( ss.m_i2c_begin     ),
    .init_finish   ( ss.m_init_finish   ),
    .conti_write   ( ss.m_conti_write   ),
    .conti_receive ( ss.m_conti_receive ),
    .write_data    ( ss.m_write_data    ),
    .write_en      ( ss.m_write_en      ),
    .read_data     ( ss.m_read_data     ),
    .read_en       ( ss.m_read_en       ),
    .flag_start    ( ss.m_flag_start    ),
    .flag_restar   ( ss.m_flag_restar   ),
    .flag_ack      ( ss.m_flag_ack      ),
    .flag_nack     ( ss.m_flag_nack     ),
    .flag_stop     ( ss.m_flag_stop     )
);

wire s_scl_in;
wire s_sda_in;
wire s_sda_oen;

i2c_slave u_i2c_slave(
    .clk         ( ss.clk      ),
    .rst_n       ( ss.rst_n    ),

    .scl_in      ( ss.m_scl_oen   ),
    .sda_in      ( ss.m_sda_oen   ),
    .sda_oen     ( ss.m_sda_in    ),

    .write_data  ( write_data  ),
    .write_en    ( write_en    ),
    .read_data   ( read_data   ),
    .read_en     ( read_en     ),
    .hitar       ( hitar       ),
    .flag_start  ( flag_start  ),
    .flag_restart( flag_restart),
    .flag_ack    ( flag_ack    ),
    .flag_stop   ( flag_stop   )
);




//**************************************************************************
//                仿真文件生成
//**************************************************************************
initial
begin
    $dumpfile("test_tb.vcd");  //生成vcd文件，记录仿真信息
    $dumpvars(0, test_tb);     //指定层次数，记录信号，0时刻开始
    #650000
    $stop;
end 

endmodule