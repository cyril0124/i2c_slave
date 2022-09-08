`timescale 1ns/1ns

module i2c_master_top
(
    input   wire        clk, 
    input   wire        rst_n,

    inout   wire        scl,
    inout   wire        sda,

    input   wire [7:0]  slave_addr,
    input   wire        i2c_rw,
    input   wire        i2c_begin,

    input   wire        init_finish,

    input   wire        conti_write,
    input   wire        conti_receive,

    input   wire [7:0]  write_data,
    input   wire        write_en,
    output  wire [7:0]  read_data,
    output  wire        read_en,

    output  wire        flag_start,
    output  wire        flag_restar,
    output  wire        flag_ack,
    output  wire        flag_nack,
    output  wire        flag_stop
);

parameter U_DLY = 1;

wire sda_in_master;
wire scl_in_master;

assign sda = (sda_oen == 1'b0) ? 1'b0 : 1'bz;
assign sda_in_master = sda;
assign scl = (scl_oen == 1'b0) ? 1'b0 : 1'bz;
assign scl_in_master = scl;

i2c_master#(
    .PRESCALER  ( 7 )
)u_i2c_master(
    .clk        ( clk        ),
    .rst_n      ( rst_n      ),

    .init_finish( init_finish   ),
    .scl_in     ( scl_in_master ),
    .scl_oen    ( scl_oen       ),
    .sda_in     ( sda_in_master ), //仿真i2c slave时,需把.sda_in()输入设置为sda,其他情况则设置成sda_in sda_in_master
    .sda_oen    ( sda_oen       ),

    .slave_addr ( slave_addr     ),
    .i2c_rw     ( i2c_rw         ),
    .i2c_begin  ( i2c_begin      ),

    .conti_write  ( conti_write   ),
    .conti_receive( conti_receive ),

    .write_data ( write_data ),
    .write_en   ( write_en   ),
    .read_data  ( read_data  ),
    .read_en    ( read_en    ),

    .flag_start ( flag_start ),
    .flag_restar( flag_restar),
    .flag_ack   ( flag_ack   ),
    .flag_nack  ( flag_nack  ),
    .flag_stop  ( flag_stop  ) 
);


endmodule