# EL3313 — Proyecto 2: Pong sobre FPGA (Grupo Maestro)

Sistema embebido bare-metal sobre **FPGA Nexys A7-100T** que implementa el juego **Pong**
con salida VGA, controles físicos y **modo multijugador maestro–esclavo vía SPI** entre dos FPGAs.

> Este README está pensado para que cualquier compañero que reciba el paquete tenga **todo el
> contexto** para entender, compilar, cargar y continuar el proyecto.

---

## 1. Resumen del proyecto

- **Curso:** EL3313 — Taller de Diseño Digital, I Semestre 2026 (Prof. Luis G. León-Vega).
- **Plataforma:** Nexys A7-100T (Artix-7 `xc7a100tcsg324-1`).
- **Procesador:** MicroBlaze V (ISA **RISC-V**), bare-metal en C.
- **Video:** VGA 640×480 generada desde un framebuffer lógico 160×120 (RGB444), doble buffer.
- **Memoria:** DDR2 vía MIG (firmware + framebuffer + sprites + variables del juego).
- **Comunicación entre FPGAs:** AXI Quad SPI sobre el conector **Pmod JA**.
- **Almacenamiento:** microSD (FAT32, FatFs) para sprites/recursos — integración parcial.

Hay **dos FPGAs** que corren firmware distinto:

| Rol | Serial JTAG | Qué hace |
|-----|-------------|----------|
| **Maestro** | `210292BB3406` | Corre la lógica del juego, genera SCK/CS/MOSI, recibe input de P2 por MISO |
| **Esclavo** | `210292BB3145` | Lee controles de P2 y los envía por MISO; recibe el estado del juego por MOSI |

`SW15` selecciona en ambas FPGAs el modo: **0 = solitario local**, **1 = multijugador SPI**.

---

## 2. Estado funcional actual

✅ Funcionando:
- VGA estable con doble buffer (sin parpadeo fuerte).
- Pong **local** (dos jugadores en la misma FPGA).
- Pong **multijugador SPI** (P2 controlado desde la FPGA esclava).
- DDR2 probada y usada desde firmware (firmware en `0x80200000`, estado del juego en `0x80000000`).
- Pacing por **vsync** en el modo multijugador del esclavo (corrige parpadeo) — último fix aplicado.

⚠️ Puntos abiertos / a verificar:
- **Imagen de la FPGA esclava**: tras reconstruir el bitstream del esclavo para corregir el SPI
  (ver §6), hubo una regresión de imagen en algún build. Verificar que el bitstream del esclavo
  en `artifacts/pong_slave.bit` muestra imagen correctamente y que el fix de MISO sigue activo.
- **microSD**: el código (`sd_loader.c`, FatFs) se inicializa y carga recursos si la SD está
  presente, pero la integración completa de recursos gráficos desde SD queda como pendiente.

---

## 3. Estructura del repositorio

```
.
├── rtl/                     # HDL sintetizable (Verilog)
│   ├── top/                 #   top-level: system_io_wrapper (instancia el BD + acondiciona controles)
│   ├── axi/  io/  memory/   #   puentes AXI, drivers de IO, memoria
│   ├── video/  vram/        #   subsistema de video y VRAM
├── ip/video_vram_axi_core/  # IP personalizado de video (VRAM ↔ VGA)
├── sim/tb/                  # bancos de prueba
├── constraints/             # XDC (pines, reloj)
├── Top/el3313_proyecto2/    # configuración HoG (hog.conf, listas de fuentes)
├── Hog/                     # framework HoG (submódulo)
├── scripts/tcl/             # automatización Vivado/XSCT
│   └── debug/               #   programar bitstream y cargar ELF por JTAG
├── hw/spi_slave_bridge/     # scripts TCL del puente SPI del esclavo (reconstrucción BD)
├── firmware/                # (versión histórica del firmware C bare-metal)
├── workspace_new/           # workspace Vitis ACTUAL
│   ├── pong_app/            #   firmware MAESTRO (game logic, renderer, SPI, SD)
│   ├── pong_app_slave/      #   firmware ESCLAVO
│   ├── el3313_platform/     #   plataforma + BSP (compartida master/slave)
│   └── pong_app_system/     #   system project Vitis
├── artifacts/               # bitstreams (.bit), firmware (.elf) y binarios (.bin) precompilados
├── docs/                    # arquitectura, interfaces, reportes
└── README.md                # este archivo
```

> **Nota:** carpetas como `Projects/`, `bin/`, `workspace/`, `bd_check/`, `.Xil/`, logs de Vivado
> y las entregas empaquetadas **no se incluyen** (son generadas/regenerables y pesadas).

---

## 4. Herramientas requeridas

- Ubuntu 22.04.5 LTS
- **Vivado 2024.1**
- **Vitis / Vitis HLS 2024.1**
- HoG (incluido como submódulo)
- Git / GitHub, VSCode, TerosHDL

---

## 5. Cómo compilar y cargar

### 5.1 Bitstream (hardware) con HoG

```bash
./Hog/Do LIST
./Hog/Do CREATE el3313_proyecto2
```

El top-level real es **`system_io_wrapper`**, que instancia el wrapper del Block Design y entrega
`INPUT_DRIVER[7:0]` ya sincronizado y filtrado (acondicionamiento de controles).

### 5.2 Usar los binarios precompilados (camino rápido)

En `artifacts/` ya están los binarios listos:

| Archivo | Descripción |
|---------|-------------|
| `system_io_wrapper.bit` | Bitstream del **maestro** |
| `pong_slave.bit` | Bitstream del **esclavo** |
| `pong_app.elf` | Firmware del **maestro** |
| `pong_app_slave.elf` | Firmware del **esclavo** |
| `config.bin`, `sprites.bin` | Configuración y sprites para DDR2/SD |

### 5.3 Programar bitstream y cargar firmware (JTAG / XSCT)

```bash
# Programar bitstream del maestro
vivado -mode batch -source scripts/tcl/debug/program_master_3406.tcl

# Cargar el ELF del maestro
xsdb scripts/tcl/debug/load_master_elf.tcl
```

Scripts equivalentes para el esclavo están en `scripts/tcl/debug/` (cargar bit/ELF por su serial).

> ⚠️ Si copian el proyecto a **otra ruta**, puede ser necesario ajustar las **rutas absolutas**
> dentro de los scripts TCL.

### 5.4 Importar en Vitis

El hardware exportado está en `el3313_proyecto2_system_wrapper.xsa` (incluido en el paquete).
Crear una plataforma a partir de ese `.xsa` y compilar las aplicaciones de `workspace_new/`.

---

## 6. Arquitectura SPI (multijugador)

### Pines físicos (Pmod JA, mismo XDC en ambas FPGAs)

| Señal | Pin | Pmod |
|-------|-----|------|
| CS (ss)   | C17 | JA1 |
| MOSI (io0)| D18 | JA2 |
| MISO (io1)| E18 | JA3 |
| SCK (sck) | G17 | JA4 |

### Configuración del IP `axi_quad_spi_0`

Ambas FPGAs usan **`Master_mode=1`**, `C_SCK_RATIO=16`, `C_NUM_SS_BITS=1`, FIFO=16, **SPI Mode 0**.

> **Por qué importa (causa raíz histórica):** el esclavo originalmente tenía `Master_mode=0`
> (slave-only). En ese modo el IP usa el puerto `SPISEL` como chip-select, pero ese pin no tenía
> asignación XDC → **MISO nunca se activaba** → el maestro recibía solo ceros → P2 no se movía.
> El fix fue poner el esclavo en `Master_mode=1` para que use `ss_i` (pin C17 vía IOBUF) como
> slave-select. Los scripts del puente están en `hw/spi_slave_bridge/`.

### Protocolo (24 bytes full-duplex, Mode 0)

**Esclavo → Maestro (MISO):**
```
[0]=0x01 (INPUT)  [1]=frame_id  [2]=p2.up  [3]=p2.down
[4]=p2.start      [5]=p2.reset  [6]=XOR[0..5]  [7..23]=0
```

**Maestro → Esclavo (MOSI):**
```
[0]=0x02 (STATE)  [1..2]=frame_id(LE)  [3..4]=ball_x  [5..6]=ball_y
[7..8]=paddle_p1_y [9..10]=paddle_p2_y [11]=score_p1 [12]=score_p2
[13]=status [14]=winner [15]=last_point [16..17]=elapsed_s
[18]=serve_dir [19]=flags [20..22]=reservado [23]=XOR[0..22]
```

---

## 7. Controles físicos (FPGA maestra)

| Control | Pin | Función |
|---------|-----|---------|
| CPU_RESETN | C12 | Reset completo del sistema |
| SW0  | — | Reset de partida |
| SW15 | — | Modo: 0 = solitario, 1 = multijugador SPI |
| BTNC | N17 | Start |
| BTNU | M18 | Barra izquierda arriba |
| BTNL | P17 | Barra izquierda abajo |
| BTNR | M17 | Barra derecha arriba (modo local) |
| BTND | P18 | Barra derecha abajo (modo local) |

Detalle completo en `docs/interfaces/controles_pong.md`.

---

## 8. Mapa de memoria (DDR2)

| Región | Dirección |
|--------|-----------|
| Firmware (ejecución) | `0x80200000` |
| Estado del juego / app data | `0x80000000` (`DDR2_mig_0`) |

---

## 9. Repositorio Git

- **Remoto:** `github.com/nicolecr71/Proyecto-Final`
- **Ramas:** `main`, `feature/slave`, `feature/microsd`, `fix/spi-slave-bridge` (último fix SPI/vsync).
- **Convención de commits:** `tipo(alcance): descripción` (p. ej. `fix: ...`, `feat: ...`).

---

## 10. Próximos pasos sugeridos

1. Verificar imagen del **esclavo** con el bitstream actual y confirmar que el fix de MISO sigue OK.
2. Completar la carga de recursos gráficos (sprites/imágenes) desde **microSD**.
3. Documentar/automatizar el flujo de build del esclavo (BD del SPI + ELF) en un solo script.
