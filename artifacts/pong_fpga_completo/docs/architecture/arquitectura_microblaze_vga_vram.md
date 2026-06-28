# Arquitectura MicroBlaze V + VRAM + VGA

## Propósito

Este documento describe la arquitectura implementada para la integración entre el procesador MicroBlaze V, el bus AXI, la memoria de video VRAM, la salida VGA y la entrada digital mediante AXI GPIO.

Esta arquitectura forma parte del sistema embebido del proyecto Pong sobre FPGA Nexys A7-100T. La función principal de este bloque es permitir que el firmware ejecutado en MicroBlaze V pueda escribir información gráfica en una memoria de video, mientras un controlador VGA lee esa memoria para generar imagen en pantalla.

## Componentes principales

| Componente | Función |
| --- | --- |
| `system_io_wrapper` | Top superior usado en el flujo actual; acondiciona controles físicos y conecta el wrapper del Block Design. |
| `input_conditioner` | Sincroniza y filtra botones/switches antes de entregar `INPUT_DRIVER[7:0]`. |
| `sync_2ff` | Sincronización de entradas asíncronas al reloj de sistema. |
| `debounce` | Filtro de rebote para botones y switches usados como control. |
| `microblaze_riscv_0` | Procesador MicroBlaze V basado en RISC-V. |
| `microblaze_riscv_0_local_memory` | Memoria local BRAM para instrucciones y datos del procesador. |
| `microblaze_riscv_0_axi_periph` | Interconexión AXI entre MicroBlaze y periféricos. |
| `video_vram_axi_core_0` | Núcleo de video con interfaz AXI, VRAM y salida VGA. |
| `axi_gpio_0` | Entrada digital de 8 bits para `INPUT_DRIVER[7:0]`. |
| `mig_7series_0` | Controlador DDR2 externo mediante MIG. |
| `axi_quad_spi_0` | Periférico SPI para comunicación con la otra FPGA. |
| `axi_uartlite_0` | UARTLite para depuración desde firmware. |
| `clk_wiz_1` | Generación de reloj interno. |
| `rst_clk_wiz_1_100M` | Sistema de reset sincronizado. |
| `mdm_1` | Módulo de depuración para MicroBlaze. |

## Flujo general del sistema

El sistema funciona de la siguiente manera:

1. Las entradas físicas de botones y switches llegan a `system_io_wrapper`.
2. `input_conditioner` sincroniza y filtra esas señales.
3. El bus limpio `INPUT_DRIVER[7:0]` entra al AXI GPIO del Block Design.
4. El procesador MicroBlaze V ejecuta firmware bare-metal.
5. El firmware lee los controles mediante AXI GPIO.
6. El firmware actualiza el estado del juego y escribe datos de color en la VRAM mediante el bus AXI.
7. La VRAM almacena pixeles en formato RGB444.
8. El controlador VGA lee continuamente la VRAM.
9. La salida VGA genera las señales `VGA_R`, `VGA_G`, `VGA_B`, `VGA_HS` y `VGA_VS`.
10. En modo multijugador, el firmware intercambia estado e input remoto mediante `axi_quad_spi_0`.

## Relación procesador - memoria - video

La VRAM funciona como una memoria compartida entre dos partes del sistema:

* El MicroBlaze escribe pixeles en la VRAM.
* El controlador VGA lee pixeles desde la VRAM.

Esto permite separar la lógica de procesamiento del juego de la lógica de generación de video. El procesador no genera directamente las señales VGA; solamente actualiza la memoria de video. El núcleo de video se encarga de convertir esa memoria en imagen visible.

## Resolución de video

La salida VGA visible es de 640x480 pixeles. Sin embargo, la VRAM utiliza una resolución lógica de 160x120 pixeles para reducir el consumo de memoria BRAM.

Cada pixel lógico representa un bloque de 4x4 pixeles físicos en pantalla.

| Parámetro              |   Valor |
| ---------------------- | ------: |
| Resolución VGA visible | 640x480 |
| Resolución lógica VRAM | 160x120 |
| Escala                 |     4x4 |
| Pixeles lógicos        |  19 200 |
| Formato de color       |  RGB444 |

## Bus AXI

El bus AXI permite que el MicroBlaze acceda a periféricos internos del diseño. En esta integración, el MicroBlaze accede principalmente a:

* `video_vram_axi_core_0`, para escribir en la memoria de video.
* `axi_gpio_0`, para leer las entradas digitales `INPUT_DRIVER[7:0]`.
* `mig_7series_0`, para acceder a memoria DDR2 externa.
* `axi_quad_spi_0`, para la comunicación SPI con la otra FPGA.
* `axi_uartlite_0`, para depuración por UART.

La dirección base de cada periférico es generada por Vivado y queda disponible para el firmware mediante `xparameters.h`.

## Entrada `INPUT_DRIVER`

El diseño incluye un bloque AXI GPIO configurado como entrada de 8 bits. Esta entrada está expuesta lógicamente como:

```text
INPUT_DRIVER[7:0]
```

En el top actual, estos bits no se conectan directamente a `SW0`-`SW7`. El puerto físico se genera a partir de botones y switches acondicionados por hardware:

| Bit | Fuente física | Función |
| ---: | --- | --- |
| 0 | `BTNU / M18` | Barra izquierda arriba |
| 1 | `BTNL / P17` | Barra izquierda abajo |
| 2 | `BTNC / N17` | Start |
| 3 | `BTNR / M17` | Barra derecha arriba |
| 4 | `BTND / P18` | Barra derecha abajo |
| 5 | `SW15 / V10` | Selector de modo multijugador |
| 6 | `SW0 / J15` | Reset de partida |
| 7 | No usado | Reservado |

`C12 / CPU_RESETN` se mantiene como reset global del sistema y no se decodifica como entrada del juego.

## Estado de integración

La arquitectura fue probada en hardware real. Se programó la FPGA con el bitstream generado desde el diseño integrado y se cargó un firmware bare-metal en MicroBlaze V. El sistema mostró el Pong por VGA, confirmando la integración entre procesador, bus AXI, VRAM y salida VGA.

También se validó el AXI GPIO de entrada con controles físicos acondicionados por `system_io_wrapper`.

El Block Design actual incluye `mig_7series_0`, `axi_quad_spi_0` y `axi_uartlite_0`. El modo multijugador por SPI fue probado con dos FPGA: la maestra ejecuta el juego y recibe el input de P2 desde la esclava. La DDR2 está integrada y mapeada, pero el juego actual no depende de ella para almacenar el estado principal del Pong.
