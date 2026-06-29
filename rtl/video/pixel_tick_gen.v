`default_nettype none

//! @title Generador de habilitación de pixel
//! @author Grupo Maestro
//! @brief Genera una señal pixel_tick a partir del reloj principal.
//!
//! Este módulo divide el reloj de entrada mediante un contador simple.
//! Para una Nexys A7 con reloj de 100 MHz, usando DIVISOR = 4 se obtiene
//! una habilitación de pixel_tick aproximadamente cada 40 ns.
//!
//! La salida pixel_tick no es un reloj nuevo. Es una señal de habilitación
//! de un ciclo de clk que permite avanzar la lógica de video sin crear otro
//! dominio de reloj.

module pixel_tick_gen #(
    parameter DIVISOR = 4 //! Cantidad de ciclos de clk por cada pixel_tick.
)(
    input  wire clk,        //! Reloj principal del sistema.
    input  wire rst,        //! Reset síncrono activo en alto.
    output reg  pixel_tick  //! Pulso de un ciclo para avanzar un pixel.
);

    reg [7:0] tick_counter;
    always @(posedge clk) begin
        if (rst) begin
            tick_counter <= 8'd0;
            pixel_tick   <= 1'b0;
        end else begin
            if (tick_counter == DIVISOR - 1) begin
                tick_counter <= 8'd0;
                pixel_tick   <= 1'b1;
            end else begin
                tick_counter <= tick_counter + 8'd1;
                pixel_tick   <= 1'b0;
            end
        end
    end

endmodule

`default_nettype wire
