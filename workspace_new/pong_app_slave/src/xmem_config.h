#ifndef XMEM_CONFIG_H
#define XMEM_CONFIG_H

#include "xparameters.h"

/* Compatibilidad para BSP nuevo generado desde plataforma microSD */

#ifndef XPAR_MIG_0_BASEADDRESS
#define XPAR_MIG_0_BASEADDRESS 0x80000000U
#endif

#ifndef XPAR_MIG_0_HIGHADDRESS
#define XPAR_MIG_0_HIGHADDRESS 0x87FFFFFFU
#endif

#ifndef XPAR_LMB_BRAM_0_BASEADDRESS
#define XPAR_LMB_BRAM_0_BASEADDRESS 0x00000000U
#endif

#ifndef XPAR_LMB_BRAM_0_HIGHADDRESS
#define XPAR_LMB_BRAM_0_HIGHADDRESS 0x0001FFFFU
#endif

#endif /* XMEM_CONFIG_H */
