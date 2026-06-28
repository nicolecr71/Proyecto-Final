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

    (* ram_style = "block" *) reg [DATA_WIDTH-1:0] vram_bank0 [0:MEMORY_DEPTH-1];
    (* ram_style = "block" *) reg [DATA_WIDTH-1:0] vram_bank1 [0:MEMORY_DEPTH-1];

    reg [DATA_WIDTH-1:0] bank0_rd_data;
    reg [DATA_WIDTH-1:0] bank1_rd_data;
    reg                  rd_bank_d;

    /*
     * Separate always blocks per bank → Vivado infiere 2 Simple Dual Port BRAMs.
     * Ambos bancos se leen cada ciclo; el MUX final selecciona cuál mostrar.
     * Esto evita la inferencia de LUTRAM distribuida que violaba timing a 100 MHz.
     */
    always @(posedge clk) begin
        if (wr_en && !wr_bank)
            vram_bank0[wr_addr] <= wr_data;
        bank0_rd_data <= vram_bank0[rd_addr];
    end

    always @(posedge clk) begin
        if (wr_en && wr_bank)
            vram_bank1[wr_addr] <= wr_data;
        bank1_rd_data <= vram_bank1[rd_addr];
    end

    /* Pipeline de selección: rd_bank_d alinea el banco con los datos leídos. */
    always @(posedge clk) begin
        rd_bank_d <= rd_bank;
        rd_data   <= rd_bank_d ? bank1_rd_data : bank0_rd_data;
    end

endmodule

`default_nettype wire
