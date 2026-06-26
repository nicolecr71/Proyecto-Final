`default_nettype none

//! @title Temporizador VGA
//! @author Grupo Maestro
//! @brief Genera las señales de temporización para una salida VGA.
//!
//! Este módulo implementa los contadores horizontal y vertical necesarios
//! para una resolución base de 640x480. También genera las señales de
//! sincronización horizontal y vertical, la señal de zona visible y las
//! coordenadas actuales del pixel.
//!
//! El módulo no genera colores. Solamente indica en qué posición de la
//! pantalla se encuentra el barrido VGA. Otro módulo debe usar pixel_x,
//! pixel_y y video_active para decidir el color de salida.

module vga_timing #(
    parameter H_VISIBLE      = 640, //! Pixeles visibles horizontales.
    parameter H_FRONT_PORCH  = 16,  //! Porche frontal horizontal.
    parameter H_SYNC_PULSE   = 96,  //! Pulso de sincronización horizontal.
    parameter H_BACK_PORCH   = 48,  //! Porche posterior horizontal.

    parameter V_VISIBLE      = 480, //! Líneas visibles verticales.
    parameter V_FRONT_PORCH  = 10,  //! Porche frontal vertical.
    parameter V_SYNC_PULSE   = 2,   //! Pulso de sincronización vertical.
    parameter V_BACK_PORCH   = 33   //! Porche posterior vertical.
)(
    input  wire        clk,          //! Reloj principal del sistema.
    input  wire        rst,          //! Reset síncrono activo en alto.
    input  wire        pixel_tick,   //! Habilitación de avance de pixel.

    output reg         hsync,        //! Sincronización horizontal VGA activa en bajo.
    output reg         vsync,        //! Sincronización vertical VGA activa en bajo.
    output wire        video_active, //! Indica que el pixel actual está en zona visible.
    output wire        frame_tick,   //! Pulso de un ciclo al finalizar un cuadro.

    output wire [9:0]  pixel_x,      //! Coordenada horizontal actual.
    output wire [9:0]  pixel_y       //! Coordenada vertical actual.
);

    localparam H_TOTAL = H_VISIBLE + H_FRONT_PORCH + H_SYNC_PULSE + H_BACK_PORCH;
    localparam V_TOTAL = V_VISIBLE + V_FRONT_PORCH + V_SYNC_PULSE + V_BACK_PORCH;

    localparam H_SYNC_START = H_VISIBLE + H_FRONT_PORCH;
    localparam H_SYNC_END   = H_VISIBLE + H_FRONT_PORCH + H_SYNC_PULSE;

    localparam V_SYNC_START = V_VISIBLE + V_FRONT_PORCH;
    localparam V_SYNC_END   = V_VISIBLE + V_FRONT_PORCH + V_SYNC_PULSE;

    reg [9:0] h_count;
    reg [9:0] v_count;

    wire h_count_last;
    wire v_count_last;

    assign h_count_last = (h_count == H_TOTAL - 1);
    assign v_count_last = (v_count == V_TOTAL - 1);

    assign video_active = (h_count < H_VISIBLE) && (v_count < V_VISIBLE);
    assign frame_tick   = pixel_tick && h_count_last && v_count_last;

    assign pixel_x = h_count;
    assign pixel_y = v_count;

    //! @brief Contadores horizontal y vertical del barrido VGA.
    always @(posedge clk) begin
        if (rst) begin
            h_count <= 10'd0;
            v_count <= 10'd0;
        end else if (pixel_tick) begin
            if (h_count_last) begin
                h_count <= 10'd0;

                if (v_count_last) begin
                    v_count <= 10'd0;
                end else begin
                    v_count <= v_count + 10'd1;
                end
            end else begin
                h_count <= h_count + 10'd1;
            end
        end
    end

    //! @brief Generación combinacional registrada de las señales de sincronización.
    always @(posedge clk) begin
        if (rst) begin
            hsync <= 1'b1;
            vsync <= 1'b1;
        end else if (pixel_tick) begin
            hsync <= ~((h_count >= H_SYNC_START) && (h_count < H_SYNC_END));
            vsync <= ~((v_count >= V_SYNC_START) && (v_count < V_SYNC_END));
        end
    end

endmodule

`default_nettype wire
