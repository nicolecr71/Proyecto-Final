`default_nettype none

//! @title Adaptador de escritura CPU hacia VRAM
//! @author Grupo Maestro
//! @brief Convierte coordenadas lógicas de pixel en direcciones de VRAM.
//!
//! Este módulo representa una interfaz simple entre una lógica tipo procesador
//! y la memoria de video. Recibe una coordenada lógica x,y dentro de una
//! pantalla de 160x120 pixeles, junto con un color RGB de 12 bits.
//!
//! Si la coordenada es válida y cpu_wr_en está activo, genera una escritura
//! hacia la VRAM de doble puerto.
//!
//! La dirección generada sigue el formato:
//!
//! addr = y * 160 + x
//!
//! Este módulo no implementa AXI todavía. Su objetivo es dejar limpia la
//! conversión procesador -> coordenada -> dirección de VRAM.

module vram_cpu_write_adapter #(
    parameter DATA_WIDTH    = 12,  //! Bits por pixel.
    parameter ADDR_WIDTH    = 15,  //! Bits de dirección de VRAM.
    parameter SCREEN_WIDTH  = 160, //! Ancho lógico de VRAM.
    parameter SCREEN_HEIGHT = 120  //! Alto lógico de VRAM.
)(
    input  wire                  cpu_wr_en,        //! Solicitud de escritura.
    input  wire [7:0]            cpu_x,            //! Coordenada X lógica.
    input  wire [6:0]            cpu_y,            //! Coordenada Y lógica.
    input  wire [DATA_WIDTH-1:0] cpu_pixel_data,   //! Color RGB 4:4:4.

    output wire                  vram_wr_en,       //! Escritura válida hacia VRAM.
    output wire [ADDR_WIDTH-1:0] vram_wr_addr,     //! Dirección lineal de VRAM.
    output wire [DATA_WIDTH-1:0] vram_wr_data,     //! Dato escrito hacia VRAM.
    output wire                  coordinate_valid  //! Indica si x,y están dentro de rango.
);

    wire [ADDR_WIDTH-1:0] row_base;
    wire [ADDR_WIDTH-1:0] computed_addr;

    assign coordinate_valid = (cpu_x < SCREEN_WIDTH) && (cpu_y < SCREEN_HEIGHT);

    // cpu_y * 160 = cpu_y * 128 + cpu_y * 32
    assign row_base =
        {1'b0, cpu_y, 7'b0000000} +
        {3'b000, cpu_y, 5'b00000};

    assign computed_addr = row_base + {7'b0000000, cpu_x};

    assign vram_wr_en   = cpu_wr_en && coordinate_valid;
    assign vram_wr_addr = coordinate_valid ? computed_addr : {ADDR_WIDTH{1'b0}};
    assign vram_wr_data = coordinate_valid ? cpu_pixel_data : {DATA_WIDTH{1'b0}};

endmodule

`default_nettype wire
