#!/usr/bin/env python3
"""
make_sd_image.py  —  crea una imagen raw para la microSD del proyecto Pong FPGA.

Formato:
  Sector 0 (512 bytes):
    [0..3]  magic  = 0x53504E47  ("SPNG" en little-endian = 0x47 0x4E 0x50 0x53)
    [4]     version = 0x01
    [5]     file_count
    [6+]    entradas de 24 bytes cada una:
              name[16]  (cadena, rellena con 0x00)
              start_sector [4]  uint32_t LE
              size_bytes   [4]  uint32_t LE

  Sectores siguientes: datos de cada archivo (relleno con 0x00 hasta múltiplo de 512)

Uso:
  python3 make_sd_image.py sprites.bin config.bin -o sd_image.bin

  Luego grabar la imagen en la tarjeta:
    Linux/Mac:  sudo dd if=sd_image.bin of=/dev/sdX bs=512
    Windows:    usar Win32DiskImager o Rufus en modo DD

IMPORTANTE: La tarjeta NO necesita estar formateada con FAT.
            El firmware lee directo por sectores.
"""

import struct
import sys
import os
import argparse

SECTOR_SIZE   = 512
MAGIC         = 0x474E5053   # "SPNG" little-endian
VERSION       = 0x01
MAX_FILES     = 8
NAME_LEN      = 16
ENTRY_SIZE    = NAME_LEN + 4 + 4   # 24 bytes
HEADER_SECTOR = 0
FIRST_DATA_SECTOR = 1               # datos empiezan en sector 1


def pad_to_sector(data: bytes) -> bytes:
    remainder = len(data) % SECTOR_SIZE
    if remainder:
        data += b'\x00' * (SECTOR_SIZE - remainder)
    return data


def build_image(files: list[tuple[str, bytes]]) -> bytes:
    if len(files) > MAX_FILES:
        raise ValueError(f"Máximo {MAX_FILES} archivos, se recibieron {len(files)}")

    # --- Calcular tabla de sectores ---
    entries = []
    current_sector = FIRST_DATA_SECTOR
    for name, data in files:
        padded = pad_to_sector(data)
        entries.append((name, current_sector, len(data), padded))
        current_sector += len(padded) // SECTOR_SIZE

    # --- Construir sector 0 ---
    header = struct.pack('<IBB', MAGIC, VERSION, len(files))
    for name, start_sector, size, _ in entries:
        name_bytes = name.encode('ascii')[:NAME_LEN]
        name_bytes = name_bytes.ljust(NAME_LEN, b'\x00')
        header += name_bytes
        header += struct.pack('<II', start_sector, size)

    # Rellenar hasta 512 bytes
    assert len(header) <= SECTOR_SIZE, "Header demasiado grande"
    header = header.ljust(SECTOR_SIZE, b'\x00')

    # --- Concatenar todo ---
    image = header
    for _, _, _, padded in entries:
        image += padded

    return image


def main():
    parser = argparse.ArgumentParser(description='Crea imagen SD para Pong FPGA')
    parser.add_argument('files', nargs='+', help='Archivos a incluir (ej: sprites.bin config.bin)')
    parser.add_argument('-o', '--output', default='sd_image.bin', help='Archivo de salida (default: sd_image.bin)')
    args = parser.parse_args()

    file_data = []
    for path in args.files:
        name = os.path.basename(path)
        with open(path, 'rb') as f:
            data = f.read()
        file_data.append((name, data))
        print(f'  + {name:20s}  {len(data):8d} bytes')

    image = build_image(file_data)

    with open(args.output, 'wb') as f:
        f.write(image)

    print(f'\nImagen generada: {args.output}  ({len(image)} bytes, {len(image)//SECTOR_SIZE} sectores)')
    print(f'\nGrabar en Linux/Mac:')
    print(f'  sudo dd if={args.output} of=/dev/sdX bs=512')


if __name__ == '__main__':
    main()
