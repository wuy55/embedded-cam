/* ============================================================================
 * device/hal/reg_gpio.h
 *
 * GPIO and IO_MUX register addresses for ESP32-D0WD-V3.
 * Reference: ESP32 Technical Reference Manual, chapter "IO_MUX and GPIO Matrix".
 *
 * Two peripheral blocks are involved in driving any pin:
 *   IO_MUX   (base 0x3FF49000): selects the FUNCTION of a pad
 *                               (GPIO, UART, SPI, ...), drive strength,
 *                               pullups, etc.
 *   GPIO     (base 0x3FF44000): for pins routed to the GPIO function,
 *                               controls direction (in/out) and value.
 *
 * GPIO0..GPIO31 are bit N of the *_REG (no suffix).
 * GPIO32..GPIO39 are bit (N - 32) of the *1_REG.
 * The W1TS / W1TC / W1TC1 mirrors are "write-1-to-set" / "write-1-to-clear"
 * variants -- writing them only affects bits set to 1, which lets us toggle
 * one pin without a read-modify-write race.
 * ========================================================================= */

#ifndef HAL_REG_GPIO_H
#define HAL_REG_GPIO_H

#include <stdint.h>

#define REG32(addr)   (*(volatile uint32_t *)(addr))

/* -- GPIO controller -------------------------------------------------------*/
#define GPIO_BASE                 0x3FF44000U

#define GPIO_OUT_REG              REG32(GPIO_BASE + 0x0004)  /* GPIO0..31  out */
#define GPIO_OUT_W1TS_REG         REG32(GPIO_BASE + 0x0008)  /* set bits   */
#define GPIO_OUT_W1TC_REG         REG32(GPIO_BASE + 0x000C)  /* clear bits */
#define GPIO_OUT1_REG             REG32(GPIO_BASE + 0x0010)  /* GPIO32..39 out */
#define GPIO_OUT1_W1TS_REG        REG32(GPIO_BASE + 0x0014)
#define GPIO_OUT1_W1TC_REG        REG32(GPIO_BASE + 0x0018)

#define GPIO_ENABLE_REG           REG32(GPIO_BASE + 0x0020)  /* GPIO0..31  oe */
#define GPIO_ENABLE_W1TS_REG      REG32(GPIO_BASE + 0x0024)
#define GPIO_ENABLE_W1TC_REG      REG32(GPIO_BASE + 0x0028)
#define GPIO_ENABLE1_REG          REG32(GPIO_BASE + 0x002C)  /* GPIO32..39 oe */
#define GPIO_ENABLE1_W1TS_REG     REG32(GPIO_BASE + 0x0030)
#define GPIO_ENABLE1_W1TC_REG     REG32(GPIO_BASE + 0x0034)

/* -- IO_MUX ----------------------------------------------------------------*
 * Per-pad register at IO_MUX_BASE + per-pin offset. The offset table is in
 * TRM Table "IO_MUX Pad List". GPIO33's offset is 0x20.
 *
 * Field layout we care about for Phase 1:
 *   MCU_SEL [14:12] = 2    -> route the pad to the GPIO function.
 *                              (Function 2 == GPIO for every "GPIOxx" pad on
 *                               the ESP32. See FUNC_GPIO33_GPIO33 = 2.)
 *   FUN_IE  [9]     = 0    -> input buffer disabled (we're output-only).
 *   FUN_DRV [11:10] = 2    -> drive strength ~20 mA, fine for an LED.
 */
#define IO_MUX_BASE               0x3FF49000U
#define IO_MUX_GPIO33_REG         REG32(IO_MUX_BASE + 0x20)

#define IO_MUX_MCU_SEL_S          12
#define IO_MUX_MCU_SEL_M          (0x7U << IO_MUX_MCU_SEL_S)
#define IO_MUX_FUNC_GPIO          2

#define IO_MUX_FUN_DRV_S          10
#define IO_MUX_FUN_DRV_M          (0x3U << IO_MUX_FUN_DRV_S)
#define IO_MUX_FUN_DRV_20MA       2

#define IO_MUX_FUN_IE             (1U << 9)

/* -- Bit position of GPIO33 in the *1_REG family --------------------------*/
#define GPIO33_BIT                (1U << (33 - 32))   /* = bit 1 = 0x2 */

#endif /* HAL_REG_GPIO_H */
