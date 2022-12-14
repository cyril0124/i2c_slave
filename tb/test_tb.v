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
    .DLY_NUM(0),
    .INIT_VAL(0)
)
u_sync_2
(
    .clk(ss.clk),
    .rst_n(ss.rst_n),
    .input_signal(ss.a),
    .output_signal()
);

sync
#(
    .DLY_NUM(1),
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

pipe#(
    .PIPE_LEN     ( 3 ),
    .INIT_VAL     ( 1'b0 )
)u_pipe(
    .clk          ( ss.clk          ),
    .rst_n        ( ss.rst_n        ),
    .input_signal ( ss.d            ),
    .output_signal(   )
);


test u_test
(
    .clk(ss.clk),
    .rst_n(ss.rst_n)
);

initial begin
    wait(ss.m_init_finish == 1'b1);

    ss.m_i2c_send_bytes(8'hA0,64'h01_02,2);

    fork
        ss.m_i2c_send_bytes(8'hB0,64'h01_02,2);
        begin
            @(posedge ss.s_flag_err);
            $strobe("[%d]m_i2c_send_bytes ERROR!\n",$time);
        end
    join

    ss.m_i2c_send_bytes(8'hA0,64'hC0_B0_A0_CC_EF_CD_B2_A0,8);
    
    fork
        ss.m_i2c_recv_bytes(8'hA0,5);
        ss.s_i2c_wr_bytes(64'h55_44_33_22_11,5);
    join

    fork
        ss.m_i2c_eeprom_random_read(8'hA0,8'h12,1);
        ss.s_i2c_wr_bytes(64'hDB,1);
    join
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
    .write_rdy     ( ss.m_write_rdy     ),
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

    .write_data  ( ss.s_write_data  ),
    .write_en    ( ss.s_write_en    ),
    .write_rdy   ( ss.s_write_rdy   ),
    .read_data   ( read_data   ),
    .read_en     ( read_en     ),
    .hitar       ( hitar       ),
    .flag_start  ( flag_start  ),
    .flag_restart( flag_restart),
    .flag_ack    ( flag_ack    ),
    .flag_stop   ( ss.s_flag_stop   ),
    .flag_err    ( ss.s_flag_err    )
);




//**************************************************************************
//                ??????????????????
//**************************************************************************
initial
begin
    $dumpfile("test_tb.vcd");  //??????vcd???????????????????????????
    $dumpvars(0, test_tb);     //?????????????????????????????????0????????????
    #650000
    $stop;
end 

endmodule