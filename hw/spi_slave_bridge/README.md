# Puente SPI esclavo (hardware) para la FPGA slave

## Por qué

El enlace SPI multijugador del slave usaba `axi_quad_spi_0` configurado con
`Master_mode=1` (un **maestro** SPI): generaba su propio SCK y exponía un SS de
salida en C17, sin pin **SPISEL**. Un core así **nunca puede ser esclavo** del
bus: no muestrea el SCK del master ni puede ser seleccionado por él.

Resultado: el slave nunca shifteaba → MISO inerte (P2 congelado) + nunca recibía
estado (pantalla estática). Por eso solo funcionaba la prueba standalone, que usaba
el esclavo SPI bit-banged en Verilog (`spi_game_slave_reference.v`).

Este puente vuelve a ese esclavo de hardware (siempre listo) y lo expone al
MicroBlaze por AXI GPIO, desacoplando el timing SPI del loop lento del CPU.

## Archivos

| Archivo | Qué es |
|---|---|
| `spi_game_slave_reference.v` | Esclavo SPI bit-banged comprobado (idéntico al de la prueba). |
| `spi_game_slave_bridge.v` | Wrapper: instancia el esclavo y empaqueta P2 (in) + estado (out) para AXI GPIO. |
| `apply_spi_slave_bridge.tcl` | Modifica el BD del slave: borra `axi_quad_spi_0`, agrega el puente + 3 AXI GPIO, expone los pines SPI. |
| `spi_slave_pins.xdc` | Mapeo de pines del Pmod JA (cs/sck/mosi=entradas, miso=salida). |

## Mapa de datos (CPU ↔ puente)

3 AXI GPIO de doble canal. Offsets Xilinx: ch1=`0x00`, ch2=`0x08`.

```
axi_gpio_spi_a: ch1 <- state_word0   ch2 <- state_word1     (entradas)
axi_gpio_spi_b: ch1 <- state_word2   ch2 <- state_word3     (entradas)
axi_gpio_spi_c: ch1 <- state_word4   ch2 -> p2_in_word      (ch1 in / ch2 out)

word0 = { ball_x[15:0],      ball_y[15:0]      }
word1 = { paddle_p1_y[15:0], paddle_p2_y[15:0] }
word2 = { frame_id[15:0],    elapsed_seconds[15:0] }
word3 = { score_p1, score_p2, status, winner }   (cada uno 8 bits, p1 en [31:24])
word4 = { last_point, serve_direction, flags, 7'b0, valid_seen }
p2    = { reset, start, down, up }   (bit3..bit0)
```

El firmware (`workspace_new/pong_app_slave/src/spi_game.c`) ya está reescrito para
este mapa, usando `XPAR_AXI_GPIO_SPI_{A,B,C}_BASEADDR`.

## Flujo de aplicación

1. **Modificar el BD** (en el proyecto del slave):
   ```sh
   cd Projects/el3313_proyecto2
   vivado -mode batch -source ../../hw/spi_slave_bridge/apply_spi_slave_bridge.tcl
   ```
   Revisar que `validate_bd_design` pase sin errores. Anotar las direcciones que
   imprime `report_bd_address` para confirmar los nombres de las instancias GPIO.

2. **Actualizar el XDC**: en `constraints/constraints.xdc`, borrar las 4 líneas
   viejas de `spi_rtl_0_*` y pegar el contenido de `spi_slave_pins.xdc`.

3. **Sintetizar e implementar**:
   ```tcl
   launch_runs synth_1 -jobs 4
   wait_on_run synth_1
   launch_runs impl_1 -to_step write_bitstream -jobs 4
   wait_on_run impl_1
   ```

4. **Exportar XSA + regenerar BSP** para que `xparameters.h` traiga
   `XPAR_AXI_GPIO_SPI_{A,B,C}_BASEADDR`. Si nombraste distinto las instancias,
   ajustá los nombres o definí `SPI_BRIDGE_GPIO_{A,B,C}_BASE` en los flags.

5. **Recompilar el ELF del slave** y cargar bitstream + ELF (ver memoria HW workflow).

## Fallback: pasos en la GUI de Vivado

Si el TCL falla en algún `connect_bd_net` (por nombres de pin del module ref):

1. Tools → Add Sources → agregar `spi_game_slave_reference.v` y `spi_game_slave_bridge.v`.
2. Abrir el BD. Borrar `axi_quad_spi_0` y el puerto externo `spi_rtl_0`.
3. Add IP → AXI GPIO ×3. En cada uno: **Enable Dual Channel**.
   - `axi_gpio_spi_a`, `_b`: ambos canales **All Inputs**, ancho 32.
   - `axi_gpio_spi_c`: canal 1 **All Inputs** (32), canal 2 **All Outputs** (32).
4. Add Module → `spi_game_slave_bridge`.
5. Run Connection Automation sobre los 3 `S_AXI` (Master = MicroBlaze Periph).
6. Conectar a mano:
   - `clk` ← `clk_wiz_1/clk_out1`, `rst_n` ← `rst_clk_wiz_1_100M/peripheral_aresetn`
   - `state_word0..4` → `gpio_io_i`/`gpio2_io_i` de a/a/b/b/c según el mapa
   - `axi_gpio_spi_c/gpio2_io_o` → `p2_in_word`
7. Make External los 4 pines SPI del puente; renombrarlos `spi_cs_n/spi_sck/spi_mosi/spi_miso`.
8. Validate Design → Generate Wrapper → sintetizar.

## Notas

- Reloj del puente = 100 MHz (`clk_out1`), muy por encima del SCK del master
  (ext_spi_clk/16 ≈ 6.25 MHz), así que el 2FF sync interno muestrea de sobra.
- `axi_quad_spi_1` (microSD) **no se toca**.
- El `state_valid_o` del esclavo es un pulso de 1 ciclo; por eso el puente expone
  un sticky `valid_seen` y el firmware detecta frames nuevos por cambio de `frame_id`,
  sin necesidad de cazar el pulso.
- El master (`pong_app`) no cambia: sigue siendo el maestro SPI real.
