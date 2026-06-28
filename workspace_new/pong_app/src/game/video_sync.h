#ifndef VIDEO_SYNC_H
#define VIDEO_SYNC_H

#include <stdint.h>

#include "vram_memory_map.h"

#define VIDEO_FRAME_COUNTER_OFFSET  0x0001FFFCu
#define VIDEO_FRAME_COUNTER_ADDR    (VRAM_BASE_ADDR + VIDEO_FRAME_COUNTER_OFFSET)

/*
 * Timeout para no congelar el firmware si el hardware todavía no expone
 * correctamente el frame_counter.
 */
#define VIDEO_WAIT_TIMEOUT          1000000u

static inline uint32_t video_get_frame_counter(void)
{
    return *((volatile uint32_t *)VIDEO_FRAME_COUNTER_ADDR);
}

static inline uint32_t video_wait_next_frame(void)
{
    uint32_t frame_now;
    uint32_t timeout;

    frame_now = video_get_frame_counter();
    timeout = VIDEO_WAIT_TIMEOUT;

    while ((video_get_frame_counter() == frame_now) && (timeout > 0u)) {
        timeout--;
    }

    return timeout;
}

#endif
