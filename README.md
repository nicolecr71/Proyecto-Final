# EL3313 Proyecto 2

Sistema embebido sobre FPGA Nexys A7-100T para el Proyecto 2 del curso EL3313.

## Alcance de este repositorio

Este repositorio contiene la parte del grupo maestro:

- MicroBlaze V con arquitectura RISC-V.
- Firmware bare-metal en C.
- Subsistema de video VGA.
- VRAM como mediador entre procesador y controlador VGA.
- Pong renderizado en VGA y controlado desde entradas físicas acondicionadas.
- Modo solitario local y modo multijugador mediante SPI maestro-esclavo.
- Integración de AXI GPIO, AXI Quad SPI, UARTLite y MIG DDR2 en el Block Design.

La microSD queda como integración pendiente según el alcance final del proyecto.

## Herramientas

- Ubuntu 22.04.5 LTS
- Vivado 2024.1
- Vitis / Vitis HLS 2024.1
- HoG
- Git / GitHub
- VSCode
- TerosHDL

## Estructura

- `src/rtl/`: módulos Verilog sintetizables.
- `sim/tb/`: bancos de prueba.
- `constraints/`: archivos XDC.
- `Top/el3313_proyecto2/`: configuración HoG.
- `scripts/`: automatización Bash/Tcl.
- `firmware/`: código C bare-metal.
- `docs/`: diagramas, decisiones de diseño e interfaces.

## Flujo HoG

```bash
./Hog/Do LIST
./Hog/Do CREATE el3313_proyecto2
```

Para el flujo actual con acondicionamiento de controles se usa el top superior `system_io_wrapper`, que instancia el wrapper del Block Design y entrega `INPUT_DRIVER[7:0]` ya sincronizado y filtrado.

## Controles principales

La documentación de controles físicos está en:

```text
docs/interfaces/controles_pong.md
```

Resumen de la FPGA maestra:

| Control | Función |
| --- | --- |
| `C12 / CPU_RESETN` | Reset completo del sistema |
| `SW0` | Reset de partida |
| `SW15` | Selector: 0 solitario, 1 multijugador SPI |
| `N17 / BTNC` | Start |
| `M18 / BTNU` | Barra izquierda arriba |
| `P17 / BTNL` | Barra izquierda abajo |
| `M17 / BTNR` | Barra derecha arriba en modo local |
| `P18 / BTND` | Barra derecha abajo en modo local |

## Convención de Commits

Formato:

```bash
tipo(alcance): descripción
```
