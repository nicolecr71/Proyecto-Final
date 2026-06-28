`timescale 1ns/1ps
`default_nettype none

module tb_el3313_proyecto2_top;

    localparam CLK_PERIOD_NS = 10;

    reg CLK100MHZ;
    reg CPU_RESETN;

    wire [3:0] VGA_R;
    wire [3:0] VGA_G;
    wire [3:0] VGA_B;
    wire       VGA_HS;
    wire       VGA_VS;

    integer error_count;
    integer done_detected;
    integer white_pixel_detected;
    integer gray_pixel_detected;

    el3313_proyecto2_top dut (
        .CLK100MHZ(CLK100MHZ),
        .CPU_RESETN(CPU_RESETN),
        .VGA_R(VGA_R),
        .VGA_G(VGA_G),
        .VGA_B(VGA_B),
        .VGA_HS(VGA_HS),
        .VGA_VS(VGA_VS)
    );

    always #(CLK_PERIOD_NS / 2) CLK100MHZ = ~CLK100MHZ;

    initial begin
        CLK100MHZ = 1'b0;
        CPU_RESETN = 1'b0;

        error_count = 0;
        done_detected = 0;
        white_pixel_detected = 0;
        gray_pixel_detected = 0;

        repeat (10) @(posedge CLK100MHZ);
        CPU_RESETN = 1'b1;

        repeat (30000) begin
            @(posedge CLK100MHZ);

            if (dut.pattern_done) begin
                done_detected = 1;
            end
        end

        if (!done_detected) begin
            $display("ERROR: pattern_done nunca se activo.");
            error_count = error_count + 1;
        end

        repeat (800 * 525 * 4) begin
            @(posedge CLK100MHZ);
            #1;

            if (dut.video_active && dut.pattern_done) begin

                if ((VGA_R == 4'hF) && (VGA_G == 4'hF) && (VGA_B == 4'hF)) begin
                    white_pixel_detected = 1;
                end

                if ((VGA_R == 4'h5) && (VGA_G == 4'h5) && (VGA_B == 4'h5)) begin
                    gray_pixel_detected = 1;
                end
            end
        end

        if (!white_pixel_detected) begin
            $display("ERROR: no se detectaron pixeles blancos desde VRAM.");
            error_count = error_count + 1;
        end

        if (!gray_pixel_detected) begin
            $display("ERROR: no se detectaron pixeles grises desde VRAM.");
            error_count = error_count + 1;
        end

        if (error_count == 0) begin
            $display("TEST PASSED: integracion VGA con VRAM funciona correctamente.");
        end else begin
            $display("TEST FAILED: errores detectados = %0d", error_count);
        end

        $finish;
    end

endmodule

`default_nettype wire
