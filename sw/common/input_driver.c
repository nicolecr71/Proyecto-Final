#include <stdint.h>

#include "game/input_driver.h"

#ifdef __has_include
#  if __has_include("xparameters.h")
#    include "xparameters.h"
#  endif
#endif

/*
 * AXI GPIO input register.
 *
 * The current block design maps axi_gpio_0 at 0x40000000.
 * The external physical inputs are conditioned in hardware before reaching
 * INPUT_DRIVER[7:0].
 */
#define INPUT_GPIO_DATA_OFFSET 0x00000000U
#define INPUT_FRAME_WAIT_TIMEOUT 200000U

#ifndef INPUT_DRIVER_BASE_ADDR
#  ifdef XPAR_INPUT_DRIVER_BASEADDR
#    define INPUT_DRIVER_BASE_ADDR ((uintptr_t)XPAR_INPUT_DRIVER_BASEADDR)
#  elif defined(XPAR_AXI_GPIO_0_BASEADDR)
#    define INPUT_DRIVER_BASE_ADDR ((uintptr_t)XPAR_AXI_GPIO_0_BASEADDR)
#  else
#    define INPUT_DRIVER_BASE_ADDR ((uintptr_t)0x40000000U)
#  endif
#endif

static uint32_t input_read_raw(void)
{
    volatile uint32_t *gpio_data;

    gpio_data = (volatile uint32_t *)(INPUT_DRIVER_BASE_ADDR + INPUT_GPIO_DATA_OFFSET);

    return (*gpio_data) & 0x000000FFU;
}

player_input_t input_decode_player1(uint32_t raw_input)
{
    player_input_t input;

    input.up    = (raw_input & INPUT_BIT_P1_UP)    ? 1U : 0U;
    input.down  = (raw_input & INPUT_BIT_P1_DOWN)  ? 1U : 0U;
    input.start = (raw_input & INPUT_BIT_P1_START) ? 1U : 0U;

    /*
     * C12 is now the global hardware reset.
     * It is not decoded as a game input bit.
     */
    input.reset = 0U;

    return input;
}

player_input_t input_decode_player2(uint32_t raw_input)
{
    player_input_t input;

    input.up    = (raw_input & INPUT_BIT_P2_UP)    ? 1U : 0U;
    input.down  = (raw_input & INPUT_BIT_P2_DOWN)  ? 1U : 0U;
    input.start = (raw_input & INPUT_BIT_P2_START) ? 1U : 0U;

    /*
     * C12 is now the global hardware reset.
     * It is not decoded as a game input bit.
     */
    input.reset = 0U;

    return input;
}

player_input_t input_read_player1(void)
{
    return input_decode_player1(input_read_raw());
}

player_input_t input_read_player2(void)
{
    return input_decode_player2(input_read_raw());
}

uint8_t input_read_multiplayer_mode(void)
{
    return (input_read_raw() & INPUT_BIT_MULTIPLAYER_MODE) ? 1U : 0U;
}

uint8_t input_read_game_reset(void)
{
    return (input_read_raw() & INPUT_BIT_GAME_RESET) ? 1U : 0U;
}


uint8_t input_read_frame_toggle(void)
{
    return (input_read_raw() & INPUT_BIT_FRAME_TOGGLE) ? 1U : 0U;
}

uint32_t input_wait_next_frame(void)
{
    uint8_t frame_now;
    uint32_t timeout;

    frame_now = input_read_frame_toggle();
    timeout = INPUT_FRAME_WAIT_TIMEOUT;

    while ((input_read_frame_toggle() == frame_now) && (timeout > 0U)) {
        timeout--;
    }

    return timeout;
}
