#ifndef GAME_PARAMS_H
#define GAME_PARAMS_H

#include <stdint.h>

/*
 * Parametros de juego leidos desde config.bin en la microSD al arrancar.
 * Si no hay SD o el archivo es invalido se usan los valores por defecto
 * definidos en game_config.h.
 */
typedef struct {
    uint8_t max_score;
    uint8_t ball_speed_x;
    uint8_t ball_speed_y;
    uint8_t paddle_speed;
} game_params_t;

extern game_params_t g_game_params;

/*
 * Lee los parametros desde DDR2_CONFIG_ADDR y los carga en g_game_params.
 * Llamar despues de sd_loader_load_resources().
 */
void game_params_load_from_ddr2(void);

#endif
