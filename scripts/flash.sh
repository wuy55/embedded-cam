#!/usr/bin/env bash
# Usage: ./scripts/flash.sh firmware.bin
# Flashes a raw binary to ESP32 flash at 0x10000
set -e
PORT=${ESP_PORT:-/dev/ttyUSB0}
BAUD=${ESP_BAUD:-460800}
BIN=${1:?Usage: flash.sh <firmware.bin>}

echo "Flashing $BIN to $PORT at $BAUD baud..."
esptool.py --chip esp32 -p "$PORT" -b "$BAUD" \
    write_flash \
    --flash_mode dio \
    --flash_freq 40m \
    --flash_size 4MB \
    0x10000 "$BIN"
