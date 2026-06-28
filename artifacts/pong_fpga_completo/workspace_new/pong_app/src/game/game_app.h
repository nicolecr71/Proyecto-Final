#ifndef GAME_APP_H
#define GAME_APP_H

#include <stdint.h>

#include "game_mode.h"
#include "game_logic.h"
#include "player_input.h"
#include "game_state.h"

/*
 * Runtime application container.
 *
 * This structure groups the current game mode, the FPGA role,
 * local inputs, remote inputs and the official game state.
 */
typedef struct {
    game_mode_t mode;
    game_role_t role;

    game_state_t state;
    game_state_t remote_state;

    player_input_t p1;
    player_input_t p2;
    player_input_t p2_remote;

    uint8_t remote_state_valid;
} game_app_t;

/*
 * Initializes the application layer.
 */
void game_app_init(
    game_app_t *app,
    game_mode_t mode,
    game_role_t role
);

/*
 * Local mode update.
 * Used when one FPGA reads both players.
 */
void game_app_update_local(
    game_app_t *app,
    player_input_t p1,
    player_input_t p2
);

/*
 * Master update.
 * Used when this FPGA is the SPI master.
 */
void game_app_update_master(
    game_app_t *app,
    player_input_t p1,
    player_input_t p2_remote
);

/*
 * Slave update.
 * Used when this FPGA is the SPI slave.
 */
void game_app_update_slave(
    game_app_t *app,
    player_input_t p2,
    const game_state_t *remote_state,
    uint8_t remote_state_valid
);

#endif