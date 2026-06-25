`timescale 1ns/1ps
`default_nettype none

module tb_pong_static_renderer;

    reg video_active;
    reg [9:0] pixel_x;
    reg [9:0] pixel_y;

    wire [3:0] vga_red;
    wire [3:0] vga_green;
    wire [3:0] vga_blue;

    integer error_count;

    pong_static_renderer dut (
        .video_active(video_active),
        .pixel_x(pixel_x),
        .pixel_y(pixel_y),
        .vga_red(vga_red),
        .vga_green(vga_green),
        .vga_blue(vga_blue)
    );

    task check_color;
        input [9:0] x;
        input [9:0] y;
        input active;
        input [3:0] expected_red;
        input [3:0] expected_green;
        input [3:0] expected_blue;
        begin
            pixel_x = x;
            pixel_y = y;
            video_active = active;
            #1;

            if ((vga_red !== expected_red) ||
                (vga_green !== expected_green) ||
                (vga_blue !== expected_blue)) begin
                $display("ERROR: color incorrecto en x=%0d y=%0d active=%0d. RGB=%h%h%h esperado=%h%h%h",
                    x, y, active,
                    vga_red, vga_green, vga_blue,
                    expected_red, expected_green, expected_blue);
                error_count = error_count + 1;
            end
        end
    endtask

    initial begin
        error_count = 0;

        // Fuera de zona visible: siempre negro.
        check_color(10'd100, 10'd100, 1'b0, 4'h0, 4'h0, 4'h0);

        // Fondo negro.
        check_color(10'd10, 10'd10, 1'b1, 4'h0, 4'h0, 4'h0);

        // Paleta izquierda.
        check_color(10'd45, 10'd240, 1'b1, 4'hF, 4'hF, 4'hF);

        // Paleta derecha.
        check_color(10'd595, 10'd240, 1'b1, 4'hF, 4'hF, 4'hF);

        // Pelota central.
        check_color(10'd320, 10'd240, 1'b1, 4'hF, 4'hF, 4'hF);

        // Línea central gris.
        check_color(10'd320, 10'd100, 1'b1, 4'h5, 4'h5, 4'h5);

        if (error_count == 0) begin
            $display("TEST PASSED: pong_static_renderer funciona correctamente.");
        end else begin
            $display("TEST FAILED: errores detectados = %0d", error_count);
        end

        $finish;
    end

endmodule

`default_nettype wire
