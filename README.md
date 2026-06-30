# Proyecto Pong FPGA Esclava - Nexys A7-100T

## Descripción del proyecto

Este repositorio contiene la parte correspondiente a la **FPGA esclava** del Proyecto 2. El sistema forma parte de un Pong multijugador implementado sobre Nexys A7-100T, usando firmware en C, comunicación SPI, periféricos de entrada, memoria local y una estructura modular compatible con la FPGA maestra.

La FPGA esclava se encarga de leer los controles del jugador 2 y enviarlos a la FPGA maestra mediante SPI. La maestra mantiene el estado oficial del juego, actualiza la lógica principal y genera la salida VGA. En este caso, la esclava funciona como una entrada remota implementada sobre FPGA.

El firmware de la esclava conserva una base común con los modos local, maestro y esclavo. Esto permite probar la lógica del juego por separado y mantener una integración ordenada con el sistema completo.

## Integrantes

- Gerson Adrián Cordero Zúñiga
- Keilin Tatiana Loaisiga Tellez
- Nicole Irina Corrales Rodríguez

## Alcance del repositorio

Este repositorio corresponde a la sección de la **FPGA esclava**. Los elementos principales incluidos y documentados son:

```text
- Sistema esclavo sobre Nexys A7-100T.
- Firmware en lenguaje C.
- Lectura de botones y switches locales.
- Preparación de entradas del jugador 2.
- Comunicación SPI con la FPGA maestra.
- Construcción y validación de paquetes.
- Soporte de modos local, maestro y esclavo en la lógica común.
- Pruebas en PC usando stubs.
- Reporte de recursos, latencia y reproducibilidad.
```

La salida VGA principal, la carga final de recursos gráficos y el estado oficial del juego corresponden a la FPGA maestra.

## Estado validado

La parte esclava fue preparada para trabajar con la FPGA maestra mediante SPI. Se validaron principalmente los módulos de software relacionados con entradas, paquetes y modos de juego.

```text
- Lectura de entradas locales.
- Conversión de bits a controles de jugador.
- Modo local.
- Modo maestro.
- Modo esclavo.
- Construcción de paquetes de entrada.
- Construcción de paquetes de estado.
- Validación por checksum.
- Rechazo de paquetes inválidos.
- Simulación de envío y recepción usando stubs.
```

## Arquitectura general de la FPGA esclava

El flujo general de la FPGA esclava es:

```text
Botones / switches
        ↓
Input Driver
        ↓
Entrada del jugador 2
        ↓
Game Packet
        ↓
SPI Game
        ↓
FPGA maestra
```

En modo esclavo, la FPGA secundaria no decide el estado oficial de la partida. Su función es capturar las entradas locales, convertirlas en un paquete y enviarlas a la maestra. Si la maestra devuelve el estado oficial del juego, la esclava puede copiarlo localmente para mantenerse sincronizada.

## Diagrama de bloques

El diagrama de bloques del sistema se encuentra en el siguiente link:

```text
https://lucid.app/lucidspark/0ef90538-2468-44be-9708-132ea4711c6b/edit?viewport_loc=-5425%2C4150%2C8538%2C4069%2C0_0&invitationId=inv_f18cc9a0-747b-4162-b2db-b39aa12685f2
```

## Módulos principales del firmware

| Módulo | Función principal |
| ------ | ----------------- |
| `game_config.h` | Constantes generales del juego. |
| `player_input.h` | Estructura de entrada de jugador. |
| `game_state.h` | Estado general del Pong. |
| `input_driver.c/h` | Convierte bits de botones y switches en controles. |
| `game_logic.c/h` | Movimiento, colisiones, puntaje y estados del juego. |
| `game_app.c/h` | Coordina los modos local, maestro y esclavo. |
| `game_packet.c/h` | Construye y valida paquetes de entrada y estado. |
| `spi_game.c/h` | Interfaz SPI y stubs para pruebas. |
| `game_background.c/h` | Interfaz base para recursos visuales o fondo. |

La división por módulos facilita probar partes individuales antes de la integración con Vivado, Vitis y el hardware final.

## Comunicación SPI esclava

En el modo multijugador, la maestra genera el reloj SPI y selecciona a la esclava. La esclava responde enviando las entradas del jugador 2.

```text
SCK   maestro -> esclava
MOSI  maestro -> esclava
MISO  esclava -> maestra
SS/CS maestro -> esclava
GND   referencia común
```

La línea MISO es la más importante desde el lado de la esclava, porque por ella se envían los datos del jugador 2 hacia la maestra. Ambas placas deben compartir GND. No se debe conectar 3.3 V entre placas si cada una está alimentada por USB.

## Reporte de latencia

La latencia entre las dos FPGA tiene dos partes: la transferencia SPI y la latencia visible en pantalla.

Para el enlace SPI se usó:

```text
SCK = 100 MHz / 16 = 6.25 MHz
Duración por bit = 160 ns
Paquete = 24 bytes = 192 bits
Tiempo SPI puro = 192 × 160 ns = 30.7 us
```

Considerando el manejo por software, FIFO, selección de esclavo y sondeo, la latencia práctica de la transacción SPI se estima alrededor de:

```text
40 us a 55 us
```

La latencia jugador-a-pantalla depende de cuándo la maestra actualiza el juego y cuándo el VGA refresca la imagen. A 60 Hz:

```text
T_frame = 1 / 60 Hz ≈ 16.67 ms
```

Por eso, la respuesta visible del jugador 2 puede reflejarse aproximadamente entre 1 y 2 frames:

```text
Latencia percibida ≈ 16.7 ms a 33 ms
```

Resumen:

| Etapa | Latencia aproximada |
| ----- | ------------------: |
| Transacción SPI pura | 30.7 us |
| Transacción SPI práctica | 40 us a 55 us |
| Latencia visible | 16.7 ms a 33 ms |

## Reporte de recursos

Los recursos corresponden al reporte de implementación de la FPGA esclava, con diseño `system_io_wrapper`, dispositivo Artix-7 `xc7a100tcsg324-1`.

| Recurso | Usado | Disponible | Utilización |
| ------ | ----: | ---------: | ----------: |
| Slice LUTs | 7 979 | 63 400 | 12.59 % |
| LUT como lógica | 7 304 | 63 400 | 11.52 % |
| LUT como memoria | 675 | 19 000 | 3.55 % |
| Slice Registers (FF) | 8 357 | 126 800 | 6.59 % |
| Slices ocupados | 3 207 | 15 850 | 20.23 % |
| Block RAM (RAMB36) | 56 | 135 | 41.48 % |
| DSPs | 0 | 240 | 0 % |
| IOB (pines) | 80 | 210 | 38.10 % |
| Relojes (BUFGCTRL) | 9 | 32 | 28.13 % |
| MMCM / PLL | 2 / 1 | 6 / 6 | 33.3 % / 16.7 % |

La lectura rápida del reporte es que el recurso más exigido es la Block RAM, principalmente por memorias internas y memoria local del sistema. La lógica tiene bastante margen, con cerca de 13 % de LUTs y 7 % de registros. No se usan DSPs porque el Pong no requiere operaciones matemáticas pesadas.

## Pruebas realizadas

Se realizaron pruebas para revisar:

```text
- Movimiento de paletas.
- Movimiento de pelota.
- Rebotes contra bordes.
- Colisiones con paletas.
- Anotación de puntos.
- Reinicio de ronda.
- Estados de partida.
- Modo local.
- Modo maestro.
- Modo esclavo.
- Paquetes de entrada.
- Paquetes de estado.
- Checksum.
- Rechazo de paquetes inválidos.
- Simulación de SPI usando stubs.
```

## Compilación de pruebas en PC

Ejemplo de compilación en Linux:

```bash
gcc -Wall -Wextra -std=c11 \
    -I sw/common \
    sw/common/game_logic.c \
    sw/common/game_app.c \
    sw/common/input_driver.c \
    sw/common/game_packet.c \
    sw/common/spi_game.c \
    sw/test/test_game_logic.c \
    -o test_pong

./test_pong
```

Estas pruebas permiten revisar la lógica antes de llevarla completamente a hardware.

## Cómo reproducir el proyecto

Para reproducir el proyecto se necesita **Vivado y Vitis 2024.1** y **dos FPGAs Nexys A7-100T**, una que funciona como maestro y otra como esclavo, conectadas entre sí por el conector **Pmod JA**.

Primero clona el repositorio incluyendo sus submódulos (el framework HoG viene como submódulo, asi que es necesario descargarlo junto con el resto) y ve a la rama `main`, que contiene la versión completa del proyecto.

La forma más rápida de ponerlo en marcha es usar los **binarios precompilados** que están en la carpeta `artifacts/`: ahí se encuentran los bitstreams y los firmwares (`.elf`) tanto del maestro como del esclavo, junto con la configuración y los sprites. Solo hay que programar cada FPGA con su bitstream correspondiente y cargar su firmware por JTAG, usando los scripts de la carpeta `scripts/tcl/debug/` (hay un script para cada placa, identificada por su número de serie).

Si en cambio se quiere **compilar todo desde cero**, el hardware se genera con HoG a partir de la configuración del proyecto, y el firmware se compila en Vitis creando una plataforma a partir del archivo de hardware exportado (`el3313_proyecto2_system_wrapper.xsa`) e importando las aplicaciones que están en `workspace_new/`.

Una vez cargadas ambas FPGAs, el modo de juego se elige con el interruptor **`SW15`** en las dos placas: en `0` se juega en modo **local** (dos jugadores en una misma FPGA) y en `1` se activa el modo **multijugador por SPI**, donde el segundo jugador se controla desde la FPGA esclava. El resto de controles (start, reset y las barras) se manejan con los botones y switches de la placa maestra.

## Enlaces

Repositorio del grupo:

```text
https://github.com/nicolecr71/Proyecto-Final
```

Chats compartidos utilizados reporte de IA:

```text
https://chatgpt.com/share/6a41f2e5-ad0c-83e8-b652-fdc6c690ef05
https://chatgpt.com/share/6a4200b3-bbf0-83e8-9901-11ba4d9b90f9
https://chatgpt.com/share/6a42c87b-8cfc-83e8-a823-677156f10351
```

## Estado actual

La FPGA esclava cuenta con una base de firmware preparada para leer entradas, construir paquetes y validar el comportamiento de los modos de juego. La integración final se realiza mediante SPI con la FPGA maestra.

## Mejoras futuras

```text
- Integrar completamente el driver SPI real en Vitis.
- Agregar depuración por UART.
- Medir la latencia real con analizador lógico.
- Documentar el cableado físico entre Pmods.
- Agregar indicadores de estado para la conexión SPI.
```

## Conclusión

La FPGA esclava permite extender el Pong a modo multijugador. Aunque no mantiene la salida VGA principal, cumple una función importante: capturar las entradas del jugador remoto y enviarlas a la FPGA maestra de forma ordenada y validada.


El video del proyecto se encuentra en el siguiente link:
https://youtu.be/ioy0nAySmRk
