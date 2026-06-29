#!/usr/bin/env python3
import argparse
import struct
from pathlib import Path

# Formato: 10 palabras uint32 little-endian.
# Estos valores corresponden al config.bin probado en hardware.
#
# Índices importantes usados durante la prueba:
#   word[6] = velocidad horizontal de la bola
#   word[7] = velocidad vertical de la bola
#   word[8] = velocidad de las barras
#
# La bola quedó mucho más rápida con los valores actuales.
CONFIG_WORDS = [1347374663, 1, 160, 120, 5, 2147549184, 36, 22, 18, 2]

def main():
    parser = argparse.ArgumentParser(description="Genera config.bin para Pong.")
    parser.add_argument(
        "--output",
        default="tools/sdcard_root/config.bin",
        help="Ruta de salida para config.bin"
    )
    args = parser.parse_args()

    out = Path(args.output)
    out.parent.mkdir(parents=True, exist_ok=True)
    out.write_bytes(struct.pack("<10I", *CONFIG_WORDS))

    print(f"config.bin generado: {out}")
    print(f"tamaño: {out.stat().st_size} bytes")
    print("words:", CONFIG_WORDS)

if __name__ == "__main__":
    main()
