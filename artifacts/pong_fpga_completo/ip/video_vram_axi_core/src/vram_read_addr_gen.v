`default_nettype none

//! @title Generador de dirección de lectura para VRAM
//! @author Grupo Maestro
//! @brief Convierte coordenadas VGA en direcciones de memoria de video.
//!
//! Este módulo convierte las coordenadas visibles de una pantalla VGA
//! de 640x480 en una dirección de lectura para una VRAM lógica de 160x120.
//!
//! Cada pixel lógico de la VRAM representa un bloque de 4x4 pixeles VGA.
//! Esto permite reducir el tamaño de la memoria de video sin perder una
//! visualización funcional para el juego Pong.
//!
//! La dirección generada sigue el formato lineal:
//!
//! addr = y_logico * 160 + x_logico
//!
//! donde:
//! x_logico = pixel_x / 4
//! y_logico = pixel_y / 4

module vram_read_addr_gen (
    input  wire        video_active,     //! Indica que el pixel VGA actual es visible.
    input  wire [9:0]  pixel_x,          //! Coordenada horizontal VGA.
    input  wire [9:0]  pixel_y,          //! Coordenada vertical VGA.

    output reg  [14:0] vram_read_addr,   //! Dirección lineal de lectura para VRAM.
    output reg         vram_read_active  //! Indica que la dirección generada es válida.
);

    wire [7:0] logical_x;
    wire [6:0] logical_y;
    wire [14:0] row_base;

    assign logical_x = pixel_x[9:2];
    assign logical_y = pixel_y[8:2];

    // logical_y * 160 = logical_y * 128 + logical_y * 32
    assign row_base = {logical_y, 7'b0000000} + {logical_y, 5'b00000};

    //! @brief Lógica combinacional para generar dirección de lectura.
    always @(*) begin
        vram_read_addr   = 15'd0;
        vram_read_active = 1'b0;

        if (video_active) begin
            vram_read_addr   = row_base + logical_x;
            vram_read_active = 1'b1;
        end
    end

endmodule

`default_nettype wire
