`timescale 1ns/1ps
`default_nettype none

module tb_pixel_tick_gen;

    localparam CLK_PERIOD_NS = 10;
    localparam DIVISOR_TB    = 4;

    reg clk;
    reg rst;
    wire pixel_tick;

    integer cycle_count;
    integer tick_count;
    integer error_count;

    pixel_tick_gen #(
        .DIVISOR(DIVISOR_TB)
    ) dut (
        .clk(clk),
        .rst(rst),
        .pixel_tick(pixel_tick)
    );

    always #(CLK_PERIOD_NS / 2) clk = ~clk;

    initial begin
        clk = 1'b0;
        rst = 1'b1;

        cycle_count = 0;
        tick_count = 0;
        error_count = 0;

        repeat (5) @(posedge clk);
        rst = 1'b0;

        repeat (32) begin
            @(posedge clk);
            cycle_count = cycle_count + 1;

            if (pixel_tick) begin
                tick_count = tick_count + 1;

                if ((cycle_count % DIVISOR_TB) != 0) begin
                    $display("ERROR: pixel_tick fuera del ciclo esperado. ciclo=%0d tiempo=%0t",
                        cycle_count, $time);
                    error_count = error_count + 1;
                end
            end
        end

        if (tick_count != 8) begin
            $display("ERROR: se esperaban 8 ticks, pero se detectaron %0d", tick_count);
            error_count = error_count + 1;
        end

        if (error_count == 0) begin
            $display("TEST PASSED: pixel_tick_gen funciona correctamente.");
        end else begin
            $display("TEST FAILED: errores detectados = %0d", error_count);
        end

        $finish;
    end

endmodule

`default_nettype wire
