/**
 * @file game_params.c
 * @brief Carga parametros de juego desde la configuracion almacenada en DDR2.
 */

#include "game/game_params.h"
#include "game/game_config.h"
#include "game/ddr2_memory.h"

game_params_t g_game_params = {
    MAX_SCORE,
    BALL_SPEED_X,
    BALL_SPEED_Y,
    PADDLE_SPEED
};

void game_params_load_from_ddr2(void)
{
    const ddr2_game_config_t *cfg =
        (const ddr2_game_config_t *)DDR2_CONFIG_ADDR;

    if (cfg->magic   != DDR2_CONFIG_MAGIC   ||
        cfg->version != DDR2_CONFIG_VERSION) {
        return;
    }

    if (cfg->max_score >= 1U && cfg->max_score <= 20U) {
        g_game_params.max_score = (uint8_t)cfg->max_score;
    }
    if (cfg->ball_speed_x >= 1U && cfg->ball_speed_x <= 10U) {
        g_game_params.ball_speed_x = (uint8_t)cfg->ball_speed_x;
    }
    if (cfg->ball_speed_y >= 1U && cfg->ball_speed_y <= 10U) {
        g_game_params.ball_speed_y = (uint8_t)cfg->ball_speed_y;
    }
    if (cfg->paddle_speed >= 1U && cfg->paddle_speed <= 10U) {
        g_game_params.paddle_speed = (uint8_t)cfg->paddle_speed;
    }
}
