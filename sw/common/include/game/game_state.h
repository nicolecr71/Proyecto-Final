#ifndef GAME_STATE_H
#define GAME_STATE_H

#include <stdint.h>

/*
 * General status of the game.
 */
typedef enum {
    GAME_WAITING = 0,
    GAME_RUNNING = 1,
    GAME_PAUSED  = 2,
    GAME_OVER    = 3
} game_status_t;

/*
 * Event flags.
 * These are useful for rendering, debugging, SPI synchronization,
 * sound effects, or showing messages on screen.
 */
#define GAME_FLAG_NONE        0x00
#define GAME_FLAG_P1_SCORED   0x01
#define GAME_FLAG_P2_SCORED   0x02
#define GAME_FLAG_ROUND_RESET 0x04
#define GAME_FLAG_GAME_OVER   0x08

/*
 * Complete logical state of the Pong game.
 * This structure is shared by:
 * - game logic
 * - render module
 * - SPI protocol
 * - master/slave synchronization
 * - future DDR2 or VRAM mapping
 */
typedef struct {
    uint16_t ball_x;
    uint16_t ball_y;

    int16_t ball_vx;
    int16_t ball_vy;

    uint16_t paddle_p1_y;
    uint16_t paddle_p2_y;

    uint8_t score_p1;
    uint8_t score_p2;

    uint8_t winner;

    /*
     * Event flags are cleared on each update cycle.
     * They indicate what happened in the most recent logic update.
     */
    uint8_t flags;

    /*
     * Frame counter for synchronization/debug.
     */
    uint16_t frame_id;

    /*
     * Time counters for HUD, synchronization and debugging.
     * game_ticks counts total updates since the match started.
     * round_ticks counts updates since the last round reset.
     * elapsed_seconds is derived from game_ticks.
     */
    uint32_t game_ticks;
    uint32_t round_ticks;
    uint16_t elapsed_seconds;

    /*
     * Last player who scored:
     * 0 = nobody
     * 1 = player 1
     * 2 = player 2
     */
    uint8_t last_point;

    /*
     * Current serve direction:
     * +1 = ball moves to the right
     * -1 = ball moves to the left
     */
    int8_t serve_direction;

    game_status_t status;
} game_state_t;

#endif