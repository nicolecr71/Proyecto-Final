#include <stdint.h>
#include <string.h>

#include "xparameters.h"
#include "xspi.h"
#include "xstatus.h"

#include "game/spi_game.h"
#include "game/game_packet.h"

#define SPI_GAME_SS_MASK 0x01U

static XSpi spi_instance;
static uint8_t spi_initialized = 0U;

static uint8_t xor_checksum(const uint8_t *buffer, uint32_t length)
{
    uint8_t checksum = 0U;
    uint32_t i;

    for (i = 0U; i < length; i++) {
        checksum ^= buffer[i];
    }

    return checksum;
}

static void put_u16_le(uint8_t *buffer, uint32_t index, uint16_t value)
{
    buffer[index] = (uint8_t)(value & 0x00FFU);
    buffer[index + 1U] = (uint8_t)((value >> 8) & 0x00FFU);
}

static uint16_t get_u16_le(const uint8_t *buffer, uint32_t index)
{
    return (uint16_t)(
        ((uint16_t)buffer[index]) |
        (((uint16_t)buffer[index + 1U]) << 8)
    );
}

static int spi_game_init_hw(void)
{
    int status;

    if (spi_initialized != 0U) {
        return XST_SUCCESS;
    }

#ifdef SDT
    XSpi_Config *config;

    config = XSpi_LookupConfig((UINTPTR)XPAR_XSPI_0_BASEADDR);
    if (config == NULL) {
        return XST_FAILURE;
    }

    status = XSpi_CfgInitialize(&spi_instance, config, config->BaseAddress);
    if (status != XST_SUCCESS) {
        return status;
    }
#else
    status = XSpi_Initialize(&spi_instance, XPAR_XSPI_0_DEVICE_ID);
    if (status != XST_SUCCESS) {
        return status;
    }
#endif

    status = XSpi_SetOptions(
        &spi_instance,
        XSP_MASTER_OPTION | XSP_MANUAL_SSELECT_OPTION
    );
    if (status != XST_SUCCESS) {
        return status;
    }

    XSpi_Start(&spi_instance);
    XSpi_IntrGlobalDisable(&spi_instance);

    status = XSpi_SetSlaveSelect(&spi_instance, SPI_GAME_SS_MASK);
    if (status != XST_SUCCESS) {
        return status;
    }

    spi_initialized = 1U;
    return XST_SUCCESS;
}

static uint8_t spi_game_transfer_bytes(
    const uint8_t *tx_buffer,
    uint8_t *rx_buffer,
    uint32_t length
)
{
    int status;

    if ((tx_buffer == NULL) || (rx_buffer == NULL) || (length == 0U)) {
        return 0U;
    }

    status = spi_game_init_hw();
    if (status != XST_SUCCESS) {
        return 0U;
    }

    status = XSpi_SetSlaveSelect(&spi_instance, SPI_GAME_SS_MASK);
    if (status != XST_SUCCESS) {
        return 0U;
    }

    status = XSpi_Transfer(
        &spi_instance,
        (uint8_t *)tx_buffer,
        rx_buffer,
        length
    );

    if (status != XST_SUCCESS) {
        return 0U;
    }

    return 1U;
}

static void pack_input_wire(
    uint8_t *buffer,
    player_input_t input,
    uint8_t frame_id
)
{
    memset(buffer, 0x00, SPI_GAME_INPUT_WIRE_BYTES);

    buffer[0] = GAME_PACKET_TYPE_INPUT;
    buffer[1] = frame_id;
    buffer[2] = input.up;
    buffer[3] = input.down;
    buffer[4] = input.start;
    buffer[5] = input.reset;
    buffer[6] = xor_checksum(buffer, 6U);
}

static uint8_t unpack_input_wire(
    const uint8_t *buffer,
    player_input_t *input
)
{
    uint8_t checksum;

    if ((buffer == NULL) || (input == NULL)) {
        return 0U;
    }

    if (buffer[0] != GAME_PACKET_TYPE_INPUT) {
        return 0U;
    }

    checksum = xor_checksum(buffer, 6U);
    if (checksum != buffer[6]) {
        return 0U;
    }

    input->up = buffer[2];
    input->down = buffer[3];
    input->start = buffer[4];
    input->reset = buffer[5];

    return 1U;
}

static void pack_state_wire(
    uint8_t *buffer,
    const game_state_t *state
)
{
    memset(buffer, 0x00, SPI_GAME_STATE_WIRE_BYTES);

    buffer[0] = GAME_PACKET_TYPE_STATE;

    put_u16_le(buffer, 1U, state->frame_id);
    put_u16_le(buffer, 3U, state->ball_x);
    put_u16_le(buffer, 5U, state->ball_y);
    put_u16_le(buffer, 7U, state->paddle_p1_y);
    put_u16_le(buffer, 9U, state->paddle_p2_y);

    buffer[11] = state->score_p1;
    buffer[12] = state->score_p2;
    buffer[13] = (uint8_t)state->status;
    buffer[14] = state->winner;
    buffer[15] = state->last_point;

    put_u16_le(buffer, 16U, state->elapsed_seconds);

    buffer[18] = (uint8_t)state->serve_direction;
    buffer[19] = state->flags;

    buffer[20] = 0U;
    buffer[21] = 0U;
    buffer[22] = 0U;
    buffer[23] = xor_checksum(buffer, 23U);
}

static uint8_t unpack_state_wire(
    const uint8_t *buffer,
    game_state_t *state
)
{
    uint8_t checksum;

    if ((buffer == NULL) || (state == NULL)) {
        return 0U;
    }

    if (buffer[0] != GAME_PACKET_TYPE_STATE) {
        return 0U;
    }

    checksum = xor_checksum(buffer, 23U);
    if (checksum != buffer[23]) {
        return 0U;
    }

    state->frame_id = get_u16_le(buffer, 1U);
    state->ball_x = get_u16_le(buffer, 3U);
    state->ball_y = get_u16_le(buffer, 5U);
    state->paddle_p1_y = get_u16_le(buffer, 7U);
    state->paddle_p2_y = get_u16_le(buffer, 9U);

    state->score_p1 = buffer[11];
    state->score_p2 = buffer[12];
    state->status = (game_status_t)buffer[13];
    state->winner = buffer[14];
    state->last_point = buffer[15];

    state->elapsed_seconds = get_u16_le(buffer, 16U);
    state->serve_direction = (int8_t)buffer[18];
    state->flags = buffer[19];

    return 1U;
}

void spi_game_stub_clear(void)
{
    spi_initialized = 0U;
}

void spi_game_send_player_input(
    player_input_t input,
    uint8_t frame_id
)
{
    uint8_t tx_buffer[SPI_GAME_INPUT_WIRE_BYTES];
    uint8_t rx_buffer[SPI_GAME_INPUT_WIRE_BYTES];

    pack_input_wire(tx_buffer, input, frame_id);
    memset(rx_buffer, 0x00, sizeof(rx_buffer));

    (void)spi_game_transfer_bytes(
        tx_buffer,
        rx_buffer,
        SPI_GAME_INPUT_WIRE_BYTES
    );
}

uint8_t spi_game_receive_player_input(
    player_input_t *input
)
{
    uint8_t tx_buffer[SPI_GAME_INPUT_WIRE_BYTES];
    uint8_t rx_buffer[SPI_GAME_INPUT_WIRE_BYTES];

    if (input == NULL) {
        return 0U;
    }

    memset(tx_buffer, 0x00, sizeof(tx_buffer));
    memset(rx_buffer, 0x00, sizeof(rx_buffer));

    if (!spi_game_transfer_bytes(
            tx_buffer,
            rx_buffer,
            SPI_GAME_INPUT_WIRE_BYTES
        )) {
        return 0U;
    }

    return unpack_input_wire(rx_buffer, input);
}

void spi_game_send_state(
    const game_state_t *state
)
{
    uint8_t tx_buffer[SPI_GAME_STATE_WIRE_BYTES];
    uint8_t rx_buffer[SPI_GAME_STATE_WIRE_BYTES];

    if (state == NULL) {
        return;
    }

    pack_state_wire(tx_buffer, state);
    memset(rx_buffer, 0x00, sizeof(rx_buffer));

    (void)spi_game_transfer_bytes(
        tx_buffer,
        rx_buffer,
        SPI_GAME_STATE_WIRE_BYTES
    );
}

uint8_t spi_game_receive_state(
    game_state_t *state
)
{
    uint8_t tx_buffer[SPI_GAME_STATE_WIRE_BYTES];
    uint8_t rx_buffer[SPI_GAME_STATE_WIRE_BYTES];

    if (state == NULL) {
        return 0U;
    }

    memset(tx_buffer, 0x00, sizeof(tx_buffer));
    memset(rx_buffer, 0x00, sizeof(rx_buffer));

    if (!spi_game_transfer_bytes(
            tx_buffer,
            rx_buffer,
            SPI_GAME_STATE_WIRE_BYTES
        )) {
        return 0U;
    }

    return unpack_state_wire(rx_buffer, state);
}

uint8_t spi_game_exchange_state_input(
    const game_state_t *state,
    player_input_t *input
)
{
    uint8_t tx_buffer[SPI_GAME_FRAME_WIRE_BYTES];
    uint8_t rx_buffer[SPI_GAME_FRAME_WIRE_BYTES];

    if ((state == NULL) || (input == NULL)) {
        return 0U;
    }

    pack_state_wire(tx_buffer, state);
    memset(rx_buffer, 0x00, sizeof(rx_buffer));

    if (!spi_game_transfer_bytes(
            tx_buffer,
            rx_buffer,
            SPI_GAME_FRAME_WIRE_BYTES
        )) {
        return 0U;
    }

    return unpack_input_wire(rx_buffer, input);
}
