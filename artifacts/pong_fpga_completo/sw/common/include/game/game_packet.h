#ifndef GAME_PACKET_H
#define GAME_PACKET_H

#include <stdint.h>

#include "game_state.h"
#include "player_input.h"

/*
 * Packet types used by the SPI multiplayer link.
 */
#define GAME_PACKET_TYPE_INPUT 0x01U
#define GAME_PACKET_TYPE_STATE 0x02U

/*
 * Input packet:
 * Sent from slave FPGA to master FPGA.
 *
 * This packet contains the local input of player 2.
 */
typedef struct {
    uint8_t packet_type;
    uint8_t frame_id;

    uint8_t up;
    uint8_t down;
    uint8_t start;
    uint8_t reset;

    uint8_t checksum;
} game_input_packet_t;

/*
 * State packet:
 * Sent from master FPGA to slave FPGA.
 *
 * This packet contains the official game state calculated by the master.
 */
typedef struct {
    uint8_t packet_type;

    uint16_t frame_id;

    uint16_t ball_x;
    uint16_t ball_y;

    uint16_t paddle_p1_y;
    uint16_t paddle_p2_y;

    uint8_t score_p1;
    uint8_t score_p2;

    uint8_t status;
    uint8_t winner;
    uint8_t last_point;

    uint16_t elapsed_seconds;

    int8_t serve_direction;

    uint8_t flags;
    uint8_t checksum;
} game_state_packet_t;

/*
 * Builds an input packet from player input.
 */
void game_packet_build_input(
    game_input_packet_t *packet,
    player_input_t input,
    uint8_t frame_id
);

/*
 * Decodes player input from an input packet.
 */
player_input_t game_packet_decode_input(
    const game_input_packet_t *packet
);

/*
 * Builds a state packet from the official game state.
 */
void game_packet_build_state(
    game_state_packet_t *packet,
    const game_state_t *state
);

/*
 * Applies a state packet into a game_state_t structure.
 * This is mainly used by the slave FPGA.
 */
void game_packet_apply_state(
    game_state_t *state,
    const game_state_packet_t *packet
);

/*
 * Validates packet checksums.
 */
uint8_t game_packet_validate_input(
    const game_input_packet_t *packet
);

uint8_t game_packet_validate_state(
    const game_state_packet_t *packet
);

#endif