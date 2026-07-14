# =============================================================================
# Phase 1 Makefile -- bare-metal blink, RAM-loaded.
#
# Usage:
#   make              -> build/firmware.elf and build/firmware.bin
#   make inspect      -> show ELF section/segment layout
#   make flash-ram    -> load build/firmware.bin into RAM and jump to it
#   make clean        -> remove build/
#
# Required on the host:
#   - xtensa-esp-elf-gcc 15.2.0 in PATH  (or set XTENSA_PREFIX below)
#   - esptool 5.2.0 in PATH (run `source ~/esptoolenv/bin/activate` first)
# =============================================================================

XTENSA_PREFIX ?= xtensa-esp-elf-
CC      := $(XTENSA_PREFIX)gcc
LD      := $(XTENSA_PREFIX)gcc           # we link with gcc, NOT ld, so the
                                         # driver picks the right multilib
OBJCOPY := $(XTENSA_PREFIX)objcopy
OBJDUMP := $(XTENSA_PREFIX)objdump
READELF := $(XTENSA_PREFIX)readelf
SIZE    := $(XTENSA_PREFIX)size

ESPTOOL ?= esptool
PORT    ?= /dev/ttyUSB0
BAUD    ?= 115200
CHIP    ?= esp32

# -- Source files ---------------------------------------------------------
DEVICE_DIR := device
BUILD_DIR  := build

C_SOURCES   := $(DEVICE_DIR)/main.c
ASM_SOURCES := $(DEVICE_DIR)/boot/startup.S

OBJECTS := $(C_SOURCES:%.c=$(BUILD_DIR)/%.o) \
           $(ASM_SOURCES:%.S=$(BUILD_DIR)/%.o)

LDSCRIPT := $(DEVICE_DIR)/ld/esp32.ld

# -- Compiler flags --------------------------------------------------------
# -mlongcalls          : allow l32r-based long calls (Xtensa-specific).
# -ffreestanding       : we're not hosted; no libc assumptions.
# -fno-builtin         : don't replace memcpy/etc. with builtins.
# -fno-common          : don't use the legacy "common" linkage for tentative
#                        defs; gives proper section placement of globals.
# -fdata-sections      : one section per global, so the linker can drop
#   -ffunction-sections   unused ones. Pairs with --gc-sections at link time.
# -nostdlib / -nostartfiles : we provide our own _start and don't link libc.
# -O2 with -Wall -Wextra : standard cleanliness.
# -mdynconfig           : specify to use the settings for ESP32 for gcc
XTENSA_CONFIG := /home/spencer/toolchains/xtensa-esp-elf/lib/xtensa_esp32.so

COMMON_FLAGS := -mdynconfig=$(XTENSA_CONFIG) -mlongcalls -ffreestanding -fno-builtin -fno-common \
                -ffunction-sections -fdata-sections \
                -Wall -Wextra -O2 -g3

CFLAGS  := $(COMMON_FLAGS) -std=c99 -I$(DEVICE_DIR)
ASFLAGS := $(COMMON_FLAGS)

# -- Linker flags ----------------------------------------------------------
# -T <script>           : use our linker script.
# -nostdlib             : do not pull in crt*.o, libc.a, libgcc.a's startup.
# -Wl,--gc-sections     : drop unused sections (paired with -ffunction/data-sections)
# -Wl,-Map=...          : emit a map file for inspection.
# -Wl,--no-warn-rwx-segments : ESP32 IRAM is RWX by design; mute the linker's
#                             RWX-permission warning.
# -mdynconfig           : specify to use the settings for ESP32 for gcc
LDFLAGS := -mdynconfig=$(XTENSA_CONFIG) \
		   -T $(LDSCRIPT) -nostdlib -nostartfiles \
           -Wl,--gc-sections \
           -Wl,-Map=$(BUILD_DIR)/firmware.map \
           -Wl,--no-warn-rwx-segments

# -- Default target --------------------------------------------------------
all: $(BUILD_DIR)/firmware.bin

# -- Pattern rules ---------------------------------------------------------
$(BUILD_DIR)/%.o: %.c
	@mkdir -p $(@D)
	$(CC) $(CFLAGS) -c $< -o $@

$(BUILD_DIR)/%.o: %.S
	@mkdir -p $(@D)
	$(CC) $(ASFLAGS) -c $< -o $@

# -- Link to ELF -----------------------------------------------------------
$(BUILD_DIR)/firmware.elf: $(OBJECTS) $(LDSCRIPT)
	$(LD) $(OBJECTS) $(LDFLAGS) -o $@
	$(SIZE) $@

# -- Convert ELF to ESP32 image bin ---------------------------------------
# elf2image bakes the ELF segments into the ESP32 image format that the
# boot ROM understands. For load_ram, the resulting .bin is just streamed
# into RAM segment-by-segment by esptool over UART.
$(BUILD_DIR)/firmware.bin: $(BUILD_DIR)/firmware.elf
	$(ESPTOOL) --chip $(CHIP) elf2image --output $@ $<

# -- Convenience targets ---------------------------------------------------
.PHONY: all clean inspect flash-ram

inspect: $(BUILD_DIR)/firmware.elf
	@echo "=== Section headers ==="
	$(READELF) -S $<
	@echo
	@echo "=== Program headers (segments that get loaded) ==="
	$(READELF) -l $<
	@echo
	@echo "=== Entry point ==="
	$(READELF) -h $< | grep -i 'entry'
	@echo
	@echo "=== _start disassembly ==="
	$(OBJDUMP) -d --section=.iram.text $< | head -40

flash-ram: $(BUILD_DIR)/firmware.bin
	@echo ">>> Loading into RAM and jumping. Hold BOOT/IO0 if the chip"
	@echo ">>> isn't already in download mode (it should be after Phase 0)."
	$(ESPTOOL) --chip $(CHIP) -p $(PORT) -b $(BAUD) load-ram $<

clean:
	rm -rf $(BUILD_DIR)
