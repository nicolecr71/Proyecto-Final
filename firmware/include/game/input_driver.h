#ifndef INPUT_DRIVER_H
#define INPUT_DRIVER_H

#include <stdint.h>
#include "player_input.h"

/*
 * Raw input bit mapping after hardware conditioning:
 *
 * INPUT_DRIVER[0] = left paddle up
 * INPUT_DRIVER[1] = left paddle down
 * INPUT_DRIVER[2] = start
 * INPUT_DRIVER[3] = right paddle up
 * INPUT_DRIVER[4] = right paddle down
 * INPUT_DRIVER[5] = multiplayer mode
 * INPUT_DRIVER[6] = game reset
 * INPUT_DRIVER[7] = frame toggle from VGA_VS
 *
 * Physical mapping on Nexys A7:
 * - C12  = CPU_RESETN, global active-low reset
 * - N17  = BTNC, start
 * - M18  = BTNU, left paddle up
 * - P17  = BTNL, left paddle down
 * - M17  = BTNR, right paddle up
 * - P18  = BTND, right paddle down
 * - SW15 = multiplayer mode, 1 enables SPI
 * - SW0  = game reset
 */
#define INPUT_BIT_LEFT_UP             0x00000001U
#define INPUT_BIT_LEFT_DOWN           0x00000002U
#define INPUT_BIT_START               0x00000004U
#define INPUT_BIT_RIGHT_UP            0x00000008U
#define INPUT_BIT_RIGHT_DOWN          0x00000010U
#define INPUT_BIT_MULTIPLAYER_MODE    0x00000020U
#define INPUT_BIT_GAME_RESET          0x00000040U
#define INPUT_BIT_FRAME_TOGGLE        0x00000080U

/*
 * Compatibility aliases.
 */
#define INPUT_BIT_P1_UP       INPUT_BIT_LEFT_UP
#define INPUT_BIT_P1_DOWN     INPUT_BIT_LEFT_DOWN
#define INPUT_BIT_P1_START    INPUT_BIT_START
#define INPUT_BIT_P1_RESET    0x00000000U

#define INPUT_BIT_P2_UP       INPUT_BIT_RIGHT_UP
#define INPUT_BIT_P2_DOWN     INPUT_BIT_RIGHT_DOWN
#define INPUT_BIT_P2_START    INPUT_BIT_START
#define INPUT_BIT_P2_RESET    0x00000000U

player_input_t input_decode_player1(uint32_t raw_input);
player_input_t input_decode_player2(uint32_t raw_input);

player_input_t input_read_player1(void);
player_input_t input_read_player2(void);

/*
 * Returns 1 when SW15 is high.
 * 0 = solo/local mode
 * 1 = multiplayer/SPI mode
 */
uint8_t input_read_multiplayer_mode(void);
uint8_t input_read_game_reset(void);
uint8_t input_read_frame_toggle(void);
uint32_t input_wait_next_frame(void);

#endif
