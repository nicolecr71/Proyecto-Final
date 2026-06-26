#include "diskio.h"
#include "game/sd_card.h"

#define SD_DRIVE 0

static uint8_t g_disk_ready = 0U;

DSTATUS disk_initialize(BYTE pdrv)
{
    if (pdrv != SD_DRIVE) {
        return STA_NOINIT;
    }
    if (sd_card_init() == SD_OK) {
        g_disk_ready = 1U;
        return 0;
    }
    g_disk_ready = 0U;
    return STA_NOINIT;
}

DSTATUS disk_status(BYTE pdrv)
{
    if (pdrv != SD_DRIVE) {
        return STA_NOINIT;
    }
    return (g_disk_ready != 0U) ? 0 : STA_NOINIT;
}

DRESULT disk_read(BYTE pdrv, BYTE *buff, LBA_t sector, UINT count)
{
    UINT i;

    if (pdrv != SD_DRIVE || g_disk_ready == 0U) {
        return RES_NOTRDY;
    }
    for (i = 0U; i < count; i++) {
        if (sd_card_read_block((uint32_t)(sector + i),
                               buff + (i * 512U)) != SD_OK) {
            return RES_ERROR;
        }
    }
    return RES_OK;
}

DRESULT disk_ioctl(BYTE pdrv, BYTE cmd, void *buff)
{
    if (pdrv != SD_DRIVE) {
        return RES_PARERR;
    }
    switch (cmd) {
        case CTRL_SYNC:
            return RES_OK;
        case GET_SECTOR_SIZE:
            *(WORD *)buff = 512U;
            return RES_OK;
        case GET_BLOCK_SIZE:
            *(DWORD *)buff = 1U;
            return RES_OK;
        default:
            return RES_PARERR;
    }
}
