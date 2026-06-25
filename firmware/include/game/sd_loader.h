#ifndef SD_LOADER_H
#define SD_LOADER_H

#include <stdint.h>

/*
 * Magic bytes at sector 0 of the SD card image.
 */
#define SD_PACK_MAGIC       0x474E5053UL   /* "SPNG" little-endian */
#define SD_PACK_VERSION     0x01U
#define SD_PACK_MAX_FILES   8U
#define SD_PACK_NAME_LEN    16U

/*
 * Sector 0 layout:
 *   [0..3]   magic
 *   [4]      version
 *   [5]      file_count
 *   [6..N]   file_entry * file_count  (24 bytes each)
 */
typedef struct {
    char     name[SD_PACK_NAME_LEN];
    uint32_t start_sector;
    uint32_t size_bytes;
} sd_pack_entry_t;

typedef struct {
    uint32_t        magic;
    uint8_t         version;
    uint8_t         file_count;
    sd_pack_entry_t files[SD_PACK_MAX_FILES];
} sd_pack_header_t;

/*
 * Initializes the SD card and parses the pack header.
 * Returns 1 on success, 0 on failure.
 */
uint8_t sd_loader_init(void);

/*
 * Copies the contents of a named file into dst_addr in DDR2.
 * Returns the number of bytes copied, or 0 on error.
 */
uint32_t sd_loader_load_file(const char *name, uintptr_t dst_addr, uint32_t max_bytes);

/*
 * Convenience: loads sprites.bin and config.bin into their DDR2 slots.
 * Returns 1 if at least sprites.bin was loaded.
 */
uint8_t sd_loader_load_resources(void);

#endif
