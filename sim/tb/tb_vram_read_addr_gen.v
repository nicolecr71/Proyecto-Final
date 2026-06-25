`timescale 1ns/1ps
`default_nettype none

module tb_vram_read_addr_gen;

    reg video_active;
    reg [9:0] pixel_x;
    reg [9:0] pixel_y;

    wire [14:0] vram_read_addr;
    wire        vram_read_active;

    integer error_count;

    vram_read_addr_gen dut (
        .video_active(video_active),
        .pixel_x(pixel_x),
        .pixel_y(pixel_y),
        .vram_read_addr(vram_read_addr),
        .vram_read_active(vram_read_active)
    );

    task check_addr;
        input        active;
        input [9:0]  x;
        input [9:0]  y;
        input [14:0] expected_addr;
        input        expected_active;
        begin
            video_active = active;
            pixel_x = x;
            pixel_y = y;
            #1;

            if (vram_read_addr !== expected_addr) begin
                $display("ERROR: dirección incorrecta. x=%0d y=%0d addr=%0d esperado=%0d",
                    x, y, vram_read_addr, expected_addr);
                error_count = error_count + 1;
            end

            if (vram_read_active !== expected_active) begin
                $display("ERROR: vram_read_active incorrecto. x=%0d y=%0d active=%0b esperado=%0b",
                    x, y, vram_read_active, expected_active);
                error_count = error_count + 1;
            end
        end
    endtask

    initial begin
        error_count = 0;

        // Fuera de zona visible: dirección cero e inactivo.
        check_addr(1'b0, 10'd100, 10'd100, 15'd0, 1'b0);

        // Esquina superior izquierda.
        check_addr(1'b1, 10'd0, 10'd0, 15'd0, 1'b1);

        // Segundo pixel lógico horizontal.
        check_addr(1'b1, 10'd4, 10'd0, 15'd1, 1'b1);

        // Segundo pixel lógico vertical.
        check_addr(1'b1, 10'd0, 10'd4, 15'd160, 1'b1);

        // Pixel dentro del mismo bloque 4x4 debe apuntar a la misma dirección.
        check_addr(1'b1, 10'd3, 10'd3, 15'd0, 1'b1);
        check_addr(1'b1, 10'd7, 10'd3, 15'd1, 1'b1);

        // Centro aproximado.
        // 320/4 = 80, 240/4 = 60
        // addr = 60*160 + 80 = 9680
        check_addr(1'b1, 10'd320, 10'd240, 15'd9680, 1'b1);

        // Último pixel visible.
        // 639/4 = 159, 479/4 = 119
        // addr = 119*160 + 159 = 19199
        check_addr(1'b1, 10'd639, 10'd479, 15'd19199, 1'b1);

        if (error_count == 0) begin
            $display("TEST PASSED: vram_read_addr_gen funciona correctamente.");
        end else begin
            $display("TEST FAILED: errores detectados = %0d", error_count);
        end

        $finish;
    end

endmodule

`default_nettype wire
