# Mapa de memoria de VRAM e interfaz de entrada

## Propósito

Este documento define el contrato de direccionamiento para la memoria de video del proyecto y la interfaz de entrada utilizada por el procesador.

La VRAM funciona como intermediario entre el procesador MicroBlaze V y el controlador VGA. El procesador escribe datos de color en memoria mediante AXI, y el sistema VGA lee esos datos continuamente para generar la imagen en pantalla.

Además, el diseño integra un bloque AXI GPIO de 8 bits llamado `INPUT_DRIVER[7:0]`, utilizado como entrada digital para el firmware.

## Resolución lógica de VRAM

La salida VGA trabaja con resolución visible de 640x480 pixeles. Para reducir el uso de BRAM, la VRAM usa una resolución lógica menor:

| Parámetro             |       Valor |
| --------------------- | ----------: |
| Ancho lógico          | 160 pixeles |
| Alto lógico           | 120 pixeles |
| Pixeles totales       |      19 200 |
| Escala VGA            |         4x4 |
| Formato de color      |      RGB444 |
| Bits útiles por pixel |     12 bits |

Cada pixel lógico de VRAM representa un bloque de 4x4 pixeles en la salida VGA.

## Formato de color RGB444

Cada pixel usa 12 bits:

| Bits   | Campo |
| ------ | ----- |
| [11:8] | Rojo  |
| [7:4]  | Verde |
| [3:0]  | Azul  |

## Dirección interna de hardware

La VRAM usa una dirección lineal:

```text
addr = y * 160 + x
```

Donde:

```text
x = 0..159
y = 0..119
addr = 0..19199
```

## Dirección desde firmware

Para facilitar la integración con AXI, cada pixel se mapea como una palabra de 32 bits.

Aunque el color útil usa solo 12 bits, el procesador escribe una palabra completa:

```text
bits [11:0]  = RGB444
bits [31:12] = reservado
```

El desplazamiento en bytes desde firmware es:

```text
offset = (y * 160 + x) * 4
```

Por tanto:

```text
direccion_pixel = VRAM_BASE_ADDR + offset
```

## Base address real de VRAM

La dirección base de la VRAM es asignada por Vivado en el Address Editor. En la integración actual con MicroBlaze V, el periférico `video_vram_axi_core_0` quedó mapeado en:

```text
XPAR_VIDEO_VRAM_AXI_CORE_0_BASEADDR = 0x00020000
XPAR_VIDEO_VRAM_AXI_CORE_0_HIGHADDR = 0x0003FFFF
```

Por tanto, en firmware se debe usar preferiblemente la macro generada en `xparameters.h`:

```c
#define VRAM_BASE_ADDR XPAR_VIDEO_VRAM_AXI_CORE_0_BASEADDR
```

Como respaldo, el valor fijo correspondiente es:

```text
VRAM_BASE_ADDR = 0x00020000
```

## Mapa general de memoria relevante

| Rango                   | Uso                                        |
| ----------------------- | ------------------------------------------ |
| 0x00000000 - 0x0001FFFF | Memoria local BRAM del MicroBlaze V        |
| 0x00020000 - 0x0003FFFF | `video_vram_axi_core_0` / VRAM por AXI     |
| 0x40000000 - 0x4000FFFF | `axi_gpio_0` / entrada `INPUT_DRIVER[7:0]` |
| 0x40600000 - 0x4060FFFF | `axi_uartlite_0`                           |
| 0x44A00000 - 0x44A0FFFF | `axi_quad_spi_0`                           |
| 0x80000000 - 0x87FFFFFF | `mig_7series_0` / DDR2 externa             |

Las direcciones exactas deben consultarse en el `xparameters.h` generado por Vitis después de exportar el `.xsa`. Normalmente aparecen como macros similares a:

```c
XPAR_AXI_GPIO_0_BASEADDR
XPAR_AXI_QUAD_SPI_0_BASEADDR
XPAR_AXI_UARTLITE_0_BASEADDR
XPAR_MIG_7SERIES_0_BASEADDR
```

## Interfaz `INPUT_DRIVER[7:0]`

El diseño integra un bloque `AXI GPIO` configurado como entrada de 8 bits:

| Parámetro          | Valor               |
| ------------------ | ------------------- |
| Bloque             | `axi_gpio_0`        |
| Tipo               | AXI GPIO            |
| Dirección del GPIO | Entrada             |
| Ancho              | 8 bits              |
| Puerto lógico      | `INPUT_DRIVER[7:0]` |

En el top actual, el puerto lógico `INPUT_DRIVER[7:0]` no se conecta directamente a switches físicos. Primero se usa `system_io_wrapper`, que instancia `input_conditioner` para sincronizar y filtrar las entradas mediante `sync_2ff` y `debounce`.

| Señal lógica | Entrada física | Pin FPGA | Función |
| --- | --- | --- | --- |
| `INPUT_DRIVER[0]` | `BTNU` | M18 | Barra izquierda arriba |
| `INPUT_DRIVER[1]` | `BTNL` | P17 | Barra izquierda abajo |
| `INPUT_DRIVER[2]` | `BTNC` | N17 | Start |
| `INPUT_DRIVER[3]` | `BTNR` | M17 | Barra derecha arriba |
| `INPUT_DRIVER[4]` | `BTND` | P18 | Barra derecha abajo |
| `INPUT_DRIVER[5]` | `SW15` | V10 | Selector de modo multijugador |
| `INPUT_DRIVER[6]` | `SW0` | J15 | Reset de partida |
| `INPUT_DRIVER[7]` | No usado | - | Reservado |

`C12 / CPU_RESETN` no forma parte de `INPUT_DRIVER[7:0]`; es el reset global del sistema.

## Relación con módulos RTL e IP

| Módulo o bloque              | Función                                                    |
| ---------------------------- | ---------------------------------------------------------- |
| `vram_dual_port.v`           | Memoria de video de doble puerto                           |
| `vram_read_addr_gen.v`       | Convierte coordenadas VGA 640x480 a dirección VRAM 160x120 |
| `vram_test_pattern_writer.v` | Escribe una escena de prueba en VRAM                       |
| `vram_cpu_write_adapter.v`   | Convierte coordenadas CPU x,y a dirección lineal de VRAM   |
| `axi_lite_vram_writer.v`     | Permite escritura en VRAM desde AXI-Lite                   |
| `video_vram_axi_core.v`      | IP principal que integra AXI-Lite, VRAM y salida VGA       |
| `axi_gpio_0`                 | Entrada AXI GPIO de 8 bits para `INPUT_DRIVER[7:0]`        |
| `system_io_wrapper.v`        | Top superior que acondiciona entradas físicas y conecta el wrapper del BD |
| `input_conditioner.v`        | Sincroniza y filtra botones/switches antes del AXI GPIO    |
| `sync_2ff.v`                 | Sincronizador de dos flip-flops para entradas asíncronas   |
| `debounce.v`                 | Filtro de rebote por contador                              |

## Estado de integración

La integración actual incluye:

* MicroBlaze V.
* Bus AXI.
* VRAM accesible por AXI.
* Controlador VGA.
* AXI GPIO de entrada de 8 bits.
* Acondicionamiento de controles físicos por `system_io_wrapper`.
* Salidas VGA `VGA_R`, `VGA_G`, `VGA_B`, `VGA_HS` y `VGA_VS`.
* MIG DDR2 mapeado en el espacio de datos del procesador.
* AXI Quad SPI mapeado en el espacio de datos del procesador.
* AXI UARTLite mapeado en el espacio de datos del procesador.
