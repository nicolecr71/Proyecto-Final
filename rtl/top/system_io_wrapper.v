`timescale 1ns / 1ps

module system_io_wrapper (
    input  wire CLK100MHZ,
    input  wire CPU_RESETN,

    input  wire BTNC,
    input  wire BTNU,
    input  wire BTNL,
    input  wire BTNR,
    input  wire BTND,
    input  wire SW15,
    input  wire SW0,

    output wire [12:0] DDR2_0_addr,
    output wire [2:0]  DDR2_0_ba,
    output wire        DDR2_0_cas_n,
    output wire [0:0]  DDR2_0_ck_n,
    output wire [0:0]  DDR2_0_ck_p,
    output wire [0:0]  DDR2_0_cke,
    output wire [0:0]  DDR2_0_cs_n,
    output wire [1:0]  DDR2_0_dm,
    inout  wire [15:0] DDR2_0_dq,
    inout  wire [1:0]  DDR2_0_dqs_n,
    inout  wire [1:0]  DDR2_0_dqs_p,
    output wire [0:0]  DDR2_0_odt,
    output wire        DDR2_0_ras_n,
    output wire        DDR2_0_we_n,

    input  wire UART_0_rxd,
    output wire UART_0_txd,

    output wire [3:0] VGA_B,
    output wire [3:0] VGA_G,
    output wire       VGA_HS,
    output wire [3:0] VGA_R,
    output wire       VGA_VS,

    inout  wire spi_rtl_0_io0_io,
    inout  wire spi_rtl_0_io1_io,
    inout  wire spi_rtl_0_sck_io,
    inout  wire [0:0] spi_rtl_0_ss_io,

    output wire        SD_RESET,
    inout  wire        spi_sd_rtl_0_io0_io,
    inout  wire        spi_sd_rtl_0_io1_io,
    inout  wire        spi_sd_rtl_0_sck_io,
    inout  wire [0:0]  spi_sd_rtl_0_ss_io
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

        .spi_rtl_0_io0_io(spi_rtl_0_io0_io),
        .spi_rtl_0_io1_io(spi_rtl_0_io1_io),
        .spi_rtl_0_sck_io(spi_rtl_0_sck_io),
        .spi_rtl_0_ss_io(spi_rtl_0_ss_io),

        .spi_sd_rtl_0_io0_io(spi_sd_rtl_0_io0_io),
        .spi_sd_rtl_0_io1_io(spi_sd_rtl_0_io1_io),
        .spi_sd_rtl_0_sck_io(spi_sd_rtl_0_sck_io),
        .spi_sd_rtl_0_ss_io(spi_sd_rtl_0_ss_io)
    );

endmodule
