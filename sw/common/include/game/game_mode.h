#ifndef GAME_MODE_H
#define GAME_MODE_H

/*
 * Game operation mode.
 *
 * GAME_MODE_LOCAL:
 * One FPGA runs the complete game locally.
 *
 * GAME_MODE_SPI_MULTIPLAYER:
 * Two FPGAs are used. One works as master and the other as slave.
 */
typedef enum {
    GAME_MODE_LOCAL = 0,
    GAME_MODE_SPI_MULTIPLAYER = 1
} game_mode_t;

/*
 * Runtime role.
 *
 * GAME_ROLE_NONE:
 * Used when the game runs locally.
 *
 * GAME_ROLE_MASTER:
 * The FPGA calculates the official game state.
 *
 * GAME_ROLE_SLAVE:
 * The FPGA sends local input and receives the official state.
 */
typedef enum {
    GAME_ROLE_NONE = 0,
    GAME_ROLE_MASTER = 1,
    GAME_ROLE_SLAVE = 2
} game_role_t;

#endif