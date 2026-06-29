`timescale 1ns / 1ps

//! @title Wrapper de entradas/salidas del sistema
//! @author Grupo Pong EL3313
//! @brief Conecta los pines fisicos de Nexys A7 con el bloque de sistema: entradas condicionadas, DDR2, UART, VGA, SPI entre FPGAs y microSD.

module system_io_wrapper (
    input  wire CLK100MHZ, //! Reloj principal de 100 MHz de la Nexys A7.
    input  wire CPU_RESETN, //! Reset fisico activo en bajo.

    input  wire BTNC, //! Boton central usado como inicio de partida.
    input  wire BTNU, //! Boton superior para mover la paleta izquierda.
    input  wire BTNL, //! Boton izquierdo para mover la paleta izquierda.
    input  wire BTNR, //! Boton derecho para mover la paleta derecha.
    input  wire BTND, //! Boton inferior para mover la paleta derecha.
    input  wire SW15, //! Switch para habilitar el modo multijugador por SPI.
    input  wire SW0, //! Switch usado como reinicio de partida.

    output wire [12:0] DDR2_0_addr, //! Senal fisica de la interfaz DDR2 de la Nexys A7.
    output wire [2:0]  DDR2_0_ba, //! Senal fisica de la interfaz DDR2 de la Nexys A7.
    output wire        DDR2_0_cas_n, //! Senal fisica de la interfaz DDR2 de la Nexys A7.
    output wire [0:0]  DDR2_0_ck_n, //! Senal fisica de la interfaz DDR2 de la Nexys A7.
    output wire [0:0]  DDR2_0_ck_p, //! Senal fisica de la interfaz DDR2 de la Nexys A7.
    output wire [0:0]  DDR2_0_cke, //! Senal fisica de la interfaz DDR2 de la Nexys A7.
    output wire [0:0]  DDR2_0_cs_n, //! Senal fisica de la interfaz DDR2 de la Nexys A7.
    output wire [1:0]  DDR2_0_dm, //! Senal fisica de la interfaz DDR2 de la Nexys A7.
    inout  wire [15:0] DDR2_0_dq, //! Senal fisica de la interfaz DDR2 de la Nexys A7.
    inout  wire [1:0]  DDR2_0_dqs_n, //! Senal fisica de la interfaz DDR2 de la Nexys A7.
    inout  wire [1:0]  DDR2_0_dqs_p, //! Senal fisica de la interfaz DDR2 de la Nexys A7.
    output wire [0:0]  DDR2_0_odt, //! Senal fisica de la interfaz DDR2 de la Nexys A7.
    output wire        DDR2_0_ras_n, //! Senal fisica de la interfaz DDR2 de la Nexys A7.
    output wire        DDR2_0_we_n, //! Senal fisica de la interfaz DDR2 de la Nexys A7.

    input  wire UART_0_rxd, //! Entrada UART para depuracion desde el computador.
    output wire UART_0_txd, //! Salida UART para mensajes de depuracion.

    output wire [3:0] VGA_B, //! Canal azul de la salida VGA.
    output wire [3:0] VGA_G, //! Canal verde de la salida VGA.
    output wire       VGA_HS, //! Sincronizacion horizontal VGA.
    output wire [3:0] VGA_R, //! Canal rojo de la salida VGA.
    output wire       VGA_VS, //! Sincronizacion vertical VGA.

    // Enlace SPI hacia la FPGA master. Esta FPGA es ESCLAVO del bus:
    // cs/sck/mosi son entradas (las genera el master), miso es salida.
    input  wire spi_cs_n, //! Chip select activo en bajo del enlace SPI entre FPGAs.
    input  wire spi_sck, //! Reloj SPI recibido desde la FPGA maestra.
    input  wire spi_mosi, //! Datos SPI de maestra hacia esclava.
    output wire spi_miso, //! Datos SPI de esclava hacia maestra.

    output wire        SD_RESET, //! Reset de la interfaz microSD.
    inout  wire        spi_sd_rtl_0_io0_io, //! Linea de datos IO0 de la microSD.
    inout  wire        spi_sd_rtl_0_io1_io, //! Linea de datos IO1 de la microSD.
    inout  wire        spi_sd_rtl_0_sck_io, //! Reloj SPI de la microSD.
    inout  wire [0:0]  spi_sd_rtl_0_ss_io //! Chip select de la microSD.
);

    wire [7:0] input_driver_conditioned;
    wire [7:0] input_driver_clean;
    wire       vga_vs_internal;

    assign SD_RESET = 1'b0;

    reg vga_vs_meta;
    reg vga_vs_sync;
    reg vga_vs_prev;
    reg frame_toggle;

    assign input_driver_clean = {frame_toggle, input_driver_conditioned[6:0]};
    assign VGA_VS = vga_vs_internal;

    always @(posedge CLK100MHZ) begin
        if (!CPU_RESETN) begin
            vga_vs_meta  <= 1'b0;
            vga_vs_sync  <= 1'b0;
            vga_vs_prev  <= 1'b0;
            frame_toggle <= 1'b0;
        end else begin
            vga_vs_meta <= vga_vs_internal;
            vga_vs_sync <= vga_vs_meta;
            vga_vs_prev <= vga_vs_sync;

            if (vga_vs_sync && !vga_vs_prev) begin
                frame_toggle <= ~frame_toggle;
            end
        end
    end

    input_conditioner u_input_conditioner (
        .clk(CLK100MHZ),
        .rst_n(CPU_RESETN),

        .btn_start_raw(BTNC),
        .btn_left_up_raw(BTNU),
        .btn_left_down_raw(BTNL),
        .btn_right_up_raw(BTNR),
        .btn_right_down_raw(BTND),
        .sw_multiplayer_raw(SW15),
        .sw_game_reset_raw(SW0),

        .input_driver_o(input_driver_conditioned)
    );

    system_wrapper u_system_wrapper (
        .CLK100MHZ(CLK100MHZ),
        .CPU_RESETN(CPU_RESETN),

        .DDR2_0_addr(DDR2_0_addr),
        .DDR2_0_ba(DDR2_0_ba),
        .DDR2_0_cas_n(DDR2_0_cas_n),
        .DDR2_0_ck_n(DDR2_0_ck_n),
        .DDR2_0_ck_p(DDR2_0_ck_p),
        .DDR2_0_cke(DDR2_0_cke),
        .DDR2_0_cs_n(DDR2_0_cs_n),
        .DDR2_0_dm(DDR2_0_dm),
        .DDR2_0_dq(DDR2_0_dq),
        .DDR2_0_dqs_n(DDR2_0_dqs_n),
        .DDR2_0_dqs_p(DDR2_0_dqs_p),
        .DDR2_0_odt(DDR2_0_odt),
        .DDR2_0_ras_n(DDR2_0_ras_n),
        .DDR2_0_we_n(DDR2_0_we_n),

        .INPUT_DRIVER(input_driver_clean),

        .UART_0_rxd(UART_0_rxd),
        .UART_0_txd(UART_0_txd),

        .VGA_B(VGA_B),
        .VGA_G(VGA_G),
        .VGA_HS(VGA_HS),
        .VGA_R(VGA_R),
        .VGA_VS(vga_vs_internal),

        .spi_cs_n(spi_cs_n),
        .spi_sck(spi_sck),
        .spi_mosi(spi_mosi),
        .spi_miso(spi_miso),

        .spi_sd_rtl_0_io0_io(spi_sd_rtl_0_io0_io),
        .spi_sd_rtl_0_io1_io(spi_sd_rtl_0_io1_io),
        .spi_sd_rtl_0_sck_io(spi_sd_rtl_0_sck_io),
        .spi_sd_rtl_0_ss_io(spi_sd_rtl_0_ss_io)
    );

endmodule
