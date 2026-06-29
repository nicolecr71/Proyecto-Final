# Controles físicos del Pong

## Propósito

Este documento define el mapeo físico y lógico de los controles usados por el Pong en las FPGA Nexys A7-100T.

El Block Design mantiene el puerto lógico `INPUT_DRIVER[7:0]` mediante `axi_gpio_0`, pero las señales físicas ya no entran directamente desde `SW0` a `SW7`. En el flujo actual se usa `system_io_wrapper`, que toma botones y switches físicos, los pasa por sincronización y debounce, y entrega un bus limpio hacia el wrapper del Block Design.

## FPGA maestra

| Control físico | Pin FPGA | Función |
| --- | --- | --- |
| `CPU_RESETN` | C12 | Reset completo del sistema, activo en bajo |
| `BTNC` | N17 | Start |
| `BTNU` | M18 | Barra izquierda arriba |
| `BTNL` | P17 | Barra izquierda abajo |
| `BTNR` | M17 | Barra derecha arriba en modo local |
| `BTND` | P18 | Barra derecha abajo en modo local |
| `SW0` | J15 | Reset de partida |
| `SW15` | V10 | Selector de modo: 0 solitario, 1 multijugador SPI |

## FPGA esclava de prueba

La FPGA esclava usada en la prueba de integración SPI lee controles físicos locales y devuelve el input del jugador 2 al maestro por MISO.

| Control físico | Pin FPGA | Función |
| --- | --- | --- |
| `CPU_RESETN` | C12 | Reset completo de la esclava, activo en bajo |
| `BTNC` | N17 | Start remoto |
| `BTNR` | M17 | P2 arriba |
| `BTND` | P18 | P2 abajo |
| `SW0` | J15 | Reset de partida remoto |

Indicadores usados en la esclava de prueba:

| LED | Función |
| --- | --- |
| `LED0` | Trama SPI válida recibida desde el maestro |
| `LED1` | Estado limpio de `BTNC` / start remoto |
| `LED2` | Estado limpio de `BTNR` / P2 arriba |
| `LED3` | Estado limpio de `BTND` / P2 abajo |
| `LED4` | Estado limpio de `SW0` / reset remoto |

## Mapeo lógico en `INPUT_DRIVER[7:0]`

| Bit | Señal lógica | Fuente física en maestro |
| ---: | --- | --- |
| 0 | Barra izquierda arriba | `BTNU / M18` |
| 1 | Barra izquierda abajo | `BTNL / P17` |
| 2 | Start | `BTNC / N17` |
| 3 | Barra derecha arriba | `BTNR / M17` |
| 4 | Barra derecha abajo | `BTND / P18` |
| 5 | Modo multijugador | `SW15 / V10` |
| 6 | Reset de partida | `SW0 / J15` |
| 7 | Reservado | No usado |

## Comportamiento por modo

Con `SW15 = 0`, el firmware trabaja en modo solitario/local. En este modo no se ejecuta intercambio SPI y ambos jugadores se pueden controlar desde los botones de la FPGA maestra.

Con `SW15 = 1`, el firmware trabaja en modo multijugador. La FPGA maestra mantiene el estado oficial del juego, envía ese estado por MOSI y toma el control de P2 desde la FPGA esclava cuando recibe un paquete MISO válido.

## Reset de partida

`C12 / CPU_RESETN` reinicia completamente el sistema hardware y el procesador.

`SW0` no reinicia la FPGA completa. El firmware lo interpreta como reset de partida. En la implementación actual se convierte en un pulso lógico cuando `SW0` pasa de 0 a 1, por lo que debe volver a 0 antes de solicitar otro reset de partida.
