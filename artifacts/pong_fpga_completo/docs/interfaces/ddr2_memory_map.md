# Mapa de memoria DDR2 usado por firmware

## Estado de integración

La memoria DDR2 de la Nexys A7 se encuentra integrada en el Block Design mediante `mig_7series_0` y está expuesta al procesador MicroBlaze V a través del bus AXI.

El BSP reconoce la región DDR2 con el siguiente rango:

| Región | Dirección |
| --- | --- |
| Base DDR2 | `0x80000000` |
| Límite superior | `0x88000000` |
| Rango útil | `0x80000000 - 0x87FFFFFF` |
| Tamaño | 128 MiB |

## Regiones reservadas por firmware

| Región | Dirección | Uso |
| --- | ---: | --- |
| `DDR2_TEST_ADDR` | `0x80001000` | Prueba de escritura/lectura DDR2 |
| `DDR2_CONFIG_ADDR` | `0x80002000` | Configuración del juego |
| `DDR2_GAME_STATE_ADDR` | `0x80003000` | Copia del estado actual del Pong |
| `DDR2_SPRITE_BANK_ADDR` | `0x80010000` | Banco demo de sprites/patrones gráficos |
| `DDR2_FRAMEBUFFER_SHADOW` | `0x80100000` | Región reservada para framebuffer sombra |

## Prueba implementada

El firmware ejecuta una prueba de memoria al iniciar. La prueba escribe dos patrones de 256 palabras de 32 bits en DDR2 y luego los lee para verificar coincidencia.

En la salida VGA se muestra un indicador visual:

| Color | Significado |
| --- | --- |
| Verde | DDR2 pasó la prueba de escritura/lectura |
| Rojo | DDR2 falló la prueba |

## Uso actual

Actualmente la DDR2 se usa desde firmware para:

- validar lectura/escritura desde MicroBlaze V;
- almacenar una configuración básica del juego;
- guardar una copia del estado de Pong;
- reservar una región para sprites o recursos gráficos;
- reservar una región para framebuffer sombra.

## Pendiente

El firmware todavía no se ejecuta completamente desde DDR2. La integración actual valida acceso funcional a DDR2 desde C, pero queda pendiente mover secciones del linker script hacia DDR2 si se desea cumplir de forma más estricta el requisito de almacenar firmware en memoria externa.

## Secciones enlazadas en DDR2

Además del acceso por direcciones absolutas, el firmware define secciones específicas en el linker script para ubicar datos directamente en DDR2:

| Sección | Uso |
| --- | --- |
| `.ddr2_rodata` | Recursos constantes, como sprites o patrones gráficos |
| `.ddr2_data` | Datos inicializados que se deseen ubicar en DDR2 |
| `.ddr2_bss` | Variables y estructuras no inicializadas ubicadas en DDR2 |

En la validación actual se ubicaron correctamente:

| Sección | Dirección observada | Contenido |
| --- | ---: | --- |
| `.ddr2_rodata` | `0x80000000` | Sprite demo de 8x8 pixeles |
| `.ddr2_bss` | `0x80000080` | Estructura principal `game_app_t` |

La salida VGA muestra dos indicadores:

| Indicador | Significado |
| --- | --- |
| Cuadro derecho verde | La prueba de lectura/escritura DDR2 pasó |
| Cuadro izquierdo verde | Las secciones enlazadas en DDR2 están dentro del rango del MIG |

Con esta fase, la DDR2 ya se utiliza para almacenar datos reales del firmware, incluyendo recursos gráficos y estructuras del juego.
