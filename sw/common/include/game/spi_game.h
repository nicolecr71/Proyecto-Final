#ifndef SPI_GAME_H
#define SPI_GAME_H

#include <stdint.h>

#include "player_input.h"
#include "game_state.h"

#define SPI_GAME_INPUT_WIRE_BYTES  7U
#define SPI_GAME_STATE_WIRE_BYTES  24U
#define SPI_GAME_FRAME_WIRE_BYTES  SPI_GAME_STATE_WIRE_BYTES

/*
 * SPI game communication layer.
 *
 * Master FPGA:
 * - owns the official Pong state
 * - sends game state through MOSI
 * - receives remote player input through MISO
 *
 * Slave FPGA:
 * - reads remote controls
 * - sends player 2 input through MISO
 * - receives official state through MOSI
 */

void spi_game_send_player_input(
    player_input_t input,
    uint8_t frame_id
);

uint8_t spi_game_receive_player_input(
    player_input_t *input
);

void spi_game_send_state(
    const game_state_t *state
);

uint8_t spi_game_receive_state(
    game_state_t *state
);

/*
 * Main master-side SPI transaction.
 *
 * One 24-byte full-duplex transaction:
 * - MOSI: official game state from master
 * - MISO: player 2 input from slave in the first 7 bytes
 *
 * Returns:
 * 1 = valid remote input received
 * 0 = SPI transfer failed or invalid packet
 */
uint8_t spi_game_exchange_state_input(
    const game_state_t *state,
    player_input_t *input
);

void spi_game_stub_clear(void);

#endif
