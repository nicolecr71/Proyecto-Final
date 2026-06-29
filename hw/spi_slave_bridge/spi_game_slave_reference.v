`timescale 1ns / 1ps

//! @title Referencia de protocolo SPI esclavo
//! @author Grupo Pong EL3313
//! @brief Modelo de referencia del lado esclavo para validar tramas SPI de entrada y estado del juego.

/*
 * SPI Game Slave Reference - Verilog
 *
 * Referencia para la FPGA esclavo.
 *
 * SPI:
 * - Mode 0: CPOL = 0, CPHA = 0
 * - CS activo en bajo
 * - 8 bits
 * - MSB first
 * - Transferencia fija de 24 bytes
 *
 * MOSI:
 *   Maestro envia el estado oficial del juego.
 *
 * MISO:
 *   Esclavo devuelve el input del jugador 2 en los primeros 7 bytes.
 */

module spi_game_slave_reference (
    input  wire clk, //! Reloj del modulo.
    input  wire rst_n, //! Reset activo en bajo.

    input  wire spi_cs_n, //! Chip select activo en bajo del enlace SPI entre FPGAs.
    input  wire spi_sck, //! Reloj SPI recibido desde la FPGA maestra.
    input  wire spi_mosi, //! Datos SPI de maestra hacia esclava.
    output reg  spi_miso, //! Datos SPI de esclava hacia maestra.

    input  wire p2_up_i,
    input  wire p2_down_i,
    input  wire p2_start_i,
    input  wire p2_reset_i,

    output reg [15:0] frame_id_o,
    output reg [15:0] ball_x_o,
    output reg [15:0] ball_y_o,
    output reg [15:0] paddle_p1_y_o,
    output reg [15:0] paddle_p2_y_o,

    output reg [7:0] score_p1_o,
    output reg [7:0] score_p2_o,
    output reg [7:0] status_o,
    output reg [7:0] winner_o,
    output reg [7:0] last_point_o,
    output reg [15:0] elapsed_seconds_o,
    output reg signed [7:0] serve_direction_o,
    output reg [7:0] flags_o,

    output reg state_valid_o
);

    localparam FRAME_BYTES = 24;

    localparam GAME_PACKET_TYPE_INPUT = 8'h01;
    localparam GAME_PACKET_TYPE_STATE = 8'h02;

    reg spi_sck_meta;
    reg spi_sck_sync;
    reg spi_sck_prev;

    reg spi_cs_meta;
    reg spi_cs_sync;
    reg spi_cs_prev;

    reg spi_mosi_meta;
    reg spi_mosi_sync;

    wire sck_rise;
    wire sck_fall;
    wire cs_fall;
    wire cs_rise;
    wire cs_active;

    reg [7:0] rx_mem [0:FRAME_BYTES-1];
    reg [7:0] tx_mem [0:FRAME_BYTES-1];

    reg [7:0] rx_shift;
    reg [2:0] bit_index;
    reg [5:0] byte_index;
    reg [5:0] rx_count;

    integer i;

    assign sck_rise  = (spi_sck_prev == 1'b0) && (spi_sck_sync == 1'b1);
    assign sck_fall  = (spi_sck_prev == 1'b1) && (spi_sck_sync == 1'b0);
    assign cs_fall   = (spi_cs_prev  == 1'b1) && (spi_cs_sync  == 1'b0);
    assign cs_rise   = (spi_cs_prev  == 1'b0) && (spi_cs_sync  == 1'b1);
    assign cs_active = (spi_cs_sync == 1'b0);

    function [7:0] checksum_input;
        input [7:0] frame_id;
        input up;
        input down;
        input start;
        input reset;
        begin
            checksum_input =
                GAME_PACKET_TYPE_INPUT ^
                frame_id ^
                {7'b0, up} ^
                {7'b0, down} ^
                {7'b0, start} ^
                {7'b0, reset};
        end
    endfunction

    function [15:0] get_u16_le;
        input [7:0] lo;
        input [7:0] hi;
        begin
            get_u16_le = {hi, lo};
        end
    endfunction

    function [7:0] checksum_state_rx;
        input integer count;
        integer k;
        begin
            checksum_state_rx = 8'h00;
            for (k = 0; k < count; k = k + 1) begin
                checksum_state_rx = checksum_state_rx ^ rx_mem[k];
            end
        end
    endfunction

    /*
     * Sincronizacion de entradas SPI al reloj interno.
     * clk debe ser bastante mas rapido que spi_sck.
     */
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            spi_sck_meta  <= 1'b0;
            spi_sck_sync  <= 1'b0;
            spi_sck_prev  <= 1'b0;

            spi_cs_meta   <= 1'b1;
            spi_cs_sync   <= 1'b1;
            spi_cs_prev   <= 1'b1;

            spi_mosi_meta <= 1'b0;
            spi_mosi_sync <= 1'b0;
        end else begin
            spi_sck_meta  <= spi_sck;
            spi_sck_sync  <= spi_sck_meta;
            spi_sck_prev  <= spi_sck_sync;

            spi_cs_meta   <= spi_cs_n;
            spi_cs_sync   <= spi_cs_meta;
            spi_cs_prev   <= spi_cs_sync;

            spi_mosi_meta <= spi_mosi;
            spi_mosi_sync <= spi_mosi_meta;
        end
    end

    /*
     * Logica SPI esclavo.
     */
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            spi_miso <= 1'b0;

            rx_shift  <= 8'h00;
            bit_index <= 3'd7;
            byte_index <= 6'd0;
            rx_count <= 6'd0;

            frame_id_o <= 16'd0;
            ball_x_o <= 16'd0;
            ball_y_o <= 16'd0;
            paddle_p1_y_o <= 16'd0;
            paddle_p2_y_o <= 16'd0;

            score_p1_o <= 8'd0;
            score_p2_o <= 8'd0;
            status_o <= 8'd0;
            winner_o <= 8'd0;
            last_point_o <= 8'd0;
            elapsed_seconds_o <= 16'd0;
            serve_direction_o <= 8'sd0;
            flags_o <= 8'd0;

            state_valid_o <= 1'b0;

            for (i = 0; i < FRAME_BYTES; i = i + 1) begin
                rx_mem[i] <= 8'h00;
                tx_mem[i] <= 8'h00;
            end
        end else begin
            state_valid_o <= 1'b0;

            /*
             * Inicio de transaccion.
             * Preparar paquete de input para MISO.
             */
            if (cs_fall) begin
                rx_shift <= 8'h00;
                bit_index <= 3'd7;
                byte_index <= 6'd0;
                rx_count <= 6'd0;

                tx_mem[0] <= GAME_PACKET_TYPE_INPUT;
                tx_mem[1] <= frame_id_o[7:0];
                tx_mem[2] <= {7'b0, p2_up_i};
                tx_mem[3] <= {7'b0, p2_down_i};
                tx_mem[4] <= {7'b0, p2_start_i};
                tx_mem[5] <= {7'b0, p2_reset_i};
                tx_mem[6] <= checksum_input(
                    frame_id_o[7:0],
                    p2_up_i,
                    p2_down_i,
                    p2_start_i,
                    p2_reset_i
                );

                for (i = 7; i < FRAME_BYTES; i = i + 1) begin
                    tx_mem[i] <= 8'h00;
                end

                /*
                 * Primer bit del primer byte.
                 * 0x01 = 00000001, MSB = 0.
                 */
                spi_miso <= GAME_PACKET_TYPE_INPUT[7];
            end

            /*
             * Mode 0:
             * Capturar MOSI en flanco rising de SCK.
             */
            if (cs_active && sck_rise) begin
                rx_shift[bit_index] <= spi_mosi_sync;

                if (bit_index == 3'd0) begin
                    if (byte_index < FRAME_BYTES) begin
                        rx_mem[byte_index] <= {rx_shift[7:1], spi_mosi_sync};
                        rx_count <= byte_index + 6'd1;
                    end

                    if (byte_index < FRAME_BYTES - 1) begin
                        byte_index <= byte_index + 6'd1;
                    end
                end
            end

            /*
             * Mode 0:
             * Cambiar MISO en flanco falling de SCK.
             */
            if (cs_active && sck_fall) begin
                if (bit_index == 3'd0) begin
                    bit_index <= 3'd7;

                    if (byte_index < FRAME_BYTES) begin
                        spi_miso <= tx_mem[byte_index][7];
                    end else begin
                        spi_miso <= 1'b0;
                    end
                end else begin
                    bit_index <= bit_index - 3'd1;

                    if (byte_index < FRAME_BYTES) begin
                        spi_miso <= tx_mem[byte_index][bit_index - 3'd1];
                    end else begin
                        spi_miso <= 1'b0;
                    end
                end
            end

            /*
             * Fin de transaccion.
             * Validar paquete recibido del maestro.
             */
            if (cs_rise) begin
                if (
                    (rx_count >= FRAME_BYTES) &&
                    (rx_mem[0] == GAME_PACKET_TYPE_STATE) &&
                    (checksum_state_rx(23) == rx_mem[23])
                ) begin
                    frame_id_o <= get_u16_le(rx_mem[1], rx_mem[2]);
                    ball_x_o <= get_u16_le(rx_mem[3], rx_mem[4]);
                    ball_y_o <= get_u16_le(rx_mem[5], rx_mem[6]);
                    paddle_p1_y_o <= get_u16_le(rx_mem[7], rx_mem[8]);
                    paddle_p2_y_o <= get_u16_le(rx_mem[9], rx_mem[10]);

                    score_p1_o <= rx_mem[11];
                    score_p2_o <= rx_mem[12];
                    status_o <= rx_mem[13];
                    winner_o <= rx_mem[14];
                    last_point_o <= rx_mem[15];
                    elapsed_seconds_o <= get_u16_le(rx_mem[16], rx_mem[17]);
                    serve_direction_o <= $signed(rx_mem[18]);
                    flags_o <= rx_mem[19];

                    state_valid_o <= 1'b1;
                end
            end
        end
    end

endmodule
