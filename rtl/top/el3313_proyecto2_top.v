`default_nettype none

//! @title Top del Proyecto 2 EL3313
//! @author Grupo Maestro
//! @brief Integra salida VGA leyendo una escena desde VRAM.
//!
//! Este módulo superior conecta el generador de pixel_tick, el temporizador
//! VGA, el generador de direcciones de lectura, la VRAM de doble puerto y
//! un escritor de patrón de prueba.
//!
//! La imagen mostrada ya no se genera directamente con lógica combinacional,
//! sino que se almacena primero en VRAM y luego se lee durante el barrido VGA.
//! Esto valida la arquitectura base procesador -> memoria de video -> VGA.

module el3313_proyecto2_top (
    input  wire       CLK100MHZ,  //! Reloj principal de 100 MHz de la Nexys A7.
    input  wire       CPU_RESETN, //! Reset físico activo en bajo.

    output wire [3:0] VGA_R,      //! Canal rojo VGA.
    output wire [3:0] VGA_G,      //! Canal verde VGA.
    output wire [3:0] VGA_B,      //! Canal azul VGA.
    output wire       VGA_HS,     //! Sincronización horizontal VGA.
    output wire       VGA_VS      //! Sincronización vertical VGA.
);

    wire reset_active_high;

    wire pixel_tick;
    wire video_active;
    wire frame_tick;
    wire [9:0] pixel_x;
    wire [9:0] pixel_y;

    wire [14:0] vram_read_addr;
    wire        vram_read_active;
    wire [11:0] vram_read_data;

    wire        pattern_wr_en;
    wire [14:0] pattern_wr_addr;
    wire [11:0] pattern_wr_data;
    wire        pattern_busy;
    wire        pattern_done;

    reg pattern_start;

    assign reset_active_high = ~CPU_RESETN;

    //! @brief Pulso inicial para llenar la VRAM después del reset.
    always @(posedge CLK100MHZ) begin
        if (reset_active_high) begin
            pattern_start <= 1'b0;
        end else if (!pattern_busy && !pattern_done) begin
            pattern_start <= 1'b1;
        end else begin
            pattern_start <= 1'b0;
        end
    end

    //! @brief Generador de habilitación de pixel para VGA.
    pixel_tick_gen #(
        .DIVISOR(4)
    ) pixel_tick_gen_inst (
        .clk(CLK100MHZ),
        .rst(reset_active_high),
        .pixel_tick(pixel_tick)
    );

    //! @brief Temporizador VGA para resolución base 640x480.
    vga_timing vga_timing_inst (
        .clk(CLK100MHZ),
        .rst(reset_active_high),
        .pixel_tick(pixel_tick),
        .hsync(VGA_HS),
        .vsync(VGA_VS),
        .video_active(video_active),
        .frame_tick(frame_tick),
        .pixel_x(pixel_x),
        .pixel_y(pixel_y)
    );

    //! @brief Convierte coordenadas VGA 640x480 a direcciones VRAM 160x120.
    vram_read_addr_gen vram_read_addr_gen_inst (
        .video_active(video_active),
        .pixel_x(pixel_x),
        .pixel_y(pixel_y),
        .vram_read_addr(vram_read_addr),
        .vram_read_active(vram_read_active)
    );

    //! @brief Escribe una escena estática tipo Pong dentro de la VRAM.
    vram_test_pattern_writer vram_test_pattern_writer_inst (
        .clk(CLK100MHZ),
        .rst(reset_active_high),
        .start(pattern_start),
        .wr_en(pattern_wr_en),
        .wr_addr(pattern_wr_addr),
        .wr_data(pattern_wr_data),
        .busy(pattern_busy),
        .done(pattern_done)
    );

    //! @brief Memoria de video de doble puerto.
    vram_dual_port vram_dual_port_inst (
        .clk(CLK100MHZ),

        .wr_en(pattern_wr_en),
        .wr_addr(pattern_wr_addr),
        .wr_data(pattern_wr_data),

        .rd_addr(vram_read_addr),
        .rd_data(vram_read_data)
    );

    assign VGA_R = (pattern_done && vram_read_active) ? vram_read_data[11:8] : 4'h0;
    assign VGA_G = (pattern_done && vram_read_active) ? vram_read_data[7:4]  : 4'h0;
    assign VGA_B = (pattern_done && vram_read_active) ? vram_read_data[3:0]  : 4'h0;

endmodule

`default_nettype wire
