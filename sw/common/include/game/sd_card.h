#ifndef SD_CARD_H
#define SD_CARD_H

#include <stdint.h>

#define SD_BLOCK_SIZE   512U

/*
 * Returned by sd_card_init().
 */
typedef enum {
    SD_OK        = 0,
    SD_NO_CARD   = 1,
    SD_INIT_FAIL = 2
} sd_result_t;

sd_result_t sd_card_init(void);
sd_result_t sd_card_read_block(uint32_t sector, uint8_t *buf);

#endif
