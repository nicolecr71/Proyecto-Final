`timescale 1ns / 1ps

module debounce #(
    parameter COUNTER_MAX   = 1000000,
    parameter COUNTER_WIDTH = 20
) (
    input  wire clk,
    input  wire rst_n,
    input  wire noisy_i,
    output reg  clean_o
);

    reg [COUNTER_WIDTH-1:0] counter;

    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            clean_o <= 1'b0;
            counter <= {COUNTER_WIDTH{1'b0}};
        end else begin
            if (noisy_i == clean_o) begin
                counter <= {COUNTER_WIDTH{1'b0}};
            end else begin
                if (counter == COUNTER_MAX[COUNTER_WIDTH-1:0]) begin
                    clean_o <= noisy_i;
                    counter <= {COUNTER_WIDTH{1'b0}};
                end else begin
                    counter <= counter + {{(COUNTER_WIDTH-1){1'b0}}, 1'b1};
                end
            end
        end
    end

endmodule
