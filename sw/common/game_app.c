/**
 * @file game_app.c
 * @brief Capa de aplicacion que selecciona modo local, maestro o esclavo sin modificar las reglas del juego.
 */

#include "game/game_app.h"

/*
 * Initializes the application container.
 */
void game_app_init(
    game_app_t *app,
    game_mode_t mode,
    game_role_t role
)
{
    app->mode = mode;
    app->role = role;

    app->p1 = (player_input_t){0};
    app->p2 = (player_input_t){0};
    app->p2_remote = (player_input_t){0};

    app->remote_state_valid = 0;

    game_init(&app->state);
    game_init(&app->remote_state);
}

/*
 * Local mode:
 * one FPGA reads both players and calculates the complete game state.
 */
void game_app_update_local(
    game_app_t *app,
    player_input_t p1,
    player_input_t p2
)
{
    app->mode = GAME_MODE_LOCAL;
    app->role = GAME_ROLE_NONE;

    app->p1 = p1;
    app->p2 = p2;

    game_update_local(&app->state, app->p1, app->p2);
}

/*
 * SPI multiplayer master:
 * master reads player 1 locally, receives player 2 input from SPI,
 * and calculates the official game state.
 */
void game_app_update_master(
    game_app_t *app,
    player_input_t p1,
    player_input_t p2_remote
)
{
    app->mode = GAME_MODE_SPI_MULTIPLAYER;
    app->role = GAME_ROLE_MASTER;

    app->p1 = p1;
    app->p2_remote = p2_remote;

    game_update_master(&app->state, app->p1, app->p2_remote);
}

/*
 * SPI multiplayer slave:
 * slave reads player 2 locally and applies the official state received
 * from the master.
 */
void game_app_update_slave(
    game_app_t *app,
    player_input_t p2,
    const game_state_t *remote_state,
    uint8_t remote_state_valid
)
{
    app->mode = GAME_MODE_SPI_MULTIPLAYER;
    app->role = GAME_ROLE_SLAVE;

    app->p2 = p2;
    app->remote_state_valid = remote_state_valid;

    if (remote_state_valid) {
        app->remote_state = *remote_state;
        game_apply_remote_state(&app->state, &app->remote_state);
    }
}