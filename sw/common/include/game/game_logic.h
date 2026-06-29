#ifndef GAME_LOGIC_H
#define GAME_LOGIC_H

#include <stdint.h>
#include "game_state.h"
#include "player_input.h"

/*
 * Initializes the complete game state.
 */
void game_init(game_state_t *state);

/*
 * Updates the game when a single FPGA runs both players locally.
 */
void game_update_local(
    game_state_t *state,
    player_input_t p1,
    player_input_t p2
);

/*
 * Updates the official game state when this FPGA acts as master.
 */
void game_update_master(
    game_state_t *state,
    player_input_t p1,
    player_input_t p2_remote
);

/*
 * Applies the official state received from the master.
 * Used by the slave FPGA.
 */
void game_apply_remote_state(
    game_state_t *state,
    const game_state_t *remote_state
);

/*
 * Resets ball and paddle positions without clearing the score.
 */
void game_reset_round(game_state_t *state);

/*
 * Returns 1 when the match has ended.
 */
uint8_t game_is_over(const game_state_t *state);

#endif