#include <stdint.h>

#include "game/pong_renderer.h"
#include "game/game_config.h"
#include "game/game_params.h"
#include "game/ddr2_memory.h"
#include "game/sprite_bank.h"
#include "vram_memory_map.h"

#define PONG_COLOR_BACKGROUND  VRAM_COLOR_BLACK
#define PONG_COLOR_FOREGROUND  VRAM_COLOR_WHITE
#define PONG_COLOR_DIM         VRAM_COLOR_GRAY
#define PONG_COLOR_P1          VRAM_RGB444(0x0, 0xF, 0xF)
#define PONG_COLOR_P2          VRAM_RGB444(0xF, 0xA, 0x0)

#define SCREEN_CENTER_LEFT_X   ((GAME_WIDTH / 2U) - 1U)

#define CENTER_LINE_WIDTH      2U
#define CENTER_DASH_HEIGHT     4U
#define CENTER_DASH_GAP        4U
#define CENTER_LINE_START_Y    16U
#define CENTER_LINE_END_Y      (GAME_HEIGHT - 2U)

#define SCORE_BLOCK_WIDTH      3U
#define SCORE_BLOCK_HEIGHT     5U
#define SCORE_BLOCK_GAP        2U
#define SCORE_Y                4U
#define SCORE_CENTER_GAP       6U
#define SCORE_P2_X             ((GAME_WIDTH / 2U) + SCORE_CENTER_GAP)

#define WAIT_BAR_WIDTH         28U
#define WAIT_BAR_HEIGHT        3U
#define WAIT_BAR_Y             20U

#define WIN_BAR_WIDTH          64U
#define WIN_BAR_HEIGHT         3U
#define WIN_BAR_Y              20U

static uint32_t score_max_width(void)
{
    uint32_t n = (uint32_t)g_game_params.max_score;
    return (n * SCORE_BLOCK_WIDTH) + ((n - 1U) * SCORE_BLOCK_GAP);
}

static uint32_t score_p1_x(void)
{
    return SCREEN_CENTER_LEFT_X - SCORE_CENTER_GAP - score_max_width() + 1U;
}

static void draw_rect(uint32_t x0, uint32_t y0, uint32_t w, uint32_t h, uint16_t color)
{
    uint32_t x;
    uint32_t y;

    for (y = y0; y < (y0 + h); y++) {
        for (x = x0; x < (x0 + w); x++) {
            vram_write_pixel(x, y, color);
        }
    }
}

static void draw_centered_rect(uint32_t y0, uint32_t w, uint32_t h, uint16_t color)
{
    draw_rect((GAME_WIDTH - w) / 2U, y0, w, h, color);
}

static void draw_sprite(uint32_t x0, uint32_t y0, uint32_t w, uint32_t h, uint32_t bank_offset)
{
    uint32_t x;
    uint32_t y;
    const volatile uint16_t *base =
        (const volatile uint16_t *)(DDR2_SPRITE_BANK_ADDR + (uintptr_t)bank_offset);

    for (y = 0U; y < h; y++) {
        for (x = 0U; x < w; x++) {
            vram_write_pixel(x0 + x, y0 + y, base[y * w + x]);
        }
    }
}

static void draw_border(void)
{
    uint32_t x;
    uint32_t y;

    for (x = 0U; x < GAME_WIDTH; x++) {
        vram_write_pixel(x, 0U, PONG_COLOR_DIM);
        vram_write_pixel(x, GAME_HEIGHT - 1U, PONG_COLOR_DIM);
    }

    for (y = 0U; y < GAME_HEIGHT; y++) {
        vram_write_pixel(0U, y, PONG_COLOR_DIM);
        vram_write_pixel(GAME_WIDTH - 1U, y, PONG_COLOR_DIM);
    }
}

static void draw_center_line(void)
{
    uint32_t y;
    uint32_t dash_end;

    for (y = CENTER_LINE_START_Y; y < CENTER_LINE_END_Y; y += (CENTER_DASH_HEIGHT + CENTER_DASH_GAP)) {
        dash_end = y + CENTER_DASH_HEIGHT;
        if (dash_end > CENTER_LINE_END_Y) {
            dash_end = CENTER_LINE_END_Y;
        }
        draw_rect(SCREEN_CENTER_LEFT_X, y, CENTER_LINE_WIDTH, dash_end - y, PONG_COLOR_DIM);
    }
}

static void draw_hud_center_divider(void)
{
    draw_rect(SCREEN_CENTER_LEFT_X, 2U, CENTER_LINE_WIDTH, 10U, PONG_COLOR_DIM);
}

static void draw_score_bar(uint8_t score, uint32_t x0, uint16_t color)
{
    uint8_t i;
    uint32_t x;
    uint8_t limit = g_game_params.max_score;

    if (score > limit) {
        score = limit;
    }

    for (i = 0U; i < score; i++) {
        x = x0 + ((uint32_t)i * (SCORE_BLOCK_WIDTH + SCORE_BLOCK_GAP));
        draw_rect(x, SCORE_Y, SCORE_BLOCK_WIDTH, SCORE_BLOCK_HEIGHT, color);
    }
}

static uint16_t get_winner_color(const game_state_t *state)
{
    if (state->score_p1 >= g_game_params.max_score) {
        return PONG_COLOR_P1;
    }
    if (state->score_p2 >= g_game_params.max_score) {
        return PONG_COLOR_P2;
    }
    return PONG_COLOR_FOREGROUND;
}

static void draw_hud(const game_state_t *state)
{
    draw_score_bar(state->score_p1, score_p1_x(), PONG_COLOR_P1);
    draw_score_bar(state->score_p2, SCORE_P2_X,   PONG_COLOR_P2);
    draw_hud_center_divider();

    if (state->status == GAME_WAITING) {
        draw_centered_rect(WAIT_BAR_Y, WAIT_BAR_WIDTH, WAIT_BAR_HEIGHT, PONG_COLOR_DIM);
    }

    if (state->status == GAME_OVER) {
        draw_centered_rect(WIN_BAR_Y, WIN_BAR_WIDTH, WIN_BAR_HEIGHT, get_winner_color(state));
    }
}

static void draw_dynamic_objects(const game_state_t *state)
{
    draw_sprite(PADDLE_MARGIN,
                state->paddle_p1_y,
                SPRITE_P1_W, SPRITE_P1_H,
                SPRITE_P1_OFFSET);

    draw_sprite(GAME_WIDTH - PADDLE_MARGIN - PADDLE_WIDTH,
                state->paddle_p2_y,
                SPRITE_P2_W, SPRITE_P2_H,
                SPRITE_P2_OFFSET);

    draw_sprite(state->ball_x,
                state->ball_y,
                SPRITE_BALL_W, SPRITE_BALL_H,
                SPRITE_BALL_OFFSET);
}

void pong_render_state(const game_state_t *state)
{
    vram_clear(PONG_COLOR_BACKGROUND);
    draw_border();
    draw_center_line();
    draw_hud(state);
    draw_dynamic_objects(state);
}
