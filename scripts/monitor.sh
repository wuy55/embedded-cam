#!/usr/bin/env bash
# Usage: ./scripts/monitor.sh
# Opens a serial monitor on /dev/ttyUSB0 at 115200 baud
PORT=${ESP_PORT:-/dev/ttyUSB0}
BAUD=${ESP_BAUD:-115200}
echo "Monitoring $PORT at $BAUD baud. Press Ctrl+A then Ctrl+X to exit."
picocom -b "$BAUD" "$PORT"
