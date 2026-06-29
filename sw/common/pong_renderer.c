#include <stdint.h>

#include "game/pong_renderer.h"
#include "game/game_config.h"
#include "game/game_params.h"
#include "game/ddr2_memory.h"
#include "game/sprite_bank.h"
#include "vram_memory_map.h"

#define COLOR_BG        VRAM_COLOR_BLACK
#define COLOR_FG        VRAM_COLOR_WHITE
#define COLOR_BALL      VRAM_RGB444(0xF, 0x0, 0x0)

#define BORDER          2U
#define CENTER_W        2U
#define DASH_H          4U
#define DASH_GAP        4U

#define SCORE_Y         8U
#define SCORE_SCALE     2U
#define SCORE_P1_X      ((GAME_WIDTH / 2U) - 20U)
#define SCORE_P2_X      ((GAME_WIDTH / 2U) + 12U)

#ifndef PADDLE_P1_X
#define PADDLE_P1_X     4U
#endif

#ifndef PADDLE_P2_X
#define PADDLE_P2_X     (GAME_WIDTH - 4U - SPRITE_P2_W)
#endif

#define NUM_RENDER_BUFFERS 2U

static game_state_t buffer_prev_state[NUM_RENDER_BUFFERS];
static uint8_t buffer_valid[NUM_RENDER_BUFFERS] = {0U, 0U};
static uint8_t current_render_buffer = 0U;
static uint8_t initial_full_redraw_frames = 4U;

static const uint8_t digit_font_3x5[10][5] = {
    {0x7U, 0x5U, 0x5U, 0x5U, 0x7U},
    {0x2U, 0x6U, 0x2U, 0x2U, 0x7U},
    {0x7U, 0x1U, 0x7U, 0x4U, 0x7U},
    {0x7U, 0x1U, 0x7U, 0x1U, 0x7U},
    {0x5U, 0x5U, 0x7U, 0x1U, 0x1U},
    {0x7U, 0x4U, 0x7U, 0x1U, 0x7U},
    {0x7U, 0x4U, 0x7U, 0x5U, 0x7U},
    {0x7U, 0x1U, 0x1U, 0x1U, 0x1U},
    {0x7U, 0x5U, 0x7U, 0x5U, 0x7U},
    {0x7U, 0x5U, 0x7U, 0x1U, 0x7U}
};

static void draw_rect(uint32_t x0, uint32_t y0, uint32_t w, uint32_t h, uint16_t color)
{
    uint32_t x;
    uint32_t y;
    uint32_t x1 = x0 + w;
    uint32_t y1 = y0 + h;

    if ((x0 >= GAME_WIDTH) || (y0 >= GAME_HEIGHT)) {
        return;
    }

    if (x1 > GAME_WIDTH) {
        x1 = GAME_WIDTH;
    }

    if (y1 > GAME_HEIGHT) {
        y1 = GAME_HEIGHT;
    }

    for (y = y0; y < y1; y++) {
        for (x = x0; x < x1; x++) {
            vram_write_pixel(x, y, color);
        }
    }
}

static void draw_border(void)
{
    draw_rect(0U, 0U, GAME_WIDTH, BORDER, COLOR_FG);
    draw_rect(0U, GAME_HEIGHT - BORDER, GAME_WIDTH, BORDER, COLOR_FG);
    draw_rect(0U, 0U, BORDER, GAME_HEIGHT, COLOR_FG);
    draw_rect(GAME_WIDTH - BORDER, 0U, BORDER, GAME_HEIGHT, COLOR_FG);
}

static void draw_center_line(void)
{
    uint32_t y;
    uint32_t x = (GAME_WIDTH / 2U) - (CENTER_W / 2U);

    for (y = BORDER + 2U; y < (GAME_HEIGHT - BORDER - 2U); y += (DASH_H + DASH_GAP)) {
        draw_rect(x, y, CENTER_W, DASH_H, COLOR_FG);
    }
}

static void draw_digit(uint8_t digit, uint32_t x0, uint32_t y0)
{
    uint32_t row;
    uint32_t col;
    uint8_t bits;

    if (digit > 9U) {
        digit = 9U;
    }

    for (row = 0U; row < 5U; row++) {
        bits = digit_font_3x5[digit][row];

        for (col = 0U; col < 3U; col++) {
            if ((bits & (1U << (2U - col))) != 0U) {
                draw_rect(x0 + (col * SCORE_SCALE),
                          y0 + (row * SCORE_SCALE),
                          SCORE_SCALE,
                          SCORE_SCALE,
                          COLOR_FG);
            }
        }
    }
}

static void clear_score_area(void)
{
    draw_rect(SCORE_P1_X - 3U, SCORE_Y - 3U, 18U, 18U, COLOR_BG);
    draw_rect(SCORE_P2_X - 3U, SCORE_Y - 3U, 18U, 18U, COLOR_BG);
}

static void draw_score(const game_state_t *state)
{
    clear_score_area();
    draw_digit(state->score_p1, SCORE_P1_X, SCORE_Y);
    draw_digit(state->score_p2, SCORE_P2_X, SCORE_Y);
}

static uint8_t glyph5x7(char c, uint8_t row)
{
    static const uint8_t space[7] = {0,0,0,0,0,0,0};

    static const uint8_t A[7] = {0x0E,0x11,0x11,0x1F,0x11,0x11,0x11};
    static const uint8_t C[7] = {0x0E,0x11,0x10,0x10,0x10,0x11,0x0E};
    static const uint8_t E[7] = {0x1F,0x10,0x10,0x1E,0x10,0x10,0x1F};
    static const uint8_t G[7] = {0x0E,0x11,0x10,0x17,0x11,0x11,0x0E};
    static const uint8_t I[7] = {0x1F,0x04,0x04,0x04,0x04,0x04,0x1F};
    static const uint8_t L[7] = {0x10,0x10,0x10,0x10,0x10,0x10,0x1F};
    static const uint8_t M[7] = {0x11,0x1B,0x15,0x15,0x11,0x11,0x11};
    static const uint8_t N[7] = {0x11,0x19,0x15,0x13,0x11,0x11,0x11};
    static const uint8_t O[7] = {0x0E,0x11,0x11,0x11,0x11,0x11,0x0E};
    static const uint8_t P[7] = {0x1E,0x11,0x11,0x1E,0x10,0x10,0x10};
    static const uint8_t Q[7] = {0x0E,0x11,0x11,0x11,0x15,0x12,0x0D};
    static const uint8_t R[7] = {0x1E,0x11,0x11,0x1E,0x14,0x12,0x11};
    static const uint8_t S[7] = {0x0F,0x10,0x10,0x0E,0x01,0x01,0x1E};
    static const uint8_t T[7] = {0x1F,0x04,0x04,0x04,0x04,0x04,0x04};
    static const uint8_t U[7] = {0x11,0x11,0x11,0x11,0x11,0x11,0x0E};
    static const uint8_t V[7] = {0x11,0x11,0x11,0x11,0x11,0x0A,0x04};

    const uint8_t *g = space;

    switch (c) {
        case 'A': g = A; break;
        case 'C': g = C; break;
        case 'E': g = E; break;
        case 'G': g = G; break;
        case 'I': g = I; break;
        case 'L': g = L; break;
        case 'M': g = M; break;
        case 'N': g = N; break;
        case 'O': g = O; break;
        case 'P': g = P; break;
        case 'Q': g = Q; break;
        case 'R': g = R; break;
        case 'S': g = S; break;
        case 'T': g = T; break;
        case 'U': g = U; break;
        case 'V': g = V; break;
        default:  g = space; break;
    }

    return g[row];
}

static uint32_t text_width(const char *text, uint32_t scale)
{
    uint32_t n = 0U;

    while (text[n] != '\0') {
        n++;
    }

    if (n == 0U) {
        return 0U;
    }

    return ((n * 6U) - 1U) * scale;
}

static void draw_text_scaled(const char *text, uint32_t x0, uint32_t y0, uint32_t scale)
{
    uint32_t i = 0U;
    uint32_t row;
    uint32_t col;
    uint8_t bits;

    while (text[i] != '\0') {
        for (row = 0U; row < 7U; row++) {
            bits = glyph5x7(text[i], (uint8_t)row);

            for (col = 0U; col < 5U; col++) {
                if ((bits & (1U << (4U - col))) != 0U) {
                    draw_rect(x0 + ((i * 6U + col) * scale),
                              y0 + (row * scale),
                              scale,
                              scale,
                              COLOR_FG);
                }
            }
        }

        i++;
    }
}

static void draw_text_centered(const char *text, uint32_t y0, uint32_t scale)
{
    uint32_t w = text_width(text, scale);
    uint32_t x = 0U;

    if (w < GAME_WIDTH) {
        x = (GAME_WIDTH - w) / 2U;
    }

    draw_text_scaled(text, x, y0, scale);
}

static void clear_message_area(void)
{
    /*
     * Limpia solo la zona interna del mensaje.
     * No toca los bordes verticales de la cancha.
     */
    draw_rect(BORDER, 48U, GAME_WIDTH - (2U * BORDER), 26U, COLOR_BG);
}

static void draw_status_message(const game_state_t *state)
{
    if (state->status == GAME_WAITING) {
        draw_text_centered("START", 54U, 2U);
    } else if (state->status == GAME_OVER) {
        if (state->score_p1 >= g_game_params.max_score) {
            draw_text_centered("EQUIPO MAESTRO GANA", 56U, 1U);
        } else if (state->score_p2 >= g_game_params.max_score) {
            draw_text_centered("EQUIPO ESCLAVO GANA", 56U, 1U);
        }
    }
}

static void draw_sprite_bw(uint32_t x0, uint32_t y0, uint32_t w, uint32_t h, uint32_t bank_offset)
{
    uint32_t x;
    uint32_t y;
    uint16_t px;

    const volatile uint16_t *base =
        (const volatile uint16_t *)(DDR2_SPRITE_BANK_ADDR + (uintptr_t)bank_offset);

    for (y = 0U; y < h; y++) {
        for (x = 0U; x < w; x++) {
            px = base[y * w + x];

            if (px != 0U) {
                if (((x0 + x) < GAME_WIDTH) && ((y0 + y) < GAME_HEIGHT)) {
                    vram_write_pixel(x0 + x, y0 + y, COLOR_FG);
                }
            }
        }
    }
}


static void draw_sprite_color(uint32_t x0,
                              uint32_t y0,
                              uint32_t w,
                              uint32_t h,
                              uint32_t bank_offset,
                              uint16_t color)
{
    uint32_t x;
    uint32_t y;
    uint16_t px;

    const volatile uint16_t *base =
        (const volatile uint16_t *)(DDR2_SPRITE_BANK_ADDR + (uintptr_t)bank_offset);

    for (y = 0U; y < h; y++) {
        for (x = 0U; x < w; x++) {
            px = base[y * w + x];

            if (px != 0U) {
                if (((x0 + x) < GAME_WIDTH) && ((y0 + y) < GAME_HEIGHT)) {
                    vram_write_pixel(x0 + x, y0 + y, color);
                }
            }
        }
    }
}

static void erase_objects(const game_state_t *state)
{
    draw_rect(PADDLE_P1_X, state->paddle_p1_y, SPRITE_P1_W, SPRITE_P1_H, COLOR_BG);
    draw_rect(PADDLE_P2_X, state->paddle_p2_y, SPRITE_P2_W, SPRITE_P2_H, COLOR_BG);
    draw_rect(state->ball_x, state->ball_y, SPRITE_BALL_W, SPRITE_BALL_H, COLOR_BG);
}

static void draw_objects(const game_state_t *state)
{
    draw_sprite_bw(PADDLE_P1_X,
                   state->paddle_p1_y,
                   SPRITE_P1_W,
                   SPRITE_P1_H,
                   SPRITE_P1_OFFSET);

    draw_sprite_bw(PADDLE_P2_X,
                   state->paddle_p2_y,
                   SPRITE_P2_W,
                   SPRITE_P2_H,
                   SPRITE_P2_OFFSET);

    /*
     * La bola solo se dibuja durante el juego activo.
     * No aparece en START ni cuando el juego terminó.
     */
    if ((state->status != GAME_WAITING) && (state->status != GAME_OVER)) {
        draw_sprite_color(state->ball_x,
                          state->ball_y,
                          SPRITE_BALL_W,
                          SPRITE_BALL_H,
                          SPRITE_BALL_OFFSET,
                          COLOR_BALL);
    }
}

static void draw_static_scene(void)
{
    draw_border();
    draw_center_line();
}

static void draw_full_scene(const game_state_t *state)
{
    vram_clear(COLOR_BG);
    draw_static_scene();
    draw_score(state);
    clear_message_area();
    draw_status_message(state);
    draw_objects(state);
}

static void render_dirty_scene(uint8_t slot, const game_state_t *state)
{
    const game_state_t *old = &buffer_prev_state[slot];

    /*
     * Este es el punto clave:
     * Se borra lo que estaba dibujado en ESTE MISMO buffer,
     * no lo que estaba en el frame inmediatamente anterior.
     */
    if (buffer_valid[slot] != 0U) {
        erase_objects(old);

        if (old->status != state->status) {
            clear_message_area();
        }
    }

    draw_static_scene();
    draw_score(state);

    if ((state->status == GAME_WAITING) || (state->status == GAME_OVER)) {
        clear_message_area();
        draw_status_message(state);
    }

    draw_objects(state);

    buffer_prev_state[slot] = *state;
    buffer_valid[slot] = 1U;
}

void pong_render_state(const game_state_t *state)
{
    uint8_t slot = current_render_buffer;

    /*
     * Inicializamos ambos buffers varias veces para que no queden residuos.
     * Después de esto no se vuelve a limpiar toda la pantalla.
     */
    if (initial_full_redraw_frames > 0U) {
        draw_full_scene(state);
        buffer_prev_state[slot] = *state;
        buffer_valid[slot] = 1U;
        initial_full_redraw_frames--;
    } else {
        render_dirty_scene(slot, state);
    }

    current_render_buffer ^= 1U;
}
