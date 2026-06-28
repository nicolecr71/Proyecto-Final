#include "game/sd_loader.h"
#include "game/ddr2_memory.h"
#include "fatfs/ff.h"

#define SD_SPRITES_FILE  "sprites.bin"
#define SD_CONFIG_FILE   "config.bin"
#define SD_SPRITES_MAX   0x00070000U
#define SD_CONFIG_MAX    0x00002000U

static FATFS g_fs;
static uint8_t g_mounted = 0U;

uint8_t sd_loader_init(void)
{
    FRESULT res;
    g_mounted = 0U;
    res = f_mount(&g_fs, "", 1);
    if (res == FR_OK) {
        g_mounted = 1U;
    }
    return g_mounted;
}

uint32_t sd_loader_load_file(const char *name, uintptr_t dst_addr, uint32_t max_bytes)
{
    FIL fil;
    FRESULT res;
    UINT br = 0U;

    if (g_mounted == 0U) {
        return 0U;
    }
    res = f_open(&fil, name, FA_READ);
    if (res != FR_OK) {
        return 0U;
    }
    (void)f_read(&fil, (void *)dst_addr, (UINT)max_bytes, &br);
    (void)f_close(&fil);
    return (uint32_t)br;
}

uint8_t sd_loader_load_resources(void)
{
    uint32_t bytes;
    bytes = sd_loader_load_file(SD_SPRITES_FILE,
                                (uintptr_t)DDR2_SPRITE_BANK_ADDR,
                                SD_SPRITES_MAX);
    if (bytes == 0U) {
        return 0U;
    }
    (void)sd_loader_load_file(SD_CONFIG_FILE,
                              (uintptr_t)DDR2_CONFIG_ADDR,
                              SD_CONFIG_MAX);
    return 1U;
}
