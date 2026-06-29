`timescale 1ns / 1ps

//! @title Sincronizador de dos flip-flops
//! @author Grupo Pong EL3313
//! @brief Sincroniza una senal asincrona al dominio de reloj principal para reducir riesgos de metastabilidad.

module sync_2ff (
    input  wire clk, //! Reloj del modulo.
    input  wire rst_n, //! Reset activo en bajo.
    input  wire async_i, //! Entrada asincrona respecto al reloj local.
    output wire sync_o //! Salida sincronizada al reloj local.
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
