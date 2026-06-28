#ifndef VRAM_MEMORY_MAP_H
#define VRAM_MEMORY_MAP_H

#include <stdint.h>
#include <stddef.h>

#ifdef XPAR_VIDEO_VRAM_AXI_CORE_0_BASEADDR
#define VRAM_BASE_ADDR          ((uintptr_t)XPAR_VIDEO_VRAM_AXI_CORE_0_BASEADDR)
#else
#define VRAM_BASE_ADDR          ((uintptr_t)0x00020000u)
#endif

#define VRAM_LOGICAL_WIDTH      160u
#define VRAM_LOGICAL_HEIGHT     120u
#define VRAM_PIXEL_COUNT        (VRAM_LOGICAL_WIDTH * VRAM_LOGICAL_HEIGHT)

#define VRAM_PIXEL_BYTES        4u

#define VRAM_SWAP_CONTROL_OFFSET 0x0001FFF8u
#define VRAM_SWAP_CONTROL_ADDR   (VRAM_BASE_ADDR + VRAM_SWAP_CONTROL_OFFSET)

#define VRAM_RGB444(red, green, blue) \
    ((((uint16_t)(red)   & 0xFu) << 8) | \
     (((uint16_t)(green) & 0xFu) << 4) | \
     (((uint16_t)(blue)  & 0xFu) << 0))

#define VRAM_COLOR_BLACK        VRAM_RGB444(0x0, 0x0, 0x0)
#define VRAM_COLOR_RED          VRAM_RGB444(0xF, 0x0, 0x0)
#define VRAM_COLOR_GREEN        VRAM_RGB444(0x0, 0xF, 0x0)
#define VRAM_COLOR_BLUE         VRAM_RGB444(0x0, 0x0, 0xF)
#define VRAM_COLOR_GRAY         VRAM_RGB444(0x5, 0x5, 0x5)
#define VRAM_COLOR_WHITE        VRAM_RGB444(0xF, 0xF, 0xF)

#define VRAM_PIXEL_INDEX(x, y) \
    (((uint32_t)(y) * VRAM_LOGICAL_WIDTH) + (uint32_t)(x))

#define VRAM_PIXEL_OFFSET(x, y) \
    (VRAM_PIXEL_INDEX((x), (y)) * VRAM_PIXEL_BYTES)

static inline uint32_t vram_is_valid_coordinate(uint32_t x, uint32_t y)
{
    return (x < VRAM_LOGICAL_WIDTH) && (y < VRAM_LOGICAL_HEIGHT);
}

static inline void vram_write_pixel(uint32_t x, uint32_t y, uint16_t rgb444)
{
    uintptr_t pixel_addr;

    if (vram_is_valid_coordinate(x, y)) {
        pixel_addr = VRAM_BASE_ADDR + (uintptr_t)VRAM_PIXEL_OFFSET(x, y);
        *((volatile uint32_t *)pixel_addr) = ((uint32_t)rgb444) & 0x00000FFFu;
    }
}

static inline void vram_request_buffer_swap(void)
{
    *((volatile uint32_t *)VRAM_SWAP_CONTROL_ADDR) = 0x00000001u;
}

static inline uint32_t vram_read_pixel(uint32_t x, uint32_t y)
{
    uintptr_t pixel_addr;

    if (vram_is_valid_coordinate(x, y)) {
        pixel_addr = VRAM_BASE_ADDR + (uintptr_t)VRAM_PIXEL_OFFSET(x, y);
        return (*((volatile uint32_t *)pixel_addr)) & 0x00000FFFu;
    }

    return 0u;
}

static inline void vram_clear(uint16_t rgb444)
{
    uint32_t x;
    uint32_t y;

    for (y = 0u; y < VRAM_LOGICAL_HEIGHT; y++) {
        for (x = 0u; x < VRAM_LOGICAL_WIDTH; x++) {
            vram_write_pixel(x, y, rgb444);
        }
    }
}

#endif
