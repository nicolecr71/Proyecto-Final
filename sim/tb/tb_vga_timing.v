`timescale 1ns/1ps
`default_nettype none

module tb_vga_timing;

    localparam CLK_PERIOD_NS = 10;

    reg clk;
    reg rst;
    reg pixel_tick;

    wire hsync;
    wire vsync;
    wire video_active;
    wire frame_tick;
    wire [9:0] pixel_x;
    wire [9:0] pixel_y;

    integer pixel_counter;
    integer frame_counter;
    integer error_count;

    vga_timing dut (
        .clk(clk),
        .rst(rst),
        .pixel_tick(pixel_tick),
        .hsync(hsync),
        .vsync(vsync),
        .video_active(video_active),
        .frame_tick(frame_tick),
        .pixel_x(pixel_x),
        .pixel_y(pixel_y)
    );

    always #(CLK_PERIOD_NS / 2) clk = ~clk;

    initial begin
        clk = 1'b0;
        rst = 1'b1;
        pixel_tick = 1'b0;
        pixel_counter = 0;
        frame_counter = 0;
        error_count = 0;

        #50;
        rst = 1'b0;

        repeat (800 * 525 * 2) begin
            @(posedge clk);
            pixel_tick = 1'b1;

            @(posedge clk);
            pixel_tick = 1'b0;

            pixel_counter = pixel_counter + 1;

            if (pixel_x > 10'd799) begin
                $display("ERROR: pixel_x fuera de rango. pixel_x=%0d tiempo=%0t", pixel_x, $time);
                error_count = error_count + 1;
            end

            if (pixel_y > 10'd524) begin
                $display("ERROR: pixel_y fuera de rango. pixel_y=%0d tiempo=%0t", pixel_y, $time);
                error_count = error_count + 1;
            end

            if (video_active && ((pixel_x >= 10'd640) || (pixel_y >= 10'd480))) begin
                $display("ERROR: video_active activo fuera de zona visible. x=%0d y=%0d tiempo=%0t",
                    pixel_x, pixel_y, $time);
                error_count = error_count + 1;
            end

            if (frame_tick) begin
                frame_counter = frame_counter + 1;
                $display("INFO: frame_tick detectado. cuadro=%0d tiempo=%0t",
                    frame_counter, $time);
            end
        end

        if (frame_counter != 2) begin
            $display("ERROR: se esperaban 2 frame_tick, pero se detectaron %0d", frame_counter);
            error_count = error_count + 1;
        end

        if (error_count == 0) begin
            $display("TEST PASSED: vga_timing funciona correctamente.");
        end else begin
            $display("TEST FAILED: errores detectados = %0d", error_count);
        end

        $finish;
    end

endmodule

`default_nettype wire
