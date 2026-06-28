#ifndef DDR2_SECTIONS_H
#define DDR2_SECTIONS_H

#define DDR2_RODATA_SECTION __attribute__((section(".ddr2_rodata"), aligned(4)))
#define DDR2_DATA_SECTION   __attribute__((section(".ddr2_data"), aligned(4)))
#define DDR2_BSS_SECTION    __attribute__((section(".ddr2_bss"), aligned(16)))

#endif
