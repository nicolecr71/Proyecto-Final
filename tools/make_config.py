#!/usr/bin/env python3
"""
Genera config.bin para el juego Pong en FPGA.

El archivo es una serializacion de ddr2_game_config_t (10 campos uint32_t
little-endian = 40 bytes total). La FPGA lo lee al arrancar desde la
microSD y ajusta max_score, velocidades y paddle_speed en tiempo de ejecucion.

Uso:
    python3 make_config.py [--output config.bin] [opciones]

Opciones de juego:
    --max-score     Puntos para ganar        (1-20,  default: 5)
    --ball-speed-x  Velocidad horizontal bola (1-10, default: 1)
    --ball-speed-y  Velocidad vertical bola   (1-10, default: 1)
    --paddle-speed  Velocidad de paletas      (1-10, default: 2)

Copiar config.bin a la raiz de una microSD formateada en FAT32.
"""

import struct
import argparse

# Constantes (deben coincidir con ddr2_memory.h)
DDR2_CONFIG_MAGIC   = 0x504F4E47   # "PONG"
DDR2_CONFIG_VERSION = 0x00000001

# Direcciones de DDR2 (solo para referencia en el archivo, no afectan la logica)
DDR2_BASE           = 0x80000000
SPRITE_BANK_ADDR    = DDR2_BASE + 0x00010000
FRAMEBUFFER_SHADOW  = DDR2_BASE + 0x00100000

# Valores por defecto (iguales a game_config.h)
DEFAULTS = {
    'game_width':   160,
    'game_height':  120,
    'max_score':    5,
    'ball_speed_x': 1,
    'ball_speed_y': 1,
    'paddle_speed': 2,
}


def clamp(value, lo, hi, name):
    if value < lo or value > hi:
        raise argparse.ArgumentTypeError(
            f"{name} debe estar entre {lo} y {hi}, got {value}")
    return value


def main():
    parser = argparse.ArgumentParser(description=__doc__,
                                     formatter_class=argparse.RawDescriptionHelpFormatter)
    parser.add_argument('--output',       default='config.bin')
    parser.add_argument('--max-score',    type=int, default=DEFAULTS['max_score'])
    parser.add_argument('--ball-speed-x', type=int, default=DEFAULTS['ball_speed_x'])
    parser.add_argument('--ball-speed-y', type=int, default=DEFAULTS['ball_speed_y'])
    parser.add_argument('--paddle-speed', type=int, default=DEFAULTS['paddle_speed'])
    args = parser.parse_args()

    max_score    = clamp(args.max_score,    1, 20, '--max-score')
    ball_speed_x = clamp(args.ball_speed_x, 1, 10, '--ball-speed-x')
    ball_speed_y = clamp(args.ball_speed_y, 1, 10, '--ball-speed-y')
    paddle_speed = clamp(args.paddle_speed, 1, 10, '--paddle-speed')

    # Estructura ddr2_game_config_t (10 x uint32_t little-endian)
    data = struct.pack('<10I',
        DDR2_CONFIG_MAGIC,
        DDR2_CONFIG_VERSION,
        DEFAULTS['game_width'],
        DEFAULTS['game_height'],
        max_score,
        SPRITE_BANK_ADDR,
        FRAMEBUFFER_SHADOW,
        ball_speed_x,
        ball_speed_y,
        paddle_speed,
    )

    with open(args.output, 'wb') as f:
        f.write(data)

    print(f"Generado: {args.output}  ({len(data)} bytes)")
    print(f"  max_score    = {max_score}")
    print(f"  ball_speed_x = {ball_speed_x}")
    print(f"  ball_speed_y = {ball_speed_y}")
    print(f"  paddle_speed = {paddle_speed}")
    print()
    print("Instrucciones:")
    print("  1. Formatea la microSD en FAT32")
    print("  2. Copia config.bin a la raiz de la SD")
    print("  3. La FPGA carga los parametros al arrancar")


if __name__ == '__main__':
    main()
