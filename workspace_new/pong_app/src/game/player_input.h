#ifndef PLAYER_INPUT_H
#define PLAYER_INPUT_H

#include <stdint.h>

/*
 * Generic player input structure.
 * The source can be local buttons, switches, SPI data, or a test program.
 */
typedef struct {
    uint8_t up;
    uint8_t down;
    uint8_t start;
    uint8_t reset;
} player_input_t;

#endif