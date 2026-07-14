/* ============================================================================
 * device/boot/startup.S
 *
 * The reset handler. This is the FIRST instruction that runs on the ESP32
 * after the boot ROM finishes load_ram and jumps to our entry point.
 *
 * We arrive here in this state:
 *   - The CPU is running at whatever clock the ROM left it at (~80 MHz).
 *   - Most CPU registers are undefined.
 *   - The PS register's WOE bit may be 0, so call4/call8 don't work yet.
 *   - The RTC watchdog is RUNNING. We have a few seconds before it resets us.
 *     (We disable it from C, in main(), once SP is set up.)
 *
 * Our job: turn that into a runnable C environment, then call main.
 * ========================================================================= */

    .file "startup.S"

    /* -- Section placement --
     * .iram.entry is matched by the linker script BEFORE every other text
     * section, so this code lands at IRAM ORIGIN = 0x40080000.
     * "ax" = allocatable + executable. */
    .section .iram.entry, "ax"

    .global _start
    .type   _start, @function
    .align  4
_start:
    /* ----------------------------------------------------------------
     * 1. Set the stack pointer.
     *    Xtensa convention: a1 = SP. We point it at the top of DRAM.
     *    _stack_top is defined by the linker script as
     *    ORIGIN(dram_seg) + LENGTH(dram_seg) = 0x3FFE0000.
     *    Stack grows DOWN, so the first push will write to 0x3FFDFFFC.
     * ---------------------------------------------------------------- */
    movi    a1, _stack_top

    /* ----------------------------------------------------------------
     * 2. Reset the Xtensa register window state.
     *    WindowBase  = 0   -> AR0..AR15 map to physical AR0..AR15.
     *    WindowStart = 1   -> only window 0 is "live" (no caller frame).
     *    rsync             -> wait for the writes to actually take effect
     *                         before any instruction observes the new state.
     * ---------------------------------------------------------------- */
    movi    a0, 0
    wsr     a0, WINDOWBASE
    movi    a0, 1
    wsr     a0, WINDOWSTART
    rsync

    /* ----------------------------------------------------------------
     * 3. Set the Processor State (PS) register.
     *    Bit layout we care about:
     *      INTLEVEL[3:0] = 0xF  -> mask all maskable interrupts (level 7
     *                              is NMI; that one cannot be masked).
     *      EXCM      [4] = 0    -> not in exception mode.
     *      UM        [5] = 0    -> kernel mode.
     *      WOE      [18] = 1    -> window-overflow option enabled.
     *                              REQUIRED before any call4 / call8.
     *    PS = (1 << 18) | 0xF = 0x4000F.
     * ---------------------------------------------------------------- */
    movi    a0, 0x4000F
    wsr     a0, PS
    rsync

    /* ----------------------------------------------------------------
     * 4. Zero the .bss section.
     *    .bss is NOLOAD in our image, so no one has zeroed it for us, and
     *    C requires uninitialized globals to read as 0. We do it ourselves.
     *
     *    a2 = current pointer
     *    a3 = end pointer  (exclusive)
     *    a4 = the value we are storing (zero)
     *
     *    Loop:
     *      if (a2 >= a3) goto done
     *      *(uint32_t *)a2 = 0
     *      a2 += 4
     *      goto loop
     * ---------------------------------------------------------------- */
    movi    a2, _bss_start
    movi    a3, _bss_end
    movi    a4, 0
.Lbss_loop:
    bgeu    a2, a3, .Lbss_done   /* branch if a2 >= a3 (unsigned) */
    s32i    a4, a2, 0            /* store zero at *a2 */
    addi    a2, a2, 4            /* a2 += 4 */
    j       .Lbss_loop
.Lbss_done:

    /* ----------------------------------------------------------------
     * 5. Hand off to C.
     *    call4 main:
     *      - rotates the register window by 4
     *      - saves the return PC into a0 of the new window
     *      - jumps to main
     *    main is compiled with the windowed ABI, so it begins with an
     *    `entry a1, N` instruction that adjusts SP for its locals and
     *    confirms the window setup.
     * ---------------------------------------------------------------- */
    call4   main

    /* ----------------------------------------------------------------
     * 6. main is supposed to be while(1) {...}. If for some reason it
     *    returns, do nothing forever. Better than executing junk in
     *    whatever happens to be the next memory location.
     * ---------------------------------------------------------------- */
.Lhang:
    j       .Lhang

    .size _start, . - _start
