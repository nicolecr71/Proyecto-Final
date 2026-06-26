#include <stdint.h>
#include <string.h>

#include "game/sd_loader.h"
#include "game/sd_card.h"
#include "game/ddr2_memory.h"

#define SD_HEADER_SECTOR    0UL
#define SD_SPRITES_MAX      (256UL * 1024UL)
#define SD_CONFIG_MAX       4096UL

static sd_pack_header_t s_header;
static uint8_t          s_ready = 0U;
static uint8_t          s_sector_buf[SD_BLOCK_SIZE];

/* ------------------------------------------------------------------ */

static int str_eq(const char *a, const char *b)
{
    while (*a && *b) {
        if (*a != *b) return 0;
        a++;
        b++;
    }
    return (*a == '\0') && (*b == '\0');
}

/* ------------------------------------------------------------------ */

uint8_t sd_loader_init(void)
{
    sd_result_t res;
    uint8_t    *p;

    s_ready = 0U;

    res = sd_card_init();
    if (res != SD_OK) {
        return 0U;
    }

    res = sd_card_read_block(SD_HEADER_SECTOR, s_sector_buf);
    if (res != SD_OK) {
        return 0U;
    }

    /* Parse header from raw bytes */
    p = s_sector_buf;
    s_header.magic =
        ((uint32_t)p[0])        |
        ((uint32_t)p[1] << 8)   |
        ((uint32_t)p[2] << 16)  |
        ((uint32_t)p[3] << 24);

    if (s_header.magic != SD_PACK_MAGIC) {
        return 0U;
    }

    s_header.version    = p[4];
    s_header.file_count = p[5];

    if (s_header.file_count > SD_PACK_MAX_FILES) {
        s_header.file_count = SD_PACK_MAX_FILES;
    }

    {
        uint8_t  i;
        uint32_t off = 6U;

        for (i = 0U; i < s_header.file_count; i++) {
            memcpy(s_header.files[i].name, &p[off], SD_PACK_NAME_LEN);
            off += SD_PACK_NAME_LEN;

            s_header.files[i].start_sector =
                ((uint32_t)p[off])        |
                ((uint32_t)p[off+1] << 8) |
                ((uint32_t)p[off+2] << 16)|
                ((uint32_t)p[off+3] << 24);
            off += 4U;

            s_header.files[i].size_bytes =
                ((uint32_t)p[off])        |
                ((uint32_t)p[off+1] << 8) |
                ((uint32_t)p[off+2] << 16)|
                ((uint32_t)p[off+3] << 24);
            off += 4U;
        }
    }

    s_ready = 1U;
    return 1U;
}

/* ------------------------------------------------------------------ */

uint32_t sd_loader_load_file(const char *name, uintptr_t dst_addr, uint32_t max_bytes)
{
    uint8_t  i;
    uint32_t sector;
    uint32_t remaining;
    uint32_t copied;
    uintptr_t dst;

    if ((s_ready == 0U) || (name == NULL) || (dst_addr == 0U)) {
        return 0U;
    }

    /* Find file in header */
    for (i = 0U; i < s_header.file_count; i++) {
        if (str_eq(s_header.files[i].name, name)) {
            break;
        }
    }
    if (i >= s_header.file_count) {
        return 0U;
    }

    remaining = s_header.files[i].size_bytes;
    if (remaining > max_bytes) {
        remaining = max_bytes;
    }

    sector = s_header.files[i].start_sector;
    dst    = dst_addr;
    copied = 0U;

    while (remaining > 0U) {
        uint32_t chunk;

        if (sd_card_read_block(sector, s_sector_buf) != SD_OK) {
            break;
        }

        chunk = (remaining < SD_BLOCK_SIZE) ? remaining : SD_BLOCK_SIZE;
        ddr2_copy_to(dst, s_sector_buf, chunk);

        dst       += chunk;
        copied    += chunk;
        remaining -= chunk;
        sector++;
    }

    return copied;
}

/* ------------------------------------------------------------------ */

uint8_t sd_loader_load_resources(void)
{
    uint32_t loaded;

    loaded = sd_loader_load_file("sprites.bin", DDR2_SPRITE_BANK_ADDR, SD_SPRITES_MAX);
    (void)sd_loader_load_file("config.bin",  DDR2_CONFIG_ADDR,       SD_CONFIG_MAX);

    return (loaded > 0U) ? 1U : 0U;
}
