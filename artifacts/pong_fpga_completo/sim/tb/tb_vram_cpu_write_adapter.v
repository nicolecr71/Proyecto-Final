`timescale 1ns/1ps
`default_nettype none

module tb_vram_cpu_write_adapter;

    reg        cpu_wr_en;
    reg [7:0]  cpu_x;
    reg [6:0]  cpu_y;
    reg [11:0] cpu_pixel_data;

    wire        vram_wr_en;
    wire [14:0] vram_wr_addr;
    wire [11:0] vram_wr_data;
    wire        coordinate_valid;

    integer error_count;

    vram_cpu_write_adapter dut (
        .cpu_wr_en(cpu_wr_en),
        .cpu_x(cpu_x),
        .cpu_y(cpu_y),
        .cpu_pixel_data(cpu_pixel_data),
        .vram_wr_en(vram_wr_en),
        .vram_wr_addr(vram_wr_addr),
        .vram_wr_data(vram_wr_data),
        .coordinate_valid(coordinate_valid)
    );

    task check_write;
        input        wr_en_in;
        input [7:0]  x_in;
        input [6:0]  y_in;
        input [11:0] data_in;
        input        expected_wr_en;
        input [14:0] expected_addr;
        input [11:0] expected_data;
        input        expected_valid;
        begin
            cpu_wr_en = wr_en_in;
            cpu_x = x_in;
            cpu_y = y_in;
            cpu_pixel_data = data_in;
            #1;

            if (vram_wr_en !== expected_wr_en) begin
                $display("ERROR: vram_wr_en incorrecto. x=%0d y=%0d valor=%0b esperado=%0b",
                    x_in, y_in, vram_wr_en, expected_wr_en);
                error_count = error_count + 1;
            end

            if (vram_wr_addr !== expected_addr) begin
                $display("ERROR: vram_wr_addr incorrecto. x=%0d y=%0d addr=%0d esperado=%0d",
                    x_in, y_in, vram_wr_addr, expected_addr);
                error_count = error_count + 1;
            end

            if (vram_wr_data !== expected_data) begin
                $display("ERROR: vram_wr_data incorrecto. dato=%h esperado=%h",
                    vram_wr_data, expected_data);
                error_count = error_count + 1;
            end

            if (coordinate_valid !== expected_valid) begin
                $display("ERROR: coordinate_valid incorrecto. x=%0d y=%0d valor=%0b esperado=%0b",
                    x_in, y_in, coordinate_valid, expected_valid);
                error_count = error_count + 1;
            end
        end
    endtask

    initial begin
        error_count = 0;

        // Primer pixel.
        check_write(1'b1, 8'd0, 7'd0, 12'hF00, 1'b1, 15'd0, 12'hF00, 1'b1);

        // Segundo pixel horizontal.
        check_write(1'b1, 8'd1, 7'd0, 12'h0F0, 1'b1, 15'd1, 12'h0F0, 1'b1);

        // Segunda fila.
        check_write(1'b1, 8'd0, 7'd1, 12'h00F, 1'b1, 15'd160, 12'h00F, 1'b1);

        // Centro lógico: x=80, y=60 -> 60*160 + 80 = 9680.
        check_write(1'b1, 8'd80, 7'd60, 12'hFFF, 1'b1, 15'd9680, 12'hFFF, 1'b1);

        // Último pixel válido: x=159, y=119 -> 119*160 + 159 = 19199.
        check_write(1'b1, 8'd159, 7'd119, 12'h555, 1'b1, 15'd19199, 12'h555, 1'b1);

        // Coordenada X inválida.
        check_write(1'b1, 8'd160, 7'd0, 12'hAAA, 1'b0, 15'd0, 12'h000, 1'b0);

        // Coordenada Y inválida.
        check_write(1'b1, 8'd0, 7'd120, 12'hBBB, 1'b0, 15'd0, 12'h000, 1'b0);

        // Coordenada válida, pero sin solicitud de escritura.
        check_write(1'b0, 8'd10, 7'd10, 12'h123, 1'b0, 15'd1610, 12'h123, 1'b1);

        if (error_count == 0) begin
            $display("TEST PASSED: vram_cpu_write_adapter funciona correctamente.");
        end else begin
            $display("TEST FAILED: errores detectados = %0d", error_count);
        end

        $finish;
    end

endmodule

`default_nettype wire
