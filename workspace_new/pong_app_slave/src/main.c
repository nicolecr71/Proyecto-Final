#include <stdint.h>

#include "game/game_app.h"
#include "game/input_driver.h"
#include "game/pong_renderer.h"
#include "game/spi_game.h"
#include "game/video_sync.h"
#include "game/ddr2_memory.h"
#include "game/ddr2_sections.h"
#include "game/game_params.h"
#include "game/sd_loader.h"
#include "vram_memory_map.h"

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
    game_state_t remote_state;
    uint8_t multiplayer_mode;
    uint8_t game_reset;
    uint8_t game_reset_prev;
    uint8_t ddr2_ok;
    uint8_t sd_ok;
    uint8_t state_valid;

    game_reset_prev = 0U;

    delay_cycles(2000000U);

    ddr2_ok = ddr2_self_test();

    if (ddr2_ok != 0U) {
        ddr2_init_game_config();
        ddr2_init_demo_sprite_bank();
    }

    sd_ok = sd_loader_init();
    if (sd_ok != 0U) {
        (void)sd_loader_load_resources();
    }

    game_params_load_from_ddr2();

    game_app_init(&g_app, GAME_MODE_LOCAL, GAME_ROLE_NONE);

    if (ddr2_ok != 0U) {
        ddr2_store_game_state(&g_app.state);
    }

    pong_render_state(&g_app.state);
    vram_request_buffer_swap();
    input_wait_next_frame();

    while (1) {
        multiplayer_mode = input_read_multiplayer_mode();

        if (!multiplayer_mode) {
            /*
             * SW15 = 0: local pong.
             * Esta FPGA corre el juego de forma independiente.
             * Paleta izquierda = jugador 1, derecha = jugador 2.
             */
            p1 = input_read_player1();
            p2 = input_read_player2();

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

        } else {
            /*
             * SW15 = 1: multijugador SPI, modo esclavo.
             *
             * El maestro (FPGA master) controla el estado oficial del juego.
             * Esta FPGA lee el joystick del jugador 2 (paleta derecha),
             * lo envía por MISO y recibe el estado actualizado por MOSI.
             *
             * spi_game_slave_exchange_input_state() pre-carga el TX FIFO
             * con el input del jugador 2 y luego bloquea hasta que el
             * maestro inicia la transacción SPI (24 bytes full-duplex).
             */
            p2 = input_read_player2();

            state_valid = spi_game_slave_exchange_input_state(p2, &remote_state);

            game_app_update_slave(&g_app, p2, &remote_state, state_valid);

            if (ddr2_ok != 0U) {
                ddr2_store_game_state(&g_app.state);
            }

            pong_render_state(&g_app.state);
            vram_request_buffer_swap();
            /* El SPI del master ya da el timing de frame.
             * El swap lo sincroniza el hardware en el próximo vsync
             * del slave, que cae dentro de la espera del siguiente SPI. */
        }
    }

    return 0;
}
