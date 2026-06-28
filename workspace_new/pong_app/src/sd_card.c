#include <stdint.h>
#include <string.h>

#include "xparameters.h"
#include "xspi.h"
#include "xstatus.h"

#include "game/sd_card.h"

/* SD SPI command bytes */
#define CMD0    0x40U
#define CMD8    0x48U
#define CMD9    0x49U
#define CMD16   0x50U
#define CMD17   0x51U
#define CMD55   0x77U
#define CMD58   0x7AU
#define ACMD41  0x69U

/* R1 response bits */
#define R1_IDLE         0x01U
#define R1_ILLEGAL_CMD  0x04U

/* Data token for CMD17 */
#define SD_DATA_TOKEN   0xFEU

/* Max poll iterations for card responses */
#define SD_POLL_MAX     2000U

static XSpi    sd_spi_inst;
static uint8_t sd_initialized = 0U;
static uint8_t sd_is_hc       = 0U;   /* 1 = SDHC/SDXC, 0 = SDSC */

/* ------------------------------------------------------------------ */
/* Low-level SPI helpers                                               */
/* ------------------------------------------------------------------ */

static uint8_t spi_byte(uint8_t out)
{
    uint8_t in = 0xFFU;
    XSpi_Transfer(&sd_spi_inst, &out, &in, 1U);
    return in;
}

static void spi_skip(uint32_t n)
{
    uint32_t i;
    for (i = 0U; i < n; i++) {
        spi_byte(0xFFU);
    }
}

/* ------------------------------------------------------------------ */
/* SD command/response                                                 */
/* ------------------------------------------------------------------ */

static uint8_t sd_send_cmd(uint8_t cmd, uint32_t arg, uint8_t crc)
{
    uint8_t r1;
    uint32_t i;

    spi_byte(0xFFU);     /* 1 idle byte before each command */

    spi_byte(cmd);
    spi_byte((uint8_t)((arg >> 24) & 0xFFU));
    spi_byte((uint8_t)((arg >> 16) & 0xFFU));
    spi_byte((uint8_t)((arg >>  8) & 0xFFU));
    spi_byte((uint8_t)( arg        & 0xFFU));
    spi_byte(crc);

    for (i = 0U; i < 8U; i++) {
        r1 = spi_byte(0xFFU);
        if ((r1 & 0x80U) == 0U) {
            return r1;
        }
    }
    return 0xFFU;   /* timeout */
}

/* ------------------------------------------------------------------ */
/* Public API                                                          */
/* ------------------------------------------------------------------ */

sd_result_t sd_card_init(void)
{
    int      status;
    uint8_t  r1;
    uint8_t  buf[4];
    uint32_t i;

    if (sd_initialized != 0U) {
        return SD_OK;
    }

    /* --- Initialize AXI Quad SPI #1 -------------------------------- */
#ifdef SDT
    XSpi_Config *cfg;
    cfg = XSpi_LookupConfig((UINTPTR)XPAR_AXI_QUAD_SPI_1_BASEADDR);
    if (cfg == NULL) {
        return SD_INIT_FAIL;
    }
    status = XSpi_CfgInitialize(&sd_spi_inst, cfg, cfg->BaseAddress);
#else
    status = XSpi_Initialize(&sd_spi_inst, XPAR_AXI_QUAD_SPI_1_DEVICE_ID);
#endif
    if (status != XST_SUCCESS) {
        return SD_INIT_FAIL;
    }

    status = XSpi_SetOptions(
        &sd_spi_inst,
        XSP_MASTER_OPTION | XSP_MANUAL_SSELECT_OPTION
    );
    if (status != XST_SUCCESS) {
        return SD_INIT_FAIL;
    }

    XSpi_Start(&sd_spi_inst);
    XSpi_IntrGlobalDisable(&sd_spi_inst);

    /* De-assert CS (SS = all 1s) while sending init clocks */
    XSpi_SetSlaveSelect(&sd_spi_inst, 0x00U);   /* no slave selected */

    /* --- 80+ init clocks with CS high ------------------------------ */
    for (i = 0U; i < 10U; i++) {
        spi_byte(0xFFU);
    }

    /* --- Assert CS ------------------------------------------------- */
    XSpi_SetSlaveSelect(&sd_spi_inst, 0x01U);

    /* --- CMD0: software reset → expect R1 = 0x01 ------------------- */
    r1 = sd_send_cmd(CMD0, 0UL, 0x95U);
    if (r1 != R1_IDLE) {
        XSpi_SetSlaveSelect(&sd_spi_inst, 0x00U);
        return SD_NO_CARD;
    }

    /* --- CMD8: check voltage range (v2 cards) ---------------------- */
    r1 = sd_send_cmd(CMD8, 0x000001AAU, 0x87U);
    if ((r1 & R1_ILLEGAL_CMD) == 0U) {
        /* v2 card: read 4-byte R7 response */
        for (i = 0U; i < 4U; i++) {
            buf[i] = spi_byte(0xFFU);
        }
        /* Check echo: buf[2]=0x01, buf[3]=0xAA */
        if ((buf[2] != 0x01U) || (buf[3] != 0xAAU)) {
            XSpi_SetSlaveSelect(&sd_spi_inst, 0x00U);
            return SD_INIT_FAIL;
        }
    }

    /* --- ACMD41: wait for card to leave idle state ----------------- */
    for (i = 0U; i < SD_POLL_MAX; i++) {
        sd_send_cmd(CMD55, 0UL, 0xFFU);
        r1 = sd_send_cmd(ACMD41, 0x40000000UL, 0xFFU);
        if (r1 == 0x00U) {
            break;
        }
    }
    if (r1 != 0x00U) {
        XSpi_SetSlaveSelect(&sd_spi_inst, 0x00U);
        return SD_INIT_FAIL;
    }

    /* --- CMD58: read OCR, check CCS bit for SDHC/SDXC ------------- */
    r1 = sd_send_cmd(CMD58, 0UL, 0xFFU);
    if (r1 == 0x00U) {
        for (i = 0U; i < 4U; i++) {
            buf[i] = spi_byte(0xFFU);
        }
        sd_is_hc = ((buf[0] & 0x40U) != 0U) ? 1U : 0U;
    }

    /* --- CMD16: set block size to 512 for SDSC -------------------- */
    if (sd_is_hc == 0U) {
        r1 = sd_send_cmd(CMD16, 512UL, 0xFFU);
        if (r1 != 0x00U) {
            XSpi_SetSlaveSelect(&sd_spi_inst, 0x00U);
            return SD_INIT_FAIL;
        }
    }

    XSpi_SetSlaveSelect(&sd_spi_inst, 0x00U);
    sd_initialized = 1U;
    return SD_OK;
}

sd_result_t sd_card_read_block(uint32_t sector, uint8_t *buf)
{
    uint8_t  r1;
    uint32_t i;
    uint32_t addr;

    if ((sd_initialized == 0U) || (buf == NULL)) {
        return SD_INIT_FAIL;
    }

    /* SDHC uses sector number; SDSC uses byte address */
    addr = (sd_is_hc != 0U) ? sector : (sector * SD_BLOCK_SIZE);

    XSpi_SetSlaveSelect(&sd_spi_inst, 0x01U);

    r1 = sd_send_cmd(CMD17, addr, 0xFFU);
    if (r1 != 0x00U) {
        XSpi_SetSlaveSelect(&sd_spi_inst, 0x00U);
        return SD_INIT_FAIL;
    }

    /* Wait for data token 0xFE */
    for (i = 0U; i < SD_POLL_MAX; i++) {
        r1 = spi_byte(0xFFU);
        if (r1 == SD_DATA_TOKEN) {
            break;
        }
    }
    if (r1 != SD_DATA_TOKEN) {
        XSpi_SetSlaveSelect(&sd_spi_inst, 0x00U);
        return SD_INIT_FAIL;
    }

    /* Read 512 bytes */
    for (i = 0U; i < SD_BLOCK_SIZE; i++) {
        buf[i] = spi_byte(0xFFU);
    }

    /* Discard 2 CRC bytes */
    spi_skip(2U);

    XSpi_SetSlaveSelect(&sd_spi_inst, 0x00U);
    return SD_OK;
}
