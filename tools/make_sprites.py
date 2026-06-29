#!/usr/bin/env python3
"""
Genera sprites.bin para el juego Pong en FPGA.

Formato: pixeles uint16_t little-endian, RGB444 (0x0RGB).
  bits [11:8] = R,  bits [7:4] = G,  bits [3:0] = B

Uso:
    python3 make_sprites.py [--output sprites.bin]

Copiar sprites.bin a la raiz de una microSD formateada en FAT32.

Layout del sprite bank (igual que sprite_bank.h):
    0x0000  Ball     3x3  px  (BALL_SIZE x BALL_SIZE)
    0x0020  Paddle1  3x20 px  (PADDLE_WIDTH x PADDLE_HEIGHT)
    0x00A0  Paddle2  3x20 px  (PADDLE_WIDTH x PADDLE_HEIGHT)
"""

import struct
import argparse

# Dimensiones (deben coincidir con game_config.h)
BALL_SIZE   = 3
PADDLE_W    = 3
PADDLE_H    = 20

# Offsets (deben coincidir con sprite_bank.h)
SPRITE_BALL_OFFSET = 0x0000
SPRITE_P1_OFFSET   = 0x0020
SPRITE_P2_OFFSET   = 0x00A0
TOTAL_BYTES        = 0x0118

# Colores por defecto RGB444 (0x0RGB)
# Editalos para personalizar la apariencia del juego
COLOR_BALL     = 0x0FFF  # blanco
COLOR_P1       = 0x0FFF  # blanco
COLOR_P2       = 0x0FFF  # blanco


def rgb444(r, g, b):
    return ((r & 0xF) << 8) | ((g & 0xF) << 4) | (b & 0xF)


def write_sprite(buf, offset, w, h, color):
    for i in range(w * h):
        struct.pack_into('<H', buf, offset + i * 2, color)


def main():
    parser = argparse.ArgumentParser(description=__doc__,
                                     formatter_class=argparse.RawDescriptionHelpFormatter)
    parser.add_argument('--output', default='sprites.bin',
                        help='Archivo de salida (default: sprites.bin)')
    args = parser.parse_args()

    buf = bytearray(TOTAL_BYTES)

    write_sprite(buf, SPRITE_BALL_OFFSET, BALL_SIZE, BALL_SIZE, COLOR_BALL)
    write_sprite(buf, SPRITE_P1_OFFSET,   PADDLE_W,  PADDLE_H,  COLOR_P1)
    write_sprite(buf, SPRITE_P2_OFFSET,   PADDLE_W,  PADDLE_H,  COLOR_P2)

    with open(args.output, 'wb') as f:
        f.write(buf)

    print(f"Generado: {args.output}  ({len(buf)} bytes)")
    print(f"  Ball   @ 0x{SPRITE_BALL_OFFSET:04X}: {BALL_SIZE}x{BALL_SIZE} px  "
          f"color=0x{COLOR_BALL:03X}")
    print(f"  P1     @ 0x{SPRITE_P1_OFFSET:04X}: {PADDLE_W}x{PADDLE_H} px  "
          f"color=0x{COLOR_P1:03X}")
    print(f"  P2     @ 0x{SPRITE_P2_OFFSET:04X}: {PADDLE_W}x{PADDLE_H} px  "
          f"color=0x{COLOR_P2:03X}")
    print()
    print("Instrucciones:")
    print("  1. Formatea la microSD en FAT32")
    print("  2. Copia sprites.bin a la raiz de la SD")
    print("  3. La FPGA carga los sprites al arrancar")


if __name__ == '__main__':
    main()
