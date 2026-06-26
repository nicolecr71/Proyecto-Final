#ifndef SPRITE_BANK_H
#define SPRITE_BANK_H

#include "game/game_config.h"

/*
 * Sprite bank layout — offsets relativos a DDR2_SPRITE_BANK_ADDR.
 * Formato: row-major, uint16_t por pixel, RGB444 nativo de VRAM (0x0RGB).
 *
 *   SPRITE_BALL : BALL_SIZE x BALL_SIZE       =  9 px = 18 bytes  @ 0x0000
 *   SPRITE_P1   : PADDLE_WIDTH x PADDLE_HEIGHT = 60 px = 120 bytes @ 0x0020
 *   SPRITE_P2   : PADDLE_WIDTH x PADDLE_HEIGHT = 60 px = 120 bytes @ 0x00A0
 */

#define SPRITE_BALL_OFFSET    0x0000U
#define SPRITE_BALL_W         ((uint32_t)BALL_SIZE)
#define SPRITE_BALL_H         ((uint32_t)BALL_SIZE)

#define SPRITE_P1_OFFSET      0x0020U
#define SPRITE_P1_W           ((uint32_t)PADDLE_WIDTH)
#define SPRITE_P1_H           ((uint32_t)PADDLE_HEIGHT)

#define SPRITE_P2_OFFSET      0x00A0U
#define SPRITE_P2_W           ((uint32_t)PADDLE_WIDTH)
#define SPRITE_P2_H           ((uint32_t)PADDLE_HEIGHT)

#define SPRITE_BANK_BYTES     0x0118U

#endif
