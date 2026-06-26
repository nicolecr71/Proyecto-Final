`default_nettype none

module vram_dual_port #(
    parameter ADDR_WIDTH   = 15,
    parameter DATA_WIDTH   = 12,
    parameter MEMORY_DEPTH = 19200
)(
    input  wire                  clk,

    input  wire                  wr_bank,
    input  wire                  wr_en,
    input  wire [ADDR_WIDTH-1:0] wr_addr,
    input  wire [DATA_WIDTH-1:0] wr_data,

    input  wire                  rd_bank,
    input  wire [ADDR_WIDTH-1:0] rd_addr,
    output reg  [DATA_WIDTH-1:0] rd_data
);

    reg [DATA_WIDTH-1:0] vram_bank0 [0:MEMORY_DEPTH-1];
    reg [DATA_WIDTH-1:0] vram_bank1 [0:MEMORY_DEPTH-1];

    always @(posedge clk) begin
        if (wr_en) begin
            if (wr_bank) begin
                vram_bank1[wr_addr] <= wr_data;
            end else begin
                vram_bank0[wr_addr] <= wr_data;
            end
        end

        if (rd_bank) begin
            rd_data <= vram_bank1[rd_addr];
        end else begin
            rd_data <= vram_bank0[rd_addr];
        end
    end

endmodule

`default_nettype wire
