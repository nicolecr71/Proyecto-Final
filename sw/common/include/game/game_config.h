#ifndef GAME_CONFIG_H
#define GAME_CONFIG_H

/*
 * Game logical resolution.
 * This is independent from the physical VGA resolution.
 * The render module can scale these coordinates later.
 */
#define GAME_WIDTH        160
#define GAME_HEIGHT       120

/*
 * Logical update rate.
 * The game logic should be called at this fixed rate.
 * On PC this is approximated with SDL_Delay().
 * On FPGA this can be driven by a timer interrupt.
 */
#define GAME_TICKS_PER_SECOND 60

/*
 * Paddle configuration.
 */
#define PADDLE_WIDTH      3
#define PADDLE_HEIGHT     20
#define PADDLE_MARGIN     5
#define PADDLE_SPEED      2

/*
 * Ball configuration.
 */
#define BALL_SIZE         3
#define BALL_SPEED_X      1
#define BALL_SPEED_Y      1

/*
 * Match configuration.
 */
#define MAX_SCORE         5

#endif