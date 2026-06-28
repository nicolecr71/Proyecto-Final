`timescale 1ns/1ps
`default_nettype none

module tb_vram_test_pattern_writer;

    localparam CLK_PERIOD_NS = 10;

    reg clk;
    reg rst;
    reg start;

    wire        wr_en;
    wire [14:0] wr_addr;
    wire [11:0] wr_data;
    wire        busy;
    wire        done;

    integer write_count;
    integer error_count;

    vram_test_pattern_writer dut (
        .clk(clk),
        .rst(rst),
        .start(start),
        .wr_en(wr_en),
        .wr_addr(wr_addr),
        .wr_data(wr_data),
        .busy(busy),
        .done(done)
    );

    always #(CLK_PERIOD_NS / 2) clk = ~clk;

    task check_sample;
        input [14:0] expected_addr;
        input [11:0] expected_data;
        begin
            if ((wr_en == 1'b1) && (wr_addr == expected_addr)) begin
                if (wr_data !== expected_data) begin
                    $display("ERROR: dato incorrecto en addr=%0d. wr_data=%h esperado=%h",
                        expected_addr, wr_data, expected_data);
                    error_count = error_count + 1;
                end
            end
        end
    endtask

    initial begin
        clk = 1'b0;
        rst = 1'b1;
        start = 1'b0;

        write_count = 0;
        error_count = 0;

        repeat (5) @(posedge clk);
        rst = 1'b0;

        @(negedge clk);
        start = 1'b1;

        @(negedge clk);
        start = 1'b0;

        while (!done) begin
            @(posedge clk);
            #1;

            if (wr_en) begin
                if (wr_addr !== write_count[14:0]) begin
                    $display("ERROR: direccion fuera de secuencia. wr_addr=%0d esperado=%0d",
                        wr_addr, write_count);
                    error_count = error_count + 1;
                end

                // addr 0: fondo negro.
                check_sample(15'd0, 12'h000);

                // Linea central: x=79, y=0 -> addr = 79.
                check_sample(15'd79, 12'h555);

                // Paleta izquierda: x=10, y=50 -> addr = 50*160 + 10 = 8010.
                check_sample(15'd8010, 12'hFFF);

                // Pelota: x=78, y=58 -> addr = 58*160 + 78 = 9358.
                check_sample(15'd9358, 12'hFFF);

                // Paleta derecha: x=147, y=50 -> addr = 50*160 + 147 = 8147.
                check_sample(15'd8147, 12'hFFF);

                write_count = write_count + 1;
            end
        end

        if (write_count != 19200) begin
            $display("ERROR: cantidad de escrituras incorrecta. write_count=%0d esperado=19200",
                write_count);
            error_count = error_count + 1;
        end

        if (error_count == 0) begin
            $display("TEST PASSED: vram_test_pattern_writer funciona correctamente.");
        end else begin
            $display("TEST FAILED: errores detectados = %0d", error_count);
        end

        $finish;
    end

endmodule

`default_nettype wire
