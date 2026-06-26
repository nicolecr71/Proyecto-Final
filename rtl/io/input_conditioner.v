`timescale 1ns / 1ps

module input_conditioner (
    input  wire clk,
    input  wire rst_n,

    input  wire btn_start_raw,
    input  wire btn_left_up_raw,
    input  wire btn_left_down_raw,
    input  wire btn_right_up_raw,
    input  wire btn_right_down_raw,
    input  wire sw_multiplayer_raw,
    input  wire sw_game_reset_raw,

    output wire [7:0] input_driver_o
);

    wire start_sync;
    wire left_up_sync;
    wire left_down_sync;
    wire right_up_sync;
    wire right_down_sync;
    wire multiplayer_sync;
    wire game_reset_sync;

    wire start_clean;
    wire left_up_clean;
    wire left_down_clean;
    wire right_up_clean;
    wire right_down_clean;
    wire multiplayer_clean;
    wire game_reset_clean;

    sync_2ff u_sync_start (
        .clk(clk),
        .rst_n(rst_n),
        .async_i(btn_start_raw),
        .sync_o(start_sync)
    );

    sync_2ff u_sync_left_up (
        .clk(clk),
        .rst_n(rst_n),
        .async_i(btn_left_up_raw),
        .sync_o(left_up_sync)
    );

    sync_2ff u_sync_left_down (
        .clk(clk),
        .rst_n(rst_n),
        .async_i(btn_left_down_raw),
        .sync_o(left_down_sync)
    );

    sync_2ff u_sync_right_up (
        .clk(clk),
        .rst_n(rst_n),
        .async_i(btn_right_up_raw),
        .sync_o(right_up_sync)
    );

    sync_2ff u_sync_right_down (
        .clk(clk),
        .rst_n(rst_n),
        .async_i(btn_right_down_raw),
        .sync_o(right_down_sync)
    );

    sync_2ff u_sync_multiplayer (
        .clk(clk),
        .rst_n(rst_n),
        .async_i(sw_multiplayer_raw),
        .sync_o(multiplayer_sync)
    );

    sync_2ff u_sync_game_reset (
        .clk(clk),
        .rst_n(rst_n),
        .async_i(sw_game_reset_raw),
        .sync_o(game_reset_sync)
    );

    debounce u_db_start (
        .clk(clk),
        .rst_n(rst_n),
        .noisy_i(start_sync),
        .clean_o(start_clean)
    );

    debounce u_db_left_up (
        .clk(clk),
        .rst_n(rst_n),
        .noisy_i(left_up_sync),
        .clean_o(left_up_clean)
    );

    debounce u_db_left_down (
        .clk(clk),
        .rst_n(rst_n),
        .noisy_i(left_down_sync),
        .clean_o(left_down_clean)
    );

    debounce u_db_right_up (
        .clk(clk),
        .rst_n(rst_n),
        .noisy_i(right_up_sync),
        .clean_o(right_up_clean)
    );

    debounce u_db_right_down (
        .clk(clk),
        .rst_n(rst_n),
        .noisy_i(right_down_sync),
        .clean_o(right_down_clean)
    );

    debounce u_db_multiplayer (
        .clk(clk),
        .rst_n(rst_n),
        .noisy_i(multiplayer_sync),
        .clean_o(multiplayer_clean)
    );

    debounce u_db_game_reset (
        .clk(clk),
        .rst_n(rst_n),
        .noisy_i(game_reset_sync),
        .clean_o(game_reset_clean)
    );

    assign input_driver_o[0] = left_up_clean;
    assign input_driver_o[1] = left_down_clean;
    assign input_driver_o[2] = start_clean;
    assign input_driver_o[3] = right_up_clean;
    assign input_driver_o[4] = right_down_clean;
    assign input_driver_o[5] = multiplayer_clean;
    assign input_driver_o[6] = game_reset_clean;
    assign input_driver_o[7] = 1'b0;

endmodule
