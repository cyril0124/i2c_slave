`timescale 1ns/1ns

module i2c_slave_top
(
    input wire clk,
    input wire rst_n,

    inout wire scl,
    inout wire sda,

    input wire [7:0] write_data,
    input wire write_en,

    output wire [7:0] read_data,
    output wire read_en,

    output wire hitar,
    output wire flag_start,
    output wire flag_ack,
    output wire flag_stop
);

parameter U_DLY = 1;

wire sda_oen;

assign sda = (sda_oen == 1'b0) ? 1'b0 : 1'bz;

i2c_slave#(
    .SLAVE_ADDR  ( 8'hA0 )
)u_i2c_slave(
    .clk         ( clk         ),
    .rst_n       ( rst_n       ),
    .scl_in      ( scl         ),
    .sda_in      ( sda         ),
    .sda_oen     ( sda_oen     ),
    .write_data  ( write_data  ),
    .write_en    ( write_en    ),
    .read_data   ( read_data   ),
    .read_en     ( read_en     ),
    .hitar       ( hitar       ),
    .flag_start  ( flag_start  ),
    .flag_ack    ( flag_ack    ),
    .flag_stop   ( flag_stop   )
);


endmodule
