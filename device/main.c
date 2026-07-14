/* ============================================================================
 * device/main.c
 *
 * Phase 1: blink the on-board red LED on GPIO33.
 *
 * The AI-Thinker ESP32-CAM wires the red status LED to GPIO33 *active-low*:
 *   GPIO33 = 0  -> LED ON
 *   GPIO33 = 1  -> LED OFF
 *
 * No standard library, no startup files from GCC. The startup.S we wrote
 * is the only thing that runs before main, and it just sets up SP +
 * windowed-call state + zeroes .bss.
 * ========================================================================= */

#include <stdint.h>

#include "hal/reg_gpio.h"
#include "hal/reg_rtc.h"
#include "hal/reg_timg.h"

/* ------------------------------------------------------------------------
 * Disable all three watchdogs.
 *
 * The RTC WDT is the dangerous one. The ROM enables it before download mode.
 * If we never disable it, the chip will reset itself ~7 seconds after our
 * code starts running, and the LED will appear to "blink and then go dark."
 * That is the canonical "missed the watchdog" symptom in ESP32 bring-up.
 * ----------------------------------------------------------------------- */
static void disable_watchdogs(void)
{
    /* RTC WDT: unlock, clear config0, leave unlocked (we never want it) */
    RTC_CNTL_WDTWPROTECT_REG = RTC_CNTL_WDT_WKEY;
    RTC_CNTL_WDTCONFIG0_REG  = 0;

    /* TIMG0 WDT */
    TIMG0_WDTWPROTECT_REG    = TIMG_WDT_WKEY;
    TIMG0_WDTCONFIG0_REG     = 0;

    /* TIMG1 WDT */
    TIMG1_WDTWPROTECT_REG    = TIMG_WDT_WKEY;
    TIMG1_WDTCONFIG0_REG     = 0;
}

/* ------------------------------------------------------------------------
 * Configure GPIO33 as a digital output.
 *
 * Two writes are required, in any order:
 *   1. IO_MUX:  set MCU_SEL = 2 ("GPIO function") for the GPIO33 pad.
 *               Without this, the pad is connected to whatever ROM left it
 *               on (often a strapping default), and GPIO_OUT writes have
 *               no effect on the physical pin.
 *   2. GPIO:    set bit (33-32)=1 in GPIO_ENABLE1 to enable the output
 *               driver.  Without this, the pad is floating-input and the
 *               LED never illuminates.
 *
 * We also clear FUN_IE (input enable). For an LED we don't need to read
 * the pin back, and disabling the input buffer slightly reduces leakage.
 * ----------------------------------------------------------------------- */
static void gpio33_init_output(void)
{
    /* Read-modify-write: set MCU_SEL=2, drive=20mA, clear FUN_IE */
    uint32_t mux = IO_MUX_GPIO33_REG;
    mux &= ~(IO_MUX_MCU_SEL_M | IO_MUX_FUN_DRV_M | IO_MUX_FUN_IE);
    mux |=  (IO_MUX_FUNC_GPIO    << IO_MUX_MCU_SEL_S);
    mux |=  (IO_MUX_FUN_DRV_20MA << IO_MUX_FUN_DRV_S);
    IO_MUX_GPIO33_REG = mux;

    /* Enable output driver. W1TS = "write 1 to set", so this is race-free
     * even though other bits in GPIO_ENABLE1 might be controlled by another
     * piece of code. (No such code exists yet, but the habit is the lesson.) */
    GPIO_ENABLE1_W1TS_REG = GPIO33_BIT;
}

static inline void gpio33_set_high(void) { GPIO_OUT1_W1TS_REG = GPIO33_BIT; }
static inline void gpio33_set_low (void) { GPIO_OUT1_W1TC_REG = GPIO33_BIT; }

/* ------------------------------------------------------------------------
 * A spin-loop delay.
 *
 * Phase 1 has no clocks/timer driver yet (Phase 4 builds that). We're at
 * approximately 80 MHz CPU clock left over from ROM. A tight loop that
 * the compiler is *not allowed to optimize away* is the simplest possible
 * delay. We use a volatile counter to defeat optimization.
 *
 * 4_000_000 iterations -> roughly half a second of LED ON or OFF time.
 * The exact value isn't important. Phase 4 replaces this with delay_us().
 * ----------------------------------------------------------------------- */
static void kdelay_loop(uint32_t iters)
{
    volatile uint32_t i;
    for (i = 0; i < iters; i++) { /* nothing */ }
}

/* ------------------------------------------------------------------------
 * main: never returns.
 * ----------------------------------------------------------------------- */
int main(void)
{
    disable_watchdogs();
    gpio33_init_output();

    for (;;) {
        gpio33_set_low();          /* LED ON  (active-low) */
        kdelay_loop(4000000);
        gpio33_set_high();         /* LED OFF */
        kdelay_loop(4000000);
    }

    /* unreachable; startup.S has a hang loop after call4 main as a backstop */
    return 0;
}
