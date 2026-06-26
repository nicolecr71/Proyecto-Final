#include "game/game_logic.h"
#include "game/game_config.h"
#include "game/game_params.h"

static void clamp_paddle(uint16_t *paddle_y)
{
    if (*paddle_y > (GAME_HEIGHT - PADDLE_HEIGHT)) {
        *paddle_y = GAME_HEIGHT - PADDLE_HEIGHT;
    }
}

static void update_paddle(uint16_t *paddle_y, player_input_t input)
{
    if (input.up && (*paddle_y >= g_game_params.paddle_speed)) {
        *paddle_y -= (uint16_t)g_game_params.paddle_speed;
    }

    if (input.down) {
        *paddle_y += (uint16_t)g_game_params.paddle_speed;
    }

    clamp_paddle(paddle_y);
}

static void update_time_counters(game_state_t *state)
{
    state->game_ticks++;
    state->round_ticks++;

    state->elapsed_seconds =
        (uint16_t)(state->game_ticks / GAME_TICKS_PER_SECOND);
}

static void game_reset_round_with_direction(game_state_t *state, int16_t serve_direction)
{
    state->ball_x = GAME_WIDTH / 2;
    state->ball_y = GAME_HEIGHT / 2;

    if (serve_direction >= 0) {
        state->ball_vx = (int16_t)g_game_params.ball_speed_x;
        state->serve_direction = 1;
    } else {
        state->ball_vx = -(int16_t)g_game_params.ball_speed_x;
        state->serve_direction = -1;
    }

    state->ball_vy = (int16_t)g_game_params.ball_speed_y;

    state->paddle_p1_y = (GAME_HEIGHT - PADDLE_HEIGHT) / 2;
    state->paddle_p2_y = (GAME_HEIGHT - PADDLE_HEIGHT) / 2;

    state->round_ticks = 0;
    state->flags |= GAME_FLAG_ROUND_RESET;
}

void game_reset_round(game_state_t *state)
{
    game_reset_round_with_direction(state, 1);
}

void game_init(game_state_t *state)
{
    state->score_p1 = 0;
    state->score_p2 = 0;

    state->winner = 0;
    state->flags = GAME_FLAG_NONE;
    state->frame_id = 0;

    state->game_ticks = 0;
    state->round_ticks = 0;
    state->elapsed_seconds = 0;

    state->last_point = 0;
    state->serve_direction = 1;

    state->status = GAME_WAITING;

    game_reset_round(state);

    state->flags = GAME_FLAG_NONE;
}

static uint8_t ball_hits_paddle_1(const game_state_t *state)
{
    uint16_t paddle_x = PADDLE_MARGIN;

    uint8_t x_collision =
        (state->ball_x <= (paddle_x + PADDLE_WIDTH)) &&
        ((state->ball_x + BALL_SIZE) >= paddle_x);

    uint8_t y_collision =
        ((state->ball_y + BALL_SIZE) >= state->paddle_p1_y) &&
        (state->ball_y <= (state->paddle_p1_y + PADDLE_HEIGHT));

    return x_collision && y_collision;
}

static uint8_t ball_hits_paddle_2(const game_state_t *state)
{
    uint16_t paddle_x = GAME_WIDTH - PADDLE_MARGIN - PADDLE_WIDTH;

    uint8_t x_collision =
        ((state->ball_x + BALL_SIZE) >= paddle_x) &&
        (state->ball_x <= (paddle_x + PADDLE_WIDTH));

    uint8_t y_collision =
        ((state->ball_y + BALL_SIZE) >= state->paddle_p2_y) &&
        (state->ball_y <= (state->paddle_p2_y + PADDLE_HEIGHT));

    return x_collision && y_collision;
}

static void update_ball(game_state_t *state)
{
    int32_t next_ball_x = (int32_t)state->ball_x + state->ball_vx;
    int32_t next_ball_y = (int32_t)state->ball_y + state->ball_vy;

    if (next_ball_y <= 0) {
        next_ball_y = 0;
        state->ball_vy = -state->ball_vy;
    }

    if ((next_ball_y + BALL_SIZE) >= GAME_HEIGHT) {
        next_ball_y = GAME_HEIGHT - BALL_SIZE;
        state->ball_vy = -state->ball_vy;
    }

    state->ball_x = (uint16_t)next_ball_x;
    state->ball_y = (uint16_t)next_ball_y;

    if (ball_hits_paddle_1(state)) {
        state->ball_x = PADDLE_MARGIN + PADDLE_WIDTH;
        state->ball_vx = (int16_t)g_game_params.ball_speed_x;
        state->serve_direction = 1;
    }

    if (ball_hits_paddle_2(state)) {
        state->ball_x = GAME_WIDTH - PADDLE_MARGIN - PADDLE_WIDTH - BALL_SIZE;
        state->ball_vx = -(int16_t)g_game_params.ball_speed_x;
        state->serve_direction = -1;
    }

    if (next_ball_x <= 0) {
        state->score_p2++;
        state->last_point = 2;
        state->flags |= GAME_FLAG_P2_SCORED;
        game_reset_round_with_direction(state, 1);
    }

    if ((next_ball_x + BALL_SIZE) >= GAME_WIDTH) {
        state->score_p1++;
        state->last_point = 1;
        state->flags |= GAME_FLAG_P1_SCORED;
        game_reset_round_with_direction(state, -1);
    }

    if (state->score_p1 >= g_game_params.max_score) {
        state->winner = 1;
        state->status = GAME_OVER;
        state->flags |= GAME_FLAG_GAME_OVER;
    }

    if (state->score_p2 >= g_game_params.max_score) {
        state->winner = 2;
        state->status = GAME_OVER;
        state->flags |= GAME_FLAG_GAME_OVER;
    }
}

static void game_update_common(
    game_state_t *state,
    player_input_t p1,
    player_input_t p2
)
{
    state->flags = GAME_FLAG_NONE;

    if (p1.reset || p2.reset) {
        game_init(state);
        return;
    }

    if (state->status == GAME_WAITING) {
        if (p1.start || p2.start) {
            state->status = GAME_RUNNING;
        } else {
            return;
        }
    }

    if (state->status == GAME_OVER) {
        return;
    }

    update_time_counters(state);
    update_paddle(&state->paddle_p1_y, p1);
    update_paddle(&state->paddle_p2_y, p2);
    update_ball(state);

    state->frame_id++;
}

void game_update_local(
    game_state_t *state,
    player_input_t p1,
    player_input_t p2
)
{
    game_update_common(state, p1, p2);
}

void game_update_master(
    game_state_t *state,
    player_input_t p1,
    player_input_t p2_remote
)
{
    game_update_common(state, p1, p2_remote);
}

void game_apply_remote_state(
    game_state_t *state,
    const game_state_t *remote_state
)
{
    *state = *remote_state;
}

uint8_t game_is_over(const game_state_t *state)
{
    return state->status == GAME_OVER;
}
