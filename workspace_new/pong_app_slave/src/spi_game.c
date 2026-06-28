#include <stdint.h>
#include <string.h>

#include "xparameters.h"

#include "game/spi_game.h"
#include "game/game_packet.h"
#include "game/input_driver.h"

/*
 * SPI multijugador — lado ESCLAVO (puente de hardware).
 *
 * El enlace SPI con la FPGA master lo maneja un esclavo SPI bit-banged en
 * Verilog (spi_game_slave_reference) envuelto por spi_game_slave_bridge.
 * Ese hardware está SIEMPRE listo: responde al SCK/CS del master en cada
 * flanco, sin depender del loop lento del CPU. El CPU solo:
 *
 *   - escribe el input del jugador 2 en un AXI GPIO (canal de salida)
 *   - lee el estado oficial recibido del master desde 3 AXI GPIO (entradas)
 *
 * Esto reemplaza al AXI Quad SPI, que estaba mal configurado como master
 * y nunca podía ser seleccionado/clockeado por la FPGA master.
 *
 * Mapa de registros AXI GPIO (offset estándar Xilinx):
 *   0x00 = canal 1 (GPIO_DATA)
 *   0x08 = canal 2 (GPIO2_DATA)
 *
 *   axi_gpio_spi_a: ch1 <- state_word0,  ch2 <- state_word1   (entradas)
 *   axi_gpio_spi_b: ch1 <- state_word2,  ch2 <- state_word3   (entradas)
 *   axi_gpio_spi_c: ch1 <- state_word4,  ch2 -> p2_in_word    (ch1 in / ch2 out)
 *
 * Empaquetado (ver spi_game_slave_bridge.v):
 *   word0 = { ball_x[15:0],      ball_y[15:0]      }
 *   word1 = { paddle_p1_y[15:0], paddle_p2_y[15:0] }
 *   word2 = { frame_id[15:0],    elapsed_seconds[15:0] }
 *   word3 = { score_p1[7:0], score_p2[7:0], status[7:0], winner[7:0] }
 *   word4 = { last_point[7:0], serve_direction[7:0], flags[7:0], 7'b0, valid_seen }
 *   p2    = { reset, start, down, up }  (bit3..bit0)
 */

/*
 * Direcciones base de los AXI GPIO del puente.
 * Tras agregar el puente al BD y regenerar el BSP, xparameters.h define
 * XPAR_AXI_GPIO_SPI_{A,B,C}_BASEADDR. Si tus instancias tienen otro nombre,
 * defini SPI_BRIDGE_GPIO_{A,B,C}_BASE en los flags del compilador.
 */
#ifndef SPI_BRIDGE_GPIO_A_BASE
#  ifdef XPAR_AXI_GPIO_SPI_A_BASEADDR
#    define SPI_BRIDGE_GPIO_A_BASE ((uintptr_t)XPAR_AXI_GPIO_SPI_A_BASEADDR)
#  else
#    error "Falta XPAR_AXI_GPIO_SPI_A_BASEADDR: regenerar BSP tras agregar el puente, o definir SPI_BRIDGE_GPIO_A_BASE"
#  endif
#endif
#ifndef SPI_BRIDGE_GPIO_B_BASE
#  ifdef XPAR_AXI_GPIO_SPI_B_BASEADDR
#    define SPI_BRIDGE_GPIO_B_BASE ((uintptr_t)XPAR_AXI_GPIO_SPI_B_BASEADDR)
#  else
#    error "Falta XPAR_AXI_GPIO_SPI_B_BASEADDR: regenerar BSP tras agregar el puente, o definir SPI_BRIDGE_GPIO_B_BASE"
#  endif
#endif
#ifndef SPI_BRIDGE_GPIO_C_BASE
#  ifdef XPAR_AXI_GPIO_SPI_C_BASEADDR
#    define SPI_BRIDGE_GPIO_C_BASE ((uintptr_t)XPAR_AXI_GPIO_SPI_C_BASEADDR)
#  else
#    error "Falta XPAR_AXI_GPIO_SPI_C_BASEADDR: regenerar BSP tras agregar el puente, o definir SPI_BRIDGE_GPIO_C_BASE"
#  endif
#endif

#define GPIO_CH1_DATA_OFFSET 0x00U
#define GPIO_CH2_DATA_OFFSET 0x08U

static inline uint32_t gpio_read(uintptr_t base, uint32_t offset)
{
    return *(volatile uint32_t *)(base + offset);
}

static inline void gpio_write(uintptr_t base, uint32_t offset, uint32_t value)
{
    *(volatile uint32_t *)(base + offset) = value;
}

uint8_t spi_game_slave_exchange_input_state(
    player_input_t p2,
    game_state_t *received_state
)
{
    uint32_t word0, word1, word2, word3, word4;
    uint32_t p2_word;
    uint8_t  valid_seen;

    if (received_state == NULL) {
        return 0U;
    }

    /*
     * 1. Publicar el input de p2 hacia el hardware (canal de salida).
     *    El esclavo SPI lo muestrea al inicio de cada transacción del master.
     */
    p2_word = ((uint32_t)(p2.up    ? 1U : 0U) << 0) |
              ((uint32_t)(p2.down  ? 1U : 0U) << 1) |
              ((uint32_t)(p2.start ? 1U : 0U) << 2) |
              ((uint32_t)(p2.reset ? 1U : 0U) << 3);
    gpio_write(SPI_BRIDGE_GPIO_C_BASE, GPIO_CH2_DATA_OFFSET, p2_word);

    /*
     * 2. Leer el estado oficial latcheado por el hardware.
     *    Estos registros solo cambian ante un paquete válido del master,
     *    así que reflejan el último estado bueno recibido.
     */
    word0 = gpio_read(SPI_BRIDGE_GPIO_A_BASE, GPIO_CH1_DATA_OFFSET);
    word1 = gpio_read(SPI_BRIDGE_GPIO_A_BASE, GPIO_CH2_DATA_OFFSET);
    word2 = gpio_read(SPI_BRIDGE_GPIO_B_BASE, GPIO_CH1_DATA_OFFSET);
    word3 = gpio_read(SPI_BRIDGE_GPIO_B_BASE, GPIO_CH2_DATA_OFFSET);
    word4 = gpio_read(SPI_BRIDGE_GPIO_C_BASE, GPIO_CH1_DATA_OFFSET);

    valid_seen = (uint8_t)(word4 & 0x1U);
    if (valid_seen == 0U) {
        /* El enlace aún no ha recibido ningún paquete válido del master. */
        return 0U;
    }

    received_state->ball_x          = (uint16_t)((word0 >> 16) & 0xFFFFU);
    received_state->ball_y          = (uint16_t)(word0 & 0xFFFFU);
    received_state->paddle_p1_y     = (uint16_t)((word1 >> 16) & 0xFFFFU);
    received_state->paddle_p2_y     = (uint16_t)(word1 & 0xFFFFU);
    received_state->frame_id        = (uint16_t)((word2 >> 16) & 0xFFFFU);
    received_state->elapsed_seconds = (uint16_t)(word2 & 0xFFFFU);
    received_state->score_p1        = (uint8_t)((word3 >> 24) & 0xFFU);
    received_state->score_p2        = (uint8_t)((word3 >> 16) & 0xFFU);
    received_state->status          = (game_status_t)((word3 >> 8) & 0xFFU);
    received_state->winner          = (uint8_t)(word3 & 0xFFU);
    received_state->last_point      = (uint8_t)((word4 >> 24) & 0xFFU);
    received_state->serve_direction = (int8_t)((word4 >> 16) & 0xFFU);
    received_state->flags           = (uint8_t)((word4 >> 8) & 0xFFU);

    return 1U;
}

void spi_game_stub_clear(void)
{
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
