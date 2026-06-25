# Prueba de integración SPI con dos FPGA

## Objetivo

Validar la comunicación SPI real entre dos FPGA Nexys A7-100T para el proyecto Pong maestro-esclavo.

## Configuración probada

- FPGA maestra: ejecuta el juego Pong, genera VGA y controla el estado oficial del juego.
- FPGA esclava: recibe el estado del juego por MOSI y devuelve los controles del jugador 2 por MISO.
- Protocolo: SPI Mode 0, 8 bits, MSB first, CS activo en bajo.
- Tamaño de trama: 24 bytes.
- Selector de modo en la maestra: `SW15 = 1` activa el intercambio SPI.

## Conexión física

| Maestro | Esclavo | Señal |
|---|---|---|
| JA1 | JA1 | CS / SS |
| JA2 | JA2 | MOSI |
| JA3 | JA3 | MISO |
| JA4 | JA4 | SCLK |
| GND | GND | Tierra común |

No se conectó 3.3 V entre placas, ya que ambas estaban alimentadas por USB.

## Resultado

La prueba fue exitosa. La FPGA maestra ejecutó el Pong en VGA y la FPGA esclava controló la paleta del jugador 2 mediante botones físicos locales.

## Controles usados en la FPGA maestra

| Control físico | Función |
|---|---|
| `SW15` | Selector: 0 solitario, 1 multijugador SPI |
| `SW0` | Reset de partida |
| `BTNC / N17` | Start |
| `BTNU / M18` | Barra izquierda arriba |
| `BTNL / P17` | Barra izquierda abajo |
| `BTNR / M17` | Barra derecha arriba en modo local |
| `BTND / P18` | Barra derecha abajo en modo local |
| `CPU_RESETN / C12` | Reset completo del sistema |

## Controles usados en la FPGA esclava

| Control físico esclavo | Función |
|---|---|
| `BTNC / N17` | Start remoto |
| `BTNR / M17` | P2 arriba |
| `BTND / P18` | P2 abajo |
| `SW0 / J15` | Reset de partida remoto |
| `CPU_RESETN / C12` | Reset completo de la esclava |

Indicadores usados en la esclava:

| LED esclavo | Función |
|---|---|
| LED0 | Trama SPI válida recibida |
| LED1 | Estado limpio de start remoto |
| LED2 | Estado limpio de P2 arriba |
| LED3 | Estado limpio de P2 abajo |
| LED4 | Estado limpio de reset remoto |

## Conclusión

Se validó la comunicación bidireccional SPI entre dos FPGA reales. El maestro envió el estado oficial del juego y recibió correctamente los controles del jugador 2 desde la FPGA esclava. También se validó el cambio de controles físicos desde switches hacia botones con sincronización y debounce.
