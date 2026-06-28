#!/usr/bin/env bash
# Compila el ELF del slave (pong_app_slave) tras el cambio del puente SPI.
# Pasa las 3 direcciones base de los AXI GPIO del puente como -D (no requiere
# regenerar el BSP). Direcciones asignadas por el BD automation:
#   axi_gpio_spi_a=0x40010000  axi_gpio_spi_b=0x40020000  axi_gpio_spi_c=0x40030000
set -euo pipefail

REPO=/home/geco/Descargas/el3313_proyecto2_compartir_20260625_1633
WS=$REPO/workspace_new
APP=$WS/pong_app_slave
SRC=$APP/src
BSP=$WS/el3313_platform/export/el3313_platform/sw/el3313_platform/standalone_microblaze_riscv_0
GCC=/home/geco/Xilinx2024/Vitis/2024.1/gnu/riscv/lin/riscv64-unknown-elf/bin/riscv64-unknown-elf-gcc
SYSROOT=/home/geco/Xilinx2024/Vitis/2024.1/gnu/riscv/lin/riscv64-unknown-elf/riscv32-xilinx-elf

OUT=$APP/Debug
mkdir -p "$OUT"

CFLAGS="-Wall -O0 -g3 -c -fmessage-length=0 -march=rv32i -mabi=ilp32 \
  -ffunction-sections -fdata-sections -isystem $SYSROOT/usr/include \
  -I$SRC -I$SRC/fatfs -I$BSP/bspinclude/include \
  -DFILE_SYSTEM_INTERFACE_SD \
  -DSPI_BRIDGE_GPIO_A_BASE=0x40010000U \
  -DSPI_BRIDGE_GPIO_B_BASE=0x40020000U \
  -DSPI_BRIDGE_GPIO_C_BASE=0x40030000U"

SRCS=$(find "$SRC" -name '*.c' | sort)
echo "== Compilando =="
OBJS=()
for c in $SRCS; do
    o="$OUT/$(basename "${c%.c}").o"
    echo "  CC $(basename "$c")"
    $GCC $CFLAGS -o "$o" "$c"
    OBJS+=("$o")
done

echo "== Enlazando =="
$GCC -Wl,-T -Wl,"$SRC/lscript.ld" -L"$BSP/bsplib/lib" \
    -march=rv32i -mabi=ilp32 --sysroot="$SYSROOT" \
    -Wl,--gc-sections -o "$OUT/pong_app_slave.elf" "${OBJS[@]}" \
    -Wl,--start-group,-lxil,-lgcc,-lc,--end-group

echo "== OK: $OUT/pong_app_slave.elf =="
/home/geco/Xilinx2024/Vitis/2024.1/gnu/riscv/lin/riscv64-unknown-elf/bin/riscv64-unknown-elf-size "$OUT/pong_app_slave.elf"
cp -f "$OUT/pong_app_slave.elf" "$REPO/artifacts/pong_app_slave.elf"
echo "Copiado a artifacts/pong_app_slave.elf"
