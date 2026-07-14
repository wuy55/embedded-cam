# embedded-cam

Intended as a camera stack built from scratch on an ESP32-CAM — every byte from the OV2640 photosite to a pixel on the host, with no Arduino, no ESP-IDF, and no vendor camera library.

The goal isn't a fast camera — libraries will hand you a JPEG in ten lines. It's to own the whole path (sensor init, SCCB bus, DMA pixel capture, a hand-rolled ISP, the 3A loops, and an Android-style HAL3/Camera2 surrogate on the host) so I can speak to every layer of a camera stack at the register level.

## Constraints

No Arduino. No ESP-IDF linked (read as reference only). No `esp-camera` — so then the pixel path is mine. No JPEG offload to the sensor's DSP — I will pull raw and write the ISP myself. No DSP libraries — demosaic, color-matrix, convolution, gamma all hand-rolled. HAL3/Camera2 are going to be a faithful host-side surrogate, since the chip can't host Android.

## Hardware & toolchain

- **Board:** ESP32-CAM — ESP32-D0WD-V3 rev v3.1, 4 MB PSRAM
- **Camera:** OV2640
- **Host:** Ubuntu 24.04 (VirtualBox on Windows 11), board on `/dev/ttyUSB0`
- **Toolchain (pinned):** `xtensa-esp-elf-gcc` 15.2.0, `esptool` 5.2.0

## Status

**Phase 0** (toolchain, USB passthrough, chip ID) and **Phase 1** (bare-metal blink) are done. Phase 1 is a complete, hand-written boot-to-`main`: a reset handler (`startup.S`) that brings up the C runtime, a linker script placing code in IRAM and data in DRAM, and a `main.c` that disables the watchdogs and blinks GPIO33 through raw register writes. The image is RAM-loaded; a flash boot via our own second-stage bootloader is next (Phase 2).

## Roadmap

| Phase | Builds | |
|--:|---|:--:|
| 0 | Toolchain, USB passthrough, chip ID | ✅ |
| 1 | Bare-metal blink: startup.S, linker script, GPIO MMIO | ✅ |
| 2 | Our own second-stage bootloader → flash boot | ▢ |
| 3 | UART driver + from-scratch `kprintf` | ▢ |
| 4 | Clocks (240 MHz PLL), hardware timer, `delay_us` | ▢ |
| 5 | SCCB/I²C driver — read OV2640 ID | ▢ |
| 6 | OV2640 init + XCLK; PCLK/HREF/VSYNC alive | ▢ |
| 7 | I²S-as-camera + DMA capture into PSRAM | ▢ |
| 8 | UART framing + host raw viewer | ▢ |
| 9 | Hand-rolled ISP (BLC→DPC→demosaic→AWB→CCM→gamma→denoise→sharpen→tonemap) | ▢ |
| 10 | 3A: statistics, AE, AWB | ▢ |
| 11 | AOSP HAL3 surrogate on the host | ▢ |
| 12 | Camera2-style API + bracketed HDR demo | ▢ |
| 13 | Interview-grade extensions | ▢ |

## Build (Phase 1)

```bash
make              # build firmware.elf + firmware.bin
make inspect      # ELF sections, segments, entry point, _start disasm
make flash-ram    # load into RAM over UART and jump
./scripts/monitor.sh   # serial monitor at 115200
```

Needs the pinned toolchain on `PATH` and `esptool` available. The Makefile's `XTENSA_CONFIG` path is machine-specific — set it to your own toolchain location if you clone this. On success the red LED (GPIO33) blinks at ~1 Hz.

## Layout

```
device/   code on the ESP32 — boot/ (startup.S), ld/ (linker script), hal/ (register maps), main.c
scripts/  flash + serial monitor helpers
```

Later phases add `device/sensor/`, `device/isp/`, `device/threeA/`, the host-side `host/hal3/` and `host/camera2/`, and a `docs/` folder of deep-dives.

## Project history

The commit history starts fresh here — an earlier version lived on a GitHub account I lost access to, so the per-step history didn't carry over. The engineering is intact and documented in the source. Development continues from here.

last updated: 02/06/2026
