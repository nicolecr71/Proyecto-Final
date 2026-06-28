#ifndef PONG_RENDERER_H
#define PONG_RENDERER_H

#include "game_state.h"

/*
 * Draws the current Pong state into the memory-mapped VRAM.
 */
void pong_render_state(const game_state_t *state);

#endif
