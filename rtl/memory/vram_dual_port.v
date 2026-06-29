`default_nettype none

//! @title VRAM de doble puerto
//! @author Grupo Pong EL3313
//! @brief Implementa dos bancos de memoria de video para permitir escritura por CPU y lectura por VGA con intercambio de buffer.

module vram_dual_port #(
    parameter ADDR_WIDTH   = 15,
    parameter DATA_WIDTH   = 12,
    parameter MEMORY_DEPTH = 19200
)(
    input  wire                  clk, //! Reloj del modulo.

    input  wire                  wr_bank, //! Banco de VRAM escrito por CPU.
    input  wire                  wr_en, //! Habilitacion de escritura en VRAM.
    input  wire [ADDR_WIDTH-1:0] wr_addr, //! Direccion de escritura en VRAM.
    input  wire [DATA_WIDTH-1:0] wr_data, //! Dato escrito en VRAM.

    input  wire                  rd_bank, //! Banco de VRAM mostrado por VGA.
    input  wire [ADDR_WIDTH-1:0] rd_addr, //! Direccion de lectura de VRAM.
    output reg  [DATA_WIDTH-1:0] rd_data //! Dato leido desde VRAM.
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
