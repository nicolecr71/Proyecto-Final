/******************************************************************************
* Copyright (C) 2023 Advanced Micro Devices, Inc. All Rights Reserved.
* SPDX-License-Identifier: MIT
******************************************************************************/

_STACK_SIZE = DEFINED(_STACK_SIZE) ? _STACK_SIZE : 0x800;
_HEAP_SIZE  = DEFINED(_HEAP_SIZE)  ? _HEAP_SIZE  : 0x1000;

MEMORY
{
    /*
     * BRAM local (128KB): boot stub, C runtime (_start), all data sections,
     * heap and stack.  Must work before MIG initialisation.
     */
    lmb_bram_0 : ORIGIN = 0x00000000, LENGTH = 0x20000

    /*
     * DDR2 firmware code (0x80200000+, 94MB):
     * main() and all application .text, safely above game-data area.
     * Fetched via MicroBlaze M_AXI_IP after boot stub jumps to main().
     */
    mig_fw     : ORIGIN = 0x80200000, LENGTH = 0x05E00000

    /*
     * DDR2 game-data (0x80000000, 2MB): custom sections only (g_app etc.).
     * Raw-pointer accesses (DDR2_CONFIG_ADDR, DDR2_SPRITE_BANK_ADDR, …)
     * live here by design, not via linker sections.
     */
    mig_0      : ORIGIN = 0x80000000, LENGTH = 0x00200000
}

ENTRY(_boot)

SECTIONS
{
    /* ----------------------------------------------------------------
     * BRAM — everything that must work before MIG is ready
     * ---------------------------------------------------------------- */

    /*
     * .text.init: BSP boot stub (_boot in boot.o).
     * Also includes crt0.o(.text) so that the JAL from boot.o to
     * _start stays within the ±1 MiB RISC-V JAL range.
     */
    .text.init : {
        __text_init_start = .;
        *(.text.init)
        *crt0.o(.text)
        __text_init_end = .;
    } > lmb_bram_0

    .init : { KEEP (*(.init)) } > lmb_bram_0
    .fini : { KEEP (*(.fini)) } > lmb_bram_0

    .ctors : {
        __CTOR_LIST__ = .; ___CTORS_LIST___ = .;
        KEEP (*crtbegin.o(.ctors))
        KEEP (*(EXCLUDE_FILE(*crtend.o) .ctors))
        KEEP (*(SORT(.ctors.*)))
        KEEP (*(.ctors))
        __CTOR_END__ = .; ___CTORS_END___ = .;
    } > lmb_bram_0

    .dtors : {
        __DTOR_LIST__ = .; ___DTORS_LIST___ = .;
        KEEP (*crtbegin.o(.dtors))
        KEEP (*(EXCLUDE_FILE(*crtend.o) .dtors))
        KEEP (*(SORT(.dtors.*)))
        KEEP (*(.dtors))
        __DTOR_END__ = .; ___DTORS_END___ = .;
    } > lmb_bram_0

    .init_array : {
        __init_array_start = .;
        KEEP (*(SORT(.init_array.*)))
        KEEP (*(.init_array))
        __init_array_end = .;
    } > lmb_bram_0

    .fini_array : {
        __fini_array_start = .;
        KEEP (*(SORT(.fini_array.*)))
        KEEP (*(.fini_array))
        __fini_array_end = .;
    } > lmb_bram_0

    /* All data sections stay in BRAM so BSP BSS-zeroing runs
       before MIG calibration completes. */
    .note.gnu.build-id : { KEEP (*(.note.gnu.build-id)) } > lmb_bram_0

    .rodata : {
        __rodata_start = .;
        *(.rodata) *(.rodata.*) *(.gnu.linkonce.r.*)
        __rodata_end = .;
    } > lmb_bram_0

    .srodata : {
        __srodata_start = .;
        *(.srodata)
        __srodata_end = .;
    } > lmb_bram_0

    .sdata2 : {
        __sdata2_start = .;
        *(.sdata2) *(.sdata2.*) *(.gnu.linkonce.s2.*)
        __sdata2_end = .;
    } > lmb_bram_0

    .data : {
        __data_start = .;
        *(.data) *(.data.*) *(.gnu.linkonce.d.*)
        _edata = .;
    } > lmb_bram_0

    .got  : { *(.got)  } > lmb_bram_0
    .got1 : { *(.got1) } > lmb_bram_0
    .got2 : { *(.got2) } > lmb_bram_0
    .jcr  : { *(.jcr)  } > lmb_bram_0

    .gcc_except_table : { *(.gcc_except_table) } > lmb_bram_0

    .sdata : {
        __sdata_start = .;
        *(.sdata) *(.sdata.*) *(.gnu.linkonce.s.*)
        __sdata_end = .;
    } > lmb_bram_0

    .tdata : {
        __tdata_start = .;
        *(.tdata) *(.tdata.*) *(.gnu.linkonce.td.*)
        __tdata_end = .;
    } > lmb_bram_0

    .tbss : {
        __tbss_start = .;
        *(.tbss) *(.tbss.*) *(.gnu.linkonce.tb.*)
        __tbss_end = .;
    } > lmb_bram_0

    .bss (NOLOAD) : {
        __bss_start = .;
        *(.bss) *(.bss.*) *(.gnu.linkonce.b.*) *(COMMON)
        __bss_end = .;
    } > lmb_bram_0

    .sbss (NOLOAD) : {
        __sbss_start = .;
        *(.sbss) *(.sbss.*) *(.gnu.linkonce.sb.*)
        __sbss_end = .;
    } > lmb_bram_0

    .sbss2 : {
        __sbss2_start = .;
        *(.sbss2) *(.sbss2.*) *(.gnu.linkonce.sb2.*)
        __sbss2_end = .;
    } > lmb_bram_0

    _SDA_BASE_  = __sdata_start + ((__sbss_end  - __sdata_start)  / 2);
    _SDA2_BASE_ = __sdata2_start + ((__sbss2_end - __sdata2_start) / 2);
    __global_pointer$ = MIN(__sdata_start + 0x800,
                        MAX(__data_start  + 0x800, __bss_end - 0x800));

    .heap (NOLOAD) : {
        . = ALIGN(8);
        _heap = .; _heap_start = .;
        . += _HEAP_SIZE;
        _heap_end = .;
    } > lmb_bram_0

    .stack (NOLOAD) : {
        _stack_end = .;
        . += _STACK_SIZE;
        . = ALIGN(8);
        _stack = .; __stack = _stack;
    } > lmb_bram_0

    _end = .;

    /* ----------------------------------------------------------------
     * BRAM — application code (.text)
     * The code is small enough (~25 KB) to fit in the 128 KB BRAM.
     * Running from BRAM avoids the DDR2 fetch latency and keeps the
     * slave at the same execution speed as the master.
     * ---------------------------------------------------------------- */
    .text : {
        . = ALIGN(4);
        *(EXCLUDE_FILE(*crt0.o) .text)
        *(EXCLUDE_FILE(*crt0.o) .text.*)
        *(.gnu.linkonce.t.*)
    } > lmb_bram_0

    /* ----------------------------------------------------------------
     * DDR2 mig_0 — custom game-data sections (g_app, etc.)
     * ---------------------------------------------------------------- */
    .ddr2_rodata : {
        . = ALIGN(4);
        *(.ddr2_rodata) *(.ddr2_rodata.*)
        . = ALIGN(4);
    } > mig_0

    .ddr2_data : {
        . = ALIGN(4);
        *(.ddr2_data) *(.ddr2_data.*)
        . = ALIGN(4);
    } > mig_0

    .ddr2_bss (NOLOAD) : {
        . = ALIGN(4);
        *(.ddr2_bss) *(.ddr2_bss.*)
        . = ALIGN(4);
    } > mig_0
}
