#ifndef SD_LOADER_H
#define SD_LOADER_H

#include <stdint.h>

/*
 * Mounts the FAT32 volume on the microSD and initializes the SD card driver.
 * Returns 1 on success, 0 on failure (no card, bad format, etc.).
 */
uint8_t sd_loader_init(void);

/*
 * Opens a file by name from the root of the FAT32 volume and reads it into
 * dst_addr. Returns bytes read, or 0 on error.
 */
uint32_t sd_loader_load_file(const char *name, uintptr_t dst_addr, uint32_t max_bytes);

/*
 * Loads "sprites.bin" and "config.bin" from the SD root into DDR2.
 * Returns 1 if sprites.bin was loaded successfully.
 */
uint8_t sd_loader_load_resources(void);

#endif
