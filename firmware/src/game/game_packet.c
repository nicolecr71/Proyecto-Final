#include "game/game_packet.h"

/*
 * Simple XOR checksum for input packet.
 *
 * This is lightweight and easy to implement in embedded C.
 * It is not cryptographic; it is only for basic transmission error detection.
 */
static uint8_t checksum_input_packet(const game_input_packet_t *packet)
{
    uint8_t checksum = 0;

    checksum ^= packet->packet_type;
    checksum ^= packet->frame_id;
    checksum ^= packet->up;
    checksum ^= packet->down;
    checksum ^= packet->start;
    checksum ^= packet->reset;

    return checksum;
}

/*
 * Simple XOR checksum for state packet.
 */
static uint8_t checksum_state_packet(const game_state_packet_t *packet)
{
    uint8_t checksum = 0;

    checksum ^= packet->packet_type;

    checksum ^= (uint8_t)(packet->frame_id & 0x00FFU);
    checksum ^= (uint8_t)((packet->frame_id >> 8) & 0x00FFU);

    checksum ^= (uint8_t)(packet->ball_x & 0x00FFU);
    checksum ^= (uint8_t)((packet->ball_x >> 8) & 0x00FFU);

    checksum ^= (uint8_t)(packet->ball_y & 0x00FFU);
    checksum ^= (uint8_t)((packet->ball_y >> 8) & 0x00FFU);

    checksum ^= (uint8_t)(packet->paddle_p1_y & 0x00FFU);
    checksum ^= (uint8_t)((packet->paddle_p1_y >> 8) & 0x00FFU);

    checksum ^= (uint8_t)(packet->paddle_p2_y & 0x00FFU);
    checksum ^= (uint8_t)((packet->paddle_p2_y >> 8) & 0x00FFU);

    checksum ^= packet->score_p1;
    checksum ^= packet->score_p2;
    checksum ^= packet->status;
    checksum ^= packet->winner;
    checksum ^= packet->last_point;

    checksum ^= (uint8_t)(packet->elapsed_seconds & 0x00FFU);
    checksum ^= (uint8_t)((packet->elapsed_seconds >> 8) & 0x00FFU);

    checksum ^= (uint8_t)packet->serve_direction;
    checksum ^= packet->flags;

    return checksum;
}

/*
 * Builds an input packet from player input.
 */
void game_packet_build_input(
    game_input_packet_t *packet,
    player_input_t input,
    uint8_t frame_id
)
{
    packet->packet_type = GAME_PACKET_TYPE_INPUT;
    packet->frame_id = frame_id;

    packet->up = input.up;
    packet->down = input.down;
    packet->start = input.start;
    packet->reset = input.reset;

    packet->checksum = checksum_input_packet(packet);
}

/*
 * Decodes player input from an input packet.
 */
player_input_t game_packet_decode_input(
    const game_input_packet_t *packet
)
{
    player_input_t input;

    input.up = packet->up;
    input.down = packet->down;
    input.start = packet->start;
    input.reset = packet->reset;

    return input;
}

/*
 * Builds a state packet from the official game state.
 */
void game_packet_build_state(
    game_state_packet_t *packet,
    const game_state_t *state
)
{
    packet->packet_type = GAME_PACKET_TYPE_STATE;

    packet->frame_id = state->frame_id;

    packet->ball_x = state->ball_x;
    packet->ball_y = state->ball_y;

    packet->paddle_p1_y = state->paddle_p1_y;
    packet->paddle_p2_y = state->paddle_p2_y;

    packet->score_p1 = state->score_p1;
    packet->score_p2 = state->score_p2;

    packet->status = (uint8_t)state->status;
    packet->winner = state->winner;
    packet->last_point = state->last_point;

    packet->elapsed_seconds = state->elapsed_seconds;

    packet->serve_direction = state->serve_direction;

    packet->flags = state->flags;

    packet->checksum = checksum_state_packet(packet);
}

/*
 * Applies a state packet into a game_state_t structure.
 *
 * Notice:
 * This updates the fields required by the slave to render and synchronize.
 * The slave should not recalculate collisions or score locally.
 */
void game_packet_apply_state(
    game_state_t *state,
    const game_state_packet_t *packet
)
{
    state->frame_id = packet->frame_id;

    state->ball_x = packet->ball_x;
    state->ball_y = packet->ball_y;

    state->paddle_p1_y = packet->paddle_p1_y;
    state->paddle_p2_y = packet->paddle_p2_y;

    state->score_p1 = packet->score_p1;
    state->score_p2 = packet->score_p2;

    state->status = (game_status_t)packet->status;
    state->winner = packet->winner;
    state->last_point = packet->last_point;

    state->elapsed_seconds = packet->elapsed_seconds;

    state->serve_direction = packet->serve_direction;

    state->flags = packet->flags;
}

/*
 * Validates an input packet.
 */
uint8_t game_packet_validate_input(
    const game_input_packet_t *packet
)
{
    if (packet->packet_type != GAME_PACKET_TYPE_INPUT) {
        return 0U;
    }

    return checksum_input_packet(packet) == packet->checksum;
}

/*
 * Validates a state packet.
 */
uint8_t game_packet_validate_state(
    const game_state_packet_t *packet
)
{
    if (packet->packet_type != GAME_PACKET_TYPE_STATE) {
        return 0U;
    }

    return checksum_state_packet(packet) == packet->checksum;
}