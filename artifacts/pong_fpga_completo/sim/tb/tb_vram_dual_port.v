`timescale 1ns/1ps
`default_nettype none

module tb_vram_dual_port;

    localparam CLK_PERIOD_NS = 10;
    localparam DATA_WIDTH_TB = 12;
    localparam ADDR_WIDTH_TB = 15;
    localparam MEMORY_DEPTH_TB = 19200;

    reg clk;

    reg wr_en;
    reg [ADDR_WIDTH_TB-1:0] wr_addr;
    reg [DATA_WIDTH_TB-1:0] wr_data;

    reg [ADDR_WIDTH_TB-1:0] rd_addr;
    wire [DATA_WIDTH_TB-1:0] rd_data;

    integer error_count;

    vram_dual_port #(
        .DATA_WIDTH(DATA_WIDTH_TB),
        .ADDR_WIDTH(ADDR_WIDTH_TB),
        .MEMORY_DEPTH(MEMORY_DEPTH_TB)
    ) dut (
        .clk(clk),
        .wr_en(wr_en),
        .wr_addr(wr_addr),
        .wr_data(wr_data),
        .rd_addr(rd_addr),
        .rd_data(rd_data)
    );

    always #(CLK_PERIOD_NS / 2) clk = ~clk;

    task write_pixel;
        input [ADDR_WIDTH_TB-1:0] addr;
        input [DATA_WIDTH_TB-1:0] data;
        begin
            @(posedge clk);
            wr_en = 1'b1;
            wr_addr = addr;
            wr_data = data;

            @(posedge clk);
            wr_en = 1'b0;
            wr_addr = {ADDR_WIDTH_TB{1'b0}};
            wr_data = {DATA_WIDTH_TB{1'b0}};
        end
    endtask

    task read_and_check_pixel;
        input [ADDR_WIDTH_TB-1:0] addr;
        input [DATA_WIDTH_TB-1:0] expected_data;
        begin
            @(posedge clk);
            rd_addr = addr;

            @(posedge clk);
            #1;

            if (rd_data !== expected_data) begin
                $display("ERROR: lectura incorrecta en addr=%0d. rd_data=%h esperado=%h",
                    addr, rd_data, expected_data);
                error_count = error_count + 1;
            end
        end
    endtask

    initial begin
        clk = 1'b0;

        wr_en = 1'b0;
        wr_addr = {ADDR_WIDTH_TB{1'b0}};
        wr_data = {DATA_WIDTH_TB{1'b0}};
        rd_addr = {ADDR_WIDTH_TB{1'b0}};

        error_count = 0;

        repeat (5) @(posedge clk);

        write_pixel(15'd0,     12'hF00); // rojo
        write_pixel(15'd1,     12'h0F0); // verde
        write_pixel(15'd2,     12'h00F); // azul
        write_pixel(15'd19199, 12'hFFF); // blanco, último pixel válido

        read_and_check_pixel(15'd0,     12'hF00);
        read_and_check_pixel(15'd1,     12'h0F0);
        read_and_check_pixel(15'd2,     12'h00F);
        read_and_check_pixel(15'd19199, 12'hFFF);

        if (error_count == 0) begin
            $display("TEST PASSED: vram_dual_port funciona correctamente.");
        end else begin
            $display("TEST FAILED: errores detectados = %0d", error_count);
        end

        $finish;
    end

endmodule

`default_nettype wire
