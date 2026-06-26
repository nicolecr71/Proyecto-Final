#ifndef DDR2_MEMORY_H
#define DDR2_MEMORY_H

#include <stdint.h>
#include <stddef.h>

#include "xmem_config.h"

#include "game/game_config.h"
#include "game/game_state.h"

/*
 * DDR2 memory map.
 *
 * The BSP exposes the MIG region as:
 * XPAR_MIG_0_BASEADDRESS = 0x80000000
 * XPAR_MIG_0_HIGHADDRESS = 0x88000000
 *
 * The usable range is treated as:
 * 0x80000000 - 0x87FFFFFF
 */
#define DDR2_BASE_ADDR              ((uintptr_t)XPAR_MIG_0_BASEADDRESS)
#define DDR2_LIMIT_ADDR             ((uintptr_t)XPAR_MIG_0_HIGHADDRESS)

#define DDR2_TEST_ADDR              (DDR2_BASE_ADDR + 0x00001000U)
#define DDR2_CONFIG_ADDR            (DDR2_BASE_ADDR + 0x00002000U)
#define DDR2_GAME_STATE_ADDR        (DDR2_BASE_ADDR + 0x00003000U)
#define DDR2_SPRITE_BANK_ADDR       (DDR2_BASE_ADDR + 0x00010000U)
#define DDR2_FRAMEBUFFER_SHADOW     (DDR2_BASE_ADDR + 0x00100000U)

#define DDR2_TEST_WORDS             256U
#define DDR2_CONFIG_MAGIC           0x504F4E47U
#define DDR2_CONFIG_VERSION         0x00000001U

typedef struct {
    uint32_t magic;
    uint32_t version;
    uint32_t game_width;
    uint32_t game_height;
    uint32_t max_score;
    uint32_t sprite_bank_addr;
    uint32_t framebuffer_shadow_addr;
} ddr2_game_config_t;

static inline void ddr2_write32(uintptr_t address, uint32_t value)
{
    *((volatile uint32_t *)address) = value;
}

static inline uint32_t ddr2_read32(uintptr_t address)
{
    return *((volatile uint32_t *)address);
}

static inline void ddr2_copy_to(uintptr_t dst_addr, const void *src, size_t size)
{
    volatile uint8_t *dst;
    const uint8_t *src_bytes;
    size_t i;

    dst = (volatile uint8_t *)dst_addr;
    src_bytes = (const uint8_t *)src;

    for (i = 0U; i < size; i++) {
        dst[i] = src_bytes[i];
    }
}

static inline uint8_t ddr2_self_test(void)
{
    uint32_t i;
    uint32_t expected;
    uint32_t value;
    uintptr_t address;

    for (i = 0U; i < DDR2_TEST_WORDS; i++) {
        address = DDR2_TEST_ADDR + ((uintptr_t)i * sizeof(uint32_t));
        expected = 0xA5A50000U ^ i;
        ddr2_write32(address, expected);
    }

    for (i = 0U; i < DDR2_TEST_WORDS; i++) {
        address = DDR2_TEST_ADDR + ((uintptr_t)i * sizeof(uint32_t));
        expected = 0xA5A50000U ^ i;
        value = ddr2_read32(address);

        if (value != expected) {
            return 0U;
        }
    }

    for (i = 0U; i < DDR2_TEST_WORDS; i++) {
        address = DDR2_TEST_ADDR + ((uintptr_t)i * sizeof(uint32_t));
        expected = 0x5A5A0000U ^ (i << 1U);
        ddr2_write32(address, expected);
    }

    for (i = 0U; i < DDR2_TEST_WORDS; i++) {
        address = DDR2_TEST_ADDR + ((uintptr_t)i * sizeof(uint32_t));
        expected = 0x5A5A0000U ^ (i << 1U);
        value = ddr2_read32(address);

        if (value != expected) {
            return 0U;
        }
    }

    return 1U;
}

static inline void ddr2_init_game_config(void)
{
    ddr2_game_config_t config;

    config.magic = DDR2_CONFIG_MAGIC;
    config.version = DDR2_CONFIG_VERSION;
    config.game_width = GAME_WIDTH;
    config.game_height = GAME_HEIGHT;
    config.max_score = MAX_SCORE;
    config.sprite_bank_addr = (uint32_t)DDR2_SPRITE_BANK_ADDR;
    config.framebuffer_shadow_addr = (uint32_t)DDR2_FRAMEBUFFER_SHADOW;

    ddr2_copy_to(DDR2_CONFIG_ADDR, &config, sizeof(config));
}

static inline void ddr2_store_game_state(const game_state_t *state)
{
    ddr2_copy_to(DDR2_GAME_STATE_ADDR, state, sizeof(game_state_t));
}

static inline void ddr2_init_demo_sprite_bank(void)
{
    uint32_t i;
    uint16_t sprite_pixel;
    uintptr_t address;

    for (i = 0U; i < 64U; i++) {
        if ((i + (i / 8U)) & 1U) {
            sprite_pixel = 0x0F0U;
        } else {
            sprite_pixel = 0x00FU;
        }

        address = DDR2_SPRITE_BANK_ADDR + ((uintptr_t)i * sizeof(uint16_t));
        *((volatile uint16_t *)address) = sprite_pixel;
    }
}

#endif
