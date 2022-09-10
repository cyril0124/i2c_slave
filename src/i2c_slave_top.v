`timescale 1ns/1ns

module i2c_slave_top
(
    input  wire       clk,
    input  wire       rst_n,

    inout  wire       scl,
    inout  wire       sda,

    input  wire [7:0] write_data,
    input  wire       write_en,
    output wire       write_rdy,

    output wire [7:0] read_data,
    output wire       read_en,

    output wire       hitar,
    output wire       flag_start,
    output wire       flag_ack,
    output wire       flag_restart,
    output wire       flag_stop,
    output wire       flag_err
);

parameter U_DLY = 1;

wire scl_in;
wire sda_in;
wire sda_oen;

assign sda = (sda_oen == 1'b0) ? 1'b0 : 1'bz;
assign scl_in = scl;
assign sda_in = sda;


i2c_slave#(
    .SLAVE_ADDR   ( 8'hA0 )
)u_i2c_slave(
    .clk          ( clk          ),
    .rst_n        ( rst_n        ),
    .scl_in       ( scl_in       ),
    .sda_in       ( sda_in       ),
    .sda_oen      ( sda_oen      ),
    .write_data   ( write_data   ),
    .write_en     ( write_en     ),
    .write_rdy    ( write_rdy    ),
    .read_data    ( read_data    ),
    .read_en      ( read_en      ),
    .hitar        ( hitar        ),
    .flag_start   ( flag_start   ),
    .flag_ack     ( flag_ack     ),
    .flag_restart ( flag_restart ),
    .flag_stop    ( flag_stop    ),
    .flag_err     ( flag_err     )
);



endmodule
