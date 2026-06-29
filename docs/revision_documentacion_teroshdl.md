# Revision de documentacion de codigo

Esta revision aplica una documentacion sobria, pensada para cumplir con TerosHDL en HDL y con buena practica de documentacion en C, sin sobrecomentar la implementacion.

## Criterio aplicado

- En Verilog se usan comentarios `//!` donde TerosHDL los reconoce.
- Cada modulo principal tiene `@title`, `@author` y `@brief`.
- Los comentarios se concentran en interfaces, parametros, proposito del modulo y decisiones no obvias.
- No se comentan asignaciones o instrucciones evidentes.
- No se modifico la logica funcional del proyecto.

## Archivos HDL revisados

- `rtl/axi/axi_lite_vram_writer.v`
- `rtl/io/debounce.v`
- `rtl/io/sync_2ff.v`
- `rtl/io/input_conditioner.v`
- `rtl/memory/vram_dual_port.v`
- `rtl/top/system_io_wrapper.v`
- `rtl/top/video_vram_axi_core.v`
- `rtl/video/*.v`
- `ip/video_vram_axi_core/src/*.v`
- `hw/spi_slave_bridge/*.v`

## Archivos C revisados

- `sw/common/game_app.c`
- `sw/common/game_logic.c`
- `sw/common/game_packet.c`
- `sw/common/game_params.c`
- `sw/common/input_driver.c`
- `sw/common/pong_renderer.c`
- `sw/common/sd_card.c`
- `sw/common/sd_loader.c`
- `sw/common/spi_game.c`
- `sw/microblaze/src/main.c`

## Recomendacion para la entrega

No agregar comentarios linea por linea. La documentacion debe explicar responsabilidad del modulo, interfaz, condiciones de uso e integracion con otros bloques. El codigo debe seguir siendo legible por nombres descriptivos e indentacion consistente.
