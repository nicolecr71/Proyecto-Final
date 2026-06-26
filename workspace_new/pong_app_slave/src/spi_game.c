#include <stdint.h>
#include <string.h>

#include "xparameters.h"
#include "xspi.h"
#include "xstatus.h"

#include "game/spi_game.h"
#include "game/game_packet.h"

static XSpi spi_instance;
static uint8_t spi_initialized = 0U;

/*
 * Último frame_id recibido del maestro.
 * Se ecoa de vuelta en el paquete de input del jugador 2.
 */
static uint8_t g_last_frame_id = 0U;

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
    buffer[index]      = (uint8_t)(value & 0x00FFU);
    buffer[index + 1U] = (uint8_t)((value >> 8U) & 0x00FFU);
}

static uint16_t get_u16_le(const uint8_t *buffer, uint32_t index)
{
    return (uint16_t)(
        ((uint16_t)buffer[index]) |
        (((uint16_t)buffer[index + 1U]) << 8U)
    );
}

static int spi_slave_init_hw(void)
{
    int status;

    if (spi_initialized != 0U) {
        return XST_SUCCESS;
    }

#ifdef SDT
    XSpi_Config *config;

    config = XSpi_LookupConfig((UINTPTR)XPAR_AXI_QUAD_SPI_0_BASEADDR);
    if (config == NULL) {
        return XST_FAILURE;
    }

    status = XSpi_CfgInitialize(&spi_instance, config, config->BaseAddress);
    if (status != XST_SUCCESS) {
        return status;
    }
#else
    status = XSpi_Initialize(&spi_instance, XPAR_AXI_QUAD_SPI_0_DEVICE_ID);
    if (status != XST_SUCCESS) {
        return status;
    }
#endif

    /*
     * Modo esclavo SPI:
     *   - Sin XSP_MASTER_OPTION → la FPGA es esclava (no genera SCK ni CS)
     *   - Sin XSP_MANUAL_SSELECT_OPTION → no aplica en modo esclavo
     *   - CPOL=0, CPHA=0 (Modo 0) → coincide con la configuración del maestro
     */
    status = XSpi_SetOptions(&spi_instance, 0U);
    if (status != XST_SUCCESS) {
        return status;
    }

    XSpi_Start(&spi_instance);
    XSpi_IntrGlobalDisable(&spi_instance);

    spi_initialized = 1U;
    return XST_SUCCESS;
}

/*
 * Empaca el input del jugador 2 en los primeros 7 bytes del buffer de TX.
 * Los bytes 7..23 se dejan en 0 (padding — el maestro los ignora).
 */
static void pack_input_wire(
    uint8_t *buffer,
    player_input_t input,
    uint8_t frame_id
)
{
    memset(buffer, 0x00, SPI_GAME_FRAME_WIRE_BYTES);

    buffer[0] = GAME_PACKET_TYPE_INPUT;
    buffer[1] = frame_id;
    buffer[2] = input.up;
    buffer[3] = input.down;
    buffer[4] = input.start;
    buffer[5] = input.reset;
    buffer[6] = xor_checksum(buffer, 6U);
    /* bytes 7..23: ceros, el maestro solo lee bytes 0..6 */
}

/*
 * Desempaca el estado del juego recibido desde el maestro (MOSI).
 * El paquete de estado tiene 24 bytes; el checksum está en byte 23.
 */
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

    state->frame_id         = get_u16_le(buffer, 1U);
    state->ball_x           = get_u16_le(buffer, 3U);
    state->ball_y           = get_u16_le(buffer, 5U);
    state->paddle_p1_y      = get_u16_le(buffer, 7U);
    state->paddle_p2_y      = get_u16_le(buffer, 9U);
    state->score_p1         = buffer[11];
    state->score_p2         = buffer[12];
    state->status           = (game_status_t)buffer[13];
    state->winner           = buffer[14];
    state->last_point       = buffer[15];
    state->elapsed_seconds  = get_u16_le(buffer, 16U);
    state->serve_direction  = (int8_t)buffer[18];
    state->flags            = buffer[19];

    return 1U;
}

/* ------------------------------------------------------------------ */

void spi_game_stub_clear(void)
{
    spi_initialized = 0U;
}

/*
 * Función principal del modo esclavo.
 *
 * Protocolo (24 bytes full-duplex, Mode 0):
 *   MOSI (maestro → esclavo): estado oficial del juego (24 bytes)
 *   MISO (esclavo → maestro): input del jugador 2 (bytes 0..6) + padding
 *
 * Flujo:
 *   1. Se empaca el input de p2 en tx_buffer[0..6], resto = 0.
 *   2. XSpi_Transfer pre-carga el TX FIFO y bloquea hasta que el maestro
 *      inicia la transacción (el maestro es quien genera SCK y CS).
 *   3. Al completar, rx_buffer contiene el estado recibido del maestro.
 *   4. Se desempaca y valida el estado con checksum.
 *
 * Retorna 1 si el estado recibido es válido, 0 si hubo error.
 */
uint8_t spi_game_slave_exchange_input_state(
    player_input_t p2,
    game_state_t *received_state
)
{
    uint8_t tx_buffer[SPI_GAME_FRAME_WIRE_BYTES];
    uint8_t rx_buffer[SPI_GAME_FRAME_WIRE_BYTES];
    int status;
    uint8_t result;

    if (received_state == NULL) {
        return 0U;
    }

    status = spi_slave_init_hw();
    if (status != XST_SUCCESS) {
        return 0U;
    }

    pack_input_wire(tx_buffer, p2, g_last_frame_id);
    memset(rx_buffer, 0x00, sizeof(rx_buffer));

    status = XSpi_Transfer(
        &spi_instance,
        tx_buffer,
        rx_buffer,
        SPI_GAME_FRAME_WIRE_BYTES
    );

    if (status != XST_SUCCESS) {
        return 0U;
    }

    result = unpack_state_wire(rx_buffer, received_state);

    if (result != 0U) {
        g_last_frame_id = (uint8_t)(received_state->frame_id & 0x00FFU);
    }

    return result;
}

/* ---- Stubs de funciones del maestro — no usadas en modo esclavo ---- */

void spi_game_send_player_input(player_input_t input, uint8_t frame_id)
{
    (void)input;
    (void)frame_id;
}

uint8_t spi_game_receive_player_input(player_input_t *input)
{
    (void)input;
    return 0U;
}

void spi_game_send_state(const game_state_t *state)
{
    (void)state;
}

uint8_t spi_game_receive_state(game_state_t *state)
{
    (void)state;
    return 0U;
}

uint8_t spi_game_exchange_state_input(
    const game_state_t *state,
    player_input_t *input
)
{
    (void)state;
    (void)input;
    return 0U;
}
