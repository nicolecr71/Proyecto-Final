`timescale 1ns / 1ps

//! @title Puente SPI para FPGA esclava
//! @author Grupo Pong EL3313
//! @brief Adapta el enlace SPI entre FPGAs para recibir el estado oficial del juego y exponerlo al sistema de video/control.

/*
 * spi_game_slave_bridge
 *
 * Envuelve el esclavo SPI bit-banged comprobado (spi_game_slave_reference)
 * y empaqueta sus puertos para conectarse al MicroBlaze por AXI GPIO.
 *
 * Motivo: el AXI Quad SPI configurado como "master" en el slave NO puede
 * actuar como esclavo del bus (genera su propio SCK, no expone SPISEL), por
 * lo que nunca era seleccionado ni clockeado por la FPGA master. Este puente
 * vuelve al esclavo de hardware (siempre listo) y desacopla el timing SPI del
 * loop lento de render/DDR2/SD del CPU.
 *
 * Interfaz con el CPU (vía 3 AXI GPIO de doble canal):
 *
 *   ENTRADA del CPU  (GPIO output  -> p2_in_word):
 *     bit0 = p2.up, bit1 = p2.down, bit2 = p2.start, bit3 = p2.reset
 *
 *   SALIDA hacia CPU (GPIO inputs <- state_wordN), estado oficial recibido:
 *     state_word0 = { ball_x[15:0],      ball_y[15:0]      }
 *     state_word1 = { paddle_p1_y[15:0], paddle_p2_y[15:0] }
 *     state_word2 = { frame_id[15:0],    elapsed_seconds[15:0] }
 *     state_word3 = { score_p1[7:0], score_p2[7:0], status[7:0], winner[7:0] }
 *     state_word4 = { last_point[7:0], serve_direction[7:0], flags[7:0],
 *                     7'b0, valid_seen }
 *
 * Los puertos state_*_o del módulo de referencia solo cambian ante un paquete
 * VÁLIDO (checksum ok), así que las palabras quedan estables para que el CPU
 * las lea con calma. El CPU detecta "frame nuevo" comparando frame_id; no
 * depende del pulso de 1 ciclo state_valid_o.
 */

module spi_game_slave_bridge (
    input  wire        clk, //! Reloj del modulo.
    input  wire        rst_n, //! Reset activo en bajo.

    /* Pines SPI físicos (al top-level / Pmod JA). Esta FPGA es ESCLAVO. */
    input  wire        spi_cs_n, //! Chip select activo en bajo del enlace SPI entre FPGAs.
    input  wire        spi_sck, //! Reloj SPI recibido desde la FPGA maestra.
    input  wire        spi_mosi, //! Datos SPI de maestra hacia esclava.
    output wire        spi_miso, //! Datos SPI de esclava hacia maestra.

    /* Input del jugador 2 escrito por el CPU (AXI GPIO output channel). */
    input  wire [31:0] p2_in_word,

    /* Estado recibido del master, leído por el CPU (AXI GPIO input channels). */
    output wire [31:0] state_word0,
    output wire [31:0] state_word1,
    output wire [31:0] state_word2,
    output wire [31:0] state_word3,
    output wire [31:0] state_word4
);

    wire [15:0] frame_id;
    wire [15:0] ball_x;
    wire [15:0] ball_y;
    wire [15:0] paddle_p1_y;
    wire [15:0] paddle_p2_y;

    wire [7:0]  score_p1;
    wire [7:0]  score_p2;
    wire [7:0]  status;
    wire [7:0]  winner;
    wire [7:0]  last_point;
    wire [15:0] elapsed_seconds;
    wire [7:0]  serve_direction;
    wire [7:0]  flags;
    wire        state_valid;

    /* Sticky: se enciende con el primer paquete válido y queda en 1.
     * Le sirve al CPU para saber que el enlace ya está vivo. */
    reg         valid_seen;
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            valid_seen <= 1'b0;
        end else if (state_valid) begin
            valid_seen <= 1'b1;
        end
    end

    spi_game_slave_reference u_spi_slave (
        .clk               (clk),
        .rst_n             (rst_n),

        .spi_cs_n          (spi_cs_n),
        .spi_sck           (spi_sck),
        .spi_mosi          (spi_mosi),
        .spi_miso          (spi_miso),

        .p2_up_i           (p2_in_word[0]),
        .p2_down_i         (p2_in_word[1]),
        .p2_start_i        (p2_in_word[2]),
        .p2_reset_i        (p2_in_word[3]),

        .frame_id_o        (frame_id),
        .ball_x_o          (ball_x),
        .ball_y_o          (ball_y),
        .paddle_p1_y_o     (paddle_p1_y),
        .paddle_p2_y_o     (paddle_p2_y),

        .score_p1_o        (score_p1),
        .score_p2_o        (score_p2),
        .status_o          (status),
        .winner_o          (winner),
        .last_point_o      (last_point),
        .elapsed_seconds_o (elapsed_seconds),
        .serve_direction_o (serve_direction),
        .flags_o           (flags),

        .state_valid_o     (state_valid)
    );

    assign state_word0 = { ball_x,      ball_y };
    assign state_word1 = { paddle_p1_y, paddle_p2_y };
    assign state_word2 = { frame_id,    elapsed_seconds };
    assign state_word3 = { score_p1, score_p2, status, winner };
    assign state_word4 = { last_point, serve_direction, flags, 7'b0, valid_seen };

endmodule
