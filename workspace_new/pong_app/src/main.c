#include <stdint.h>

#include "game/game_app.h"
#include "game/input_driver.h"
#include "game/pong_renderer.h"
#include "game/video_sync.h"
#include "game/spi_game.h"
#include "game/ddr2_memory.h"
#include "game/ddr2_sections.h"
#include "game/game_params.h"
#include "game/sd_loader.h"
#include "vram_memory_map.h"

#define MAIN_LOOP_DELAY_CYCLES 120000U

static game_app_t g_app DDR2_BSS_SECTION;

static void delay_cycles(uint32_t cycles)
{
    volatile uint32_t i;

    for (i = 0U; i < cycles; i++) {}
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
    uint8_t sd_ok;

    game_reset_prev = 0U;

    delay_cycles(2000000U);

    ddr2_ok = ddr2_self_test();

    if (ddr2_ok != 0U) {
        ddr2_init_game_config();
        ddr2_init_demo_sprite_bank();
    }

    /*
     * Carga sprites y config desde la microSD (FAT32) hacia DDR2.
     * Si no hay SD o faltan archivos, quedan los sprites de demo.
     */
    sd_ok = sd_loader_init();
    if (sd_ok != 0U) {
        (void)sd_loader_load_resources();
    }

    game_params_load_from_ddr2();

    game_app_init(&g_app, GAME_MODE_LOCAL, GAME_ROLE_MASTER);

    if (ddr2_ok != 0U) {
        ddr2_store_game_state(&g_app.state);
    }

    pong_render_state(&g_app.state);
    vram_request_buffer_swap();
    input_wait_next_frame();

    while (1) {
        p1 = input_read_player1();
        p2 = input_read_player2();

        multiplayer_mode = input_read_multiplayer_mode();

        if (multiplayer_mode) {
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

        game_app_update_local(&g_app, p1, p2);

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
