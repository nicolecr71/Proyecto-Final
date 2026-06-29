`default_nettype none

//! @title Escritor de patrón de prueba para VRAM
//! @author Grupo Maestro
//! @brief Llena la VRAM con una escena estática tipo Pong.
//!
//! Este módulo recorre una VRAM lógica de 160x120 pixeles y escribe
//! un patrón de prueba usado para validar la lectura de memoria y la
//! salida VGA. La escena generada contiene fondo negro, línea central,
//! dos paletas y una pelota.
//!
//! El módulo se usa antes de integrar MicroBlaze V y AXI, permitiendo
//! probar la VRAM con datos conocidos.

module vram_test_pattern_writer #(
    parameter DATA_WIDTH   = 12,    //! Bits por pixel.
    parameter ADDR_WIDTH   = 15,    //! Bits de dirección.
    parameter SCREEN_WIDTH = 160,   //! Ancho lógico de VRAM.
    parameter SCREEN_HEIGHT = 120,  //! Alto lógico de VRAM.
    parameter MEMORY_DEPTH = 19200  //! Cantidad total de pixeles.
)(
    input  wire                  clk,      //! Reloj principal.
    input  wire                  rst,      //! Reset síncrono activo en alto.
    input  wire                  start,    //! Pulso para iniciar escritura.

    output reg                   wr_en,    //! Habilitación de escritura hacia VRAM.
    output reg  [ADDR_WIDTH-1:0] wr_addr,  //! Dirección de escritura hacia VRAM.
    output reg  [DATA_WIDTH-1:0] wr_data,  //! Dato RGB escrito hacia VRAM.

    output reg                   busy,     //! Indica que el llenado está en proceso.
    output reg                   done      //! Indica que el llenado terminó.
);

    localparam [DATA_WIDTH-1:0] COLOR_BLACK = 12'h000;
    localparam [DATA_WIDTH-1:0] COLOR_GRAY  = 12'h555;
    localparam [DATA_WIDTH-1:0] COLOR_WHITE = 12'hFFF;

    localparam PADDLE_WIDTH  = 3;
    localparam PADDLE_HEIGHT = 20;
    localparam BALL_SIZE     = 4;

    localparam LEFT_PADDLE_X  = 10;
    localparam RIGHT_PADDLE_X = SCREEN_WIDTH - 10 - PADDLE_WIDTH;

    localparam LEFT_PADDLE_Y  = (SCREEN_HEIGHT - PADDLE_HEIGHT) / 2;
    localparam RIGHT_PADDLE_Y = (SCREEN_HEIGHT - PADDLE_HEIGHT) / 2;

    localparam BALL_X = (SCREEN_WIDTH - BALL_SIZE) / 2;
    localparam BALL_Y = (SCREEN_HEIGHT - BALL_SIZE) / 2;

    reg [ADDR_WIDTH-1:0] write_addr;
    reg [7:0] logical_x;
    reg [6:0] logical_y;

    wire center_line_area;
    wire left_paddle_area;
    wire right_paddle_area;
    wire ball_area;

    reg [DATA_WIDTH-1:0] next_pixel_data;

    assign center_line_area =
        (logical_x >= (SCREEN_WIDTH / 2 - 1)) &&
        (logical_x <= (SCREEN_WIDTH / 2)) &&
        (logical_y[2] == 1'b0);

    assign left_paddle_area =
        (logical_x >= LEFT_PADDLE_X) &&
        (logical_x <  LEFT_PADDLE_X + PADDLE_WIDTH) &&
        (logical_y >= LEFT_PADDLE_Y) &&
        (logical_y <  LEFT_PADDLE_Y + PADDLE_HEIGHT);

    assign right_paddle_area =
        (logical_x >= RIGHT_PADDLE_X) &&
        (logical_x <  RIGHT_PADDLE_X + PADDLE_WIDTH) &&
        (logical_y >= RIGHT_PADDLE_Y) &&
        (logical_y <  RIGHT_PADDLE_Y + PADDLE_HEIGHT);

    assign ball_area =
        (logical_x >= BALL_X) &&
        (logical_x <  BALL_X + BALL_SIZE) &&
        (logical_y >= BALL_Y) &&
        (logical_y <  BALL_Y + BALL_SIZE);
    always @(*) begin
        next_pixel_data = COLOR_BLACK;

        if (left_paddle_area || right_paddle_area || ball_area) begin
            next_pixel_data = COLOR_WHITE;
        end else if (center_line_area) begin
            next_pixel_data = COLOR_GRAY;
        end
    end
    always @(posedge clk) begin
        if (rst) begin
            wr_en      <= 1'b0;
            wr_addr    <= {ADDR_WIDTH{1'b0}};
            wr_data    <= {DATA_WIDTH{1'b0}};
            busy       <= 1'b0;
            done       <= 1'b0;
            write_addr <= {ADDR_WIDTH{1'b0}};
            logical_x  <= 8'd0;
            logical_y  <= 7'd0;
        end else begin
            wr_en <= 1'b0;

            if (start && !busy && !done) begin
                busy       <= 1'b1;
                done       <= 1'b0;
                write_addr <= {ADDR_WIDTH{1'b0}};
                logical_x  <= 8'd0;
                logical_y  <= 7'd0;
            end else if (busy) begin
                wr_en   <= 1'b1;
                wr_addr <= write_addr;
                wr_data <= next_pixel_data;

                if (write_addr == MEMORY_DEPTH - 1) begin
                    busy       <= 1'b0;
                    done       <= 1'b1;
                    write_addr <= {ADDR_WIDTH{1'b0}};
                    logical_x  <= 8'd0;
                    logical_y  <= 7'd0;
                end else begin
                    write_addr <= write_addr + 1'b1;

                    if (logical_x == SCREEN_WIDTH - 1) begin
                        logical_x <= 8'd0;
                        logical_y <= logical_y + 1'b1;
                    end else begin
                        logical_x <= logical_x + 1'b1;
                    end
                end
            end
        end
    end

endmodule

`default_nettype wire
