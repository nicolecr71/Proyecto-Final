#include <stdint.h>
#include <stddef.h>

#include "game/game_app.h"
#include "game/input_driver.h"
#include "game/pong_renderer.h"
#include "game/video_sync.h"
#include "game/spi_game.h"
#include "game/ddr2_memory.h"
#include "game/ddr2_sections.h"
#include "game/sd_loader.h"
#include "vram_memory_map.h"

#define MAIN_LOOP_DELAY_CYCLES 120000U

static game_app_t g_app DDR2_BSS_SECTION;

static const uint16_t g_demo_sprite_resource[64] DDR2_RODATA_SECTION = {
    0x0F0, 0x00F, 0x0F0, 0x00F, 0x0F0, 0x00F, 0x0F0, 0x00F,
    0x00F, 0x0F0, 0x00F, 0x0F0, 0x00F, 0x0F0, 0x00F, 0x0F0,
    0x0F0, 0x00F, 0x0F0, 0x00F, 0x0F0, 0x00F, 0x0F0, 0x00F,
    0x00F, 0x0F0, 0x00F, 0x0F0, 0x00F, 0x0F0, 0x00F, 0x0F0,
    0x0F0, 0x00F, 0x0F0, 0x00F, 0x0F0, 0x00F, 0x0F0, 0x00F,
    0x00F, 0x0F0, 0x00F, 0x0F0, 0x00F, 0x0F0, 0x00F, 0x0F0,
    0x0F0, 0x00F, 0x0F0, 0x00F, 0x0F0, 0x00F, 0x0F0, 0x00F,
    0x00F, 0x0F0, 0x00F, 0x0F0, 0x00F, 0x0F0, 0x00F, 0x0F0
};

static void delay_cycles(uint32_t cycles)
{
    volatile uint32_t i;

    for (i = 0U; i < cycles; i++) {
        /* Busy wait used until a timer/tick source is integrated. */
    }
}

static void draw_status_square(uint32_t x0, uint32_t y0, uint8_t ok)
{
    uint32_t x;
    uint32_t y;
    uint16_t color;

    color = ok ? VRAM_COLOR_GREEN : VRAM_COLOR_RED;

    for (y = y0; y < (y0 + 9U); y++) {
        for (x = x0; x < (x0 + 9U); x++) {
            vram_write_pixel(x, y, color);
        }
    }
}

static uint8_t ddr2_pointer_in_range(const void *ptr)
{
    uintptr_t addr;

    addr = (uintptr_t)ptr;

    if (addr < DDR2_BASE_ADDR) {
        return 0U;
    }

    if (addr >= DDR2_LIMIT_ADDR) {
        return 0U;
    }

    return 1U;
}

static void copy_demo_sprite_resource_to_ddr2_bank(void)
{
    ddr2_copy_to(
        DDR2_SPRITE_BANK_ADDR,
        g_demo_sprite_resource,
        sizeof(g_demo_sprite_resource)
    );
}

int main(void)
{
    player_input_t p1;
    player_input_t p2;
    player_input_t p2_remote;
    uint8_t multiplayer_mode;
    uint8_t game_reset;
    uint8_t game_reset_prev;
    uint8_t ddr2_ok;
    uint8_t ddr2_sections_ok;
    uint8_t sd_ok;

    game_reset_prev = 0U;

    delay_cycles(2000000U);

    ddr2_ok = ddr2_self_test();

    ddr2_sections_ok =
        ddr2_pointer_in_range(&g_app) &&
        ddr2_pointer_in_range(g_demo_sprite_resource);

    if (ddr2_ok != 0U) {
        ddr2_init_game_config();
        ddr2_init_demo_sprite_bank();
        copy_demo_sprite_resource_to_ddr2_bank();
    }

    /*
     * Load sprites and config from microSD into DDR2.
     * If the SD card is absent or the pack is invalid the demo
     * sprite bank written above is kept as fallback.
     */
    sd_ok = sd_loader_init();
    if (sd_ok != 0U) {
        (void)sd_loader_load_resources();
    }

    game_app_init(
        &g_app,
        GAME_MODE_LOCAL,
        GAME_ROLE_MASTER
    );

    if (ddr2_ok != 0U) {
        ddr2_store_game_state(&g_app.state);
    }

            pong_render_state(&g_app.state);
        vram_request_buffer_swap();
        input_wait_next_frame();

    /*
     * Indicadores:
     * Derecha = prueba lectura/escritura DDR2.
     * Izquierda = secciones enlazadas en DDR2.
     */

    while (1) {
        p1 = input_read_player1();
        p2 = input_read_player2();

        multiplayer_mode = input_read_multiplayer_mode();

        if (multiplayer_mode) {
            /*
             * En modo SPI, la barra derecha pertenece a la FPGA esclava.
             * Por eso se descartan los botones locales M17/P18 del maestro.
             */
            p2 = (player_input_t){0};

            if (spi_game_exchange_state_input(&g_app.state, &p2_remote)) {
                p2 = p2_remote;
            }
        }

        game_reset = input_read_game_reset();

        if ((game_reset != 0U) && (game_reset_prev == 0U)) {
            p1.reset = 1U;
            p2.reset = 1U;
        }

        game_reset_prev = game_reset;

        game_app_update_local(
            &g_app,
            p1,
            p2
        );

        if (ddr2_ok != 0U) {
            ddr2_store_game_state(&g_app.state);
        }

        pong_render_state(&g_app.state);
        vram_request_buffer_swap();
        input_wait_next_frame();
        
        delay_cycles(MAIN_LOOP_DELAY_CYCLES);
    }

    return 0;
}
