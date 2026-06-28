`default_nettype none

//! @title Renderizador estático de Pong
//! @author Grupo Maestro
//! @brief Genera una imagen estática tipo Pong para probar la salida VGA.
//!
//! Este módulo recibe la coordenada actual del pixel y genera los canales
//! RGB correspondientes a una escena simple de Pong. La escena incluye fondo
//! negro, línea central, dos paletas y una pelota.
//!
//! Este módulo no usa memoria de video. Su propósito es validar el barrido
//! VGA, la zona visible y la salida de color antes de integrar VRAM.

module pong_static_renderer #(
    parameter SCREEN_WIDTH  = 640, //! Ancho visible de pantalla.
    parameter SCREEN_HEIGHT = 480  //! Alto visible de pantalla.
)(
    input  wire        video_active, //! Indica que el pixel actual es visible.
    input  wire [9:0]  pixel_x,      //! Coordenada horizontal actual.
    input  wire [9:0]  pixel_y,      //! Coordenada vertical actual.

    output reg  [3:0]  vga_red,      //! Canal rojo VGA.
    output reg  [3:0]  vga_green,    //! Canal verde VGA.
    output reg  [3:0]  vga_blue      //! Canal azul VGA.
);

    localparam PADDLE_WIDTH  = 10;
    localparam PADDLE_HEIGHT = 80;
    localparam BALL_SIZE     = 12;

    localparam LEFT_PADDLE_X  = 40;
    localparam RIGHT_PADDLE_X = SCREEN_WIDTH - 40 - PADDLE_WIDTH;

    localparam LEFT_PADDLE_Y  = (SCREEN_HEIGHT - PADDLE_HEIGHT) / 2;
    localparam RIGHT_PADDLE_Y = (SCREEN_HEIGHT - PADDLE_HEIGHT) / 2;

    localparam BALL_X = (SCREEN_WIDTH - BALL_SIZE) / 2;
    localparam BALL_Y = (SCREEN_HEIGHT - BALL_SIZE) / 2;

    wire center_line_area;
    wire left_paddle_area;
    wire right_paddle_area;
    wire ball_area;

    assign center_line_area =
        (pixel_x >= (SCREEN_WIDTH / 2 - 1)) &&
        (pixel_x <= (SCREEN_WIDTH / 2 + 1)) &&
        ((pixel_y[4] == 1'b0));

    assign left_paddle_area =
        (pixel_x >= LEFT_PADDLE_X) &&
        (pixel_x <  LEFT_PADDLE_X + PADDLE_WIDTH) &&
        (pixel_y >= LEFT_PADDLE_Y) &&
        (pixel_y <  LEFT_PADDLE_Y + PADDLE_HEIGHT);

    assign right_paddle_area =
        (pixel_x >= RIGHT_PADDLE_X) &&
        (pixel_x <  RIGHT_PADDLE_X + PADDLE_WIDTH) &&
        (pixel_y >= RIGHT_PADDLE_Y) &&
        (pixel_y <  RIGHT_PADDLE_Y + PADDLE_HEIGHT);

    assign ball_area =
        (pixel_x >= BALL_X) &&
        (pixel_x <  BALL_X + BALL_SIZE) &&
        (pixel_y >= BALL_Y) &&
        (pixel_y <  BALL_Y + BALL_SIZE);

    //! @brief Lógica combinacional de color para la escena estática.
    always @(*) begin
        vga_red   = 4'h0;
        vga_green = 4'h0;
        vga_blue  = 4'h0;

        if (video_active) begin
            if (left_paddle_area || right_paddle_area || ball_area) begin
                vga_red   = 4'hF;
                vga_green = 4'hF;
                vga_blue  = 4'hF;
            end else if (center_line_area) begin
                vga_red   = 4'h5;
                vga_green = 4'h5;
                vga_blue  = 4'h5;
            end else begin
                vga_red   = 4'h0;
                vga_green = 4'h0;
                vga_blue  = 4'h0;
            end
        end
    end

endmodule

`default_nettype wire
