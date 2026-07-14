/* ============================================================================
 * device/hal/reg_rtc.h
 *
 * Just the RTC_CNTL watchdog registers we need to disable.
 * Reference: ESP32 TRM, "Watchdog Timers" chapter.
 *
 * The RTC watchdog is independent of the two TIMG watchdogs. It's running
 * the moment the boot ROM hands control to us, and if we ignore it we get
 * a chip reset within ~7 seconds. The reset reason after that is
 * RTCWDT_RTC_RESET (0x10), which is a famous foot-gun on this chip.
 *
 * To disable it:
 *   1. Unlock by writing the magic key 0x50D83AA1 to WDTWPROTECT.
 *   2. Clear WDTCONFIG0 (every enable bit is in there).
 *   3. (Optional) re-lock by writing anything else to WDTWPROTECT.
 * ========================================================================= */

#ifndef HAL_REG_RTC_H
#define HAL_REG_RTC_H

#include <stdint.h>
#include "reg_gpio.h"   /* re-uses REG32 macro */

#define RTC_CNTL_BASE                 0x3FF48000U

#define RTC_CNTL_WDTCONFIG0_REG       REG32(RTC_CNTL_BASE + 0x008C)
#define RTC_CNTL_WDTWPROTECT_REG      REG32(RTC_CNTL_BASE + 0x00A4)

/* The "I really mean it" key. Without writing this first, all writes to
 * WDTCONFIG0..WDTCONFIG4 are ignored by the hardware. Documented in TRM. */
#define RTC_CNTL_WDT_WKEY             0x50D83AA1U

#endif /* HAL_REG_RTC_H */
