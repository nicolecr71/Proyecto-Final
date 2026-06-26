`timescale 1ns / 1ps

module sync_2ff (
    input  wire clk,
    input  wire rst_n,
    input  wire async_i,
    output wire sync_o
);

    reg sync_ff1;
    reg sync_ff2;

    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            sync_ff1 <= 1'b0;
            sync_ff2 <= 1'b0;
        end else begin
            sync_ff1 <= async_i;
            sync_ff2 <= sync_ff1;
        end
    end

    assign sync_o = sync_ff2;

endmodule
