/* ============================================================================
 * device/ld/esp32.ld
 *
 * Linker script for Phase 1: bare-metal blink, RAM-loaded via esptool.
 *
 * Memory map of an ESP32-D0WD-V3 (the relevant pieces only):
 *   IRAM (instruction-bus SRAM) : 0x40080000 .. 0x400A0000  (128 KB)
 *   DRAM (data-bus     SRAM)    : 0x3FFB0000 .. 0x3FFE0000  (192 KB)
 *
 * IMPORTANT XTENSA-SPECIFIC ORDERING:
 *   Xtensa's `l32r` PC-relative load can only reach BACKWARDS (negative
 *   offset only, range up to 256 KB). The assembler emits 32-bit constants
 *   into ".<section>.literal" sections. Those literal sections MUST be
 *   placed at a LOWER address than the .text/.iram code that references
 *   them, otherwise the linker emits:
 *       "dangerous relocation: l32r: literal placed after use".
 *
 *   The standard idiom is `*(.foo.literal .foo.literal.* .foo .foo.*)` --
 *   listing literal patterns FIRST inside the wildcard so they are emitted
 *   first into the output section.
 * ========================================================================= */
ENTRY(_start)

MEMORY
{
    iram_seg (RWX) : ORIGIN = 0x40080000, LENGTH = 0x00020000  /* 128 KB IRAM */
    dram_seg (RW)  : ORIGIN = 0x3FFB0000, LENGTH = 0x00030000  /* 192 KB DRAM */
}

SECTIONS
{
    /* -- All code in IRAM ------------------------------------------------ */
    .iram.text : ALIGN(4)
    {
        _iram_start = ABSOLUTE(.);

        /* (1) Reset handler FIRST so it lands at IRAM origin = 0x40080000.
         *     Literals come before the code, per the comment above.        */
        KEEP(*(.iram.entry.literal .iram.entry.literal.*))
        KEEP(*(.iram.entry .iram.entry.*))

        /* (2) Other IRAM code (none yet, but reserve the slot).            */
        *(.iram.text.literal .iram.text.literal.*)
        *(.iram.text .iram.text.*)

        /* (3) All ordinary C code: literals first, then text.              */
        *(.literal .literal.*)
        *(.text .text.*)

        . = ALIGN(4);
        _iram_end = ABSOLUTE(.);
    } > iram_seg

    /* -- Read-only constants in DRAM ------------------------------------- */
    .rodata : ALIGN(4)
    {
        *(.rodata .rodata.*)
        . = ALIGN(4);
    } > dram_seg

    /* -- Initialized writable data in DRAM ------------------------------- */
    .data : ALIGN(4)
    {
        _data_start = ABSOLUTE(.);
        *(.data .data.*)
        . = ALIGN(4);
        _data_end = ABSOLUTE(.);
    } > dram_seg

    /* -- Zero-initialized data: NOLOAD so it isn't in the image ---------- */
    .bss (NOLOAD) : ALIGN(4)
    {
        _bss_start = ABSOLUTE(.);
        *(.bss .bss.*)
        *(COMMON)
        . = ALIGN(4);
        _bss_end = ABSOLUTE(.);
    } > dram_seg

    /* -- Stack top: published symbol consumed by startup.S --------------- */
    _stack_top = ORIGIN(dram_seg) + LENGTH(dram_seg);

    /DISCARD/ :
    {
        *(.comment .comment.*)
        *(.eh_frame .eh_frame_hdr)
        *(.xt.lit .xt.prop .xt.insn)
    }
}
