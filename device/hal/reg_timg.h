/* ============================================================================
 * device/hal/reg_timg.h
 *
 * Timer-group watchdog registers (TIMG0 and TIMG1).
 * Reference: ESP32 TRM, "Timer Group Watchdog Timers".
 *
 * After load_ram these are typically NOT enabled by the ROM, but we disable
 * them anyway so any future change in ROM behavior or any leftover state
 * from a previous session can't reset us. Disable cost is ~6 register writes.
 *
 * Same protection scheme as the RTC WDT: write key first, then write 0
 * to TIMG_WDTCONFIG0 to disable.
 * ========================================================================= */

#ifndef HAL_REG_TIMG_H
#define HAL_REG_TIMG_H

#include <stdint.h>
#include "reg_gpio.h"   /* REG32 macro */

#define TIMG0_BASE                    0x3FF5F000U
#define TIMG1_BASE                    0x3FF60000U

#define TIMG0_WDTCONFIG0_REG          REG32(TIMG0_BASE + 0x0048)
#define TIMG0_WDTWPROTECT_REG         REG32(TIMG0_BASE + 0x0064)

#define TIMG1_WDTCONFIG0_REG          REG32(TIMG1_BASE + 0x0048)
#define TIMG1_WDTWPROTECT_REG         REG32(TIMG1_BASE + 0x0064)

#define TIMG_WDT_WKEY                 0x50D83AA1U

#endif /* HAL_REG_TIMG_H */
