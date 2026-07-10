#!/bin/bash
# Flash CFS Handheld firmware (auto-detect ESP32 / ESP32-S3)
set -euo pipefail
ROOT="$(cd "$(dirname "$0")" && pwd)"

# Prefer native arm64 esptool venv (Intel brew esptool often fails termios on Apple Silicon)
VENV="${ESPTOOL_VENV:-/tmp/esptool-arm64}"
if [ -x "$VENV/bin/python" ]; then
  ESPTOOL_CMD=(arch -arm64 "$VENV/bin/python" -m esptool)
elif command -v esptool >/dev/null 2>&1; then
  ESPTOOL_CMD=(esptool)
else
  echo "esptool not found. Create venv: arch -arm64 /usr/bin/python3 -m venv /tmp/esptool-arm64 && arch -arm64 /tmp/esptool-arm64/bin/pip install esptool"
  exit 1
fi

BOOT_APP0="${HOME}/Library/Arduino15/packages/esp32/hardware/esp32/3.3.8/tools/partitions/boot_app0.bin"

# Prefer first available serial port
PORT=""
for p in /dev/cu.SLAB_USBtoUART /dev/cu.usbserial-0001 /dev/cu.usbserial-0002; do
  if [ -e "$p" ]; then PORT="$p"; break; fi
done
if [ -z "$PORT" ]; then
  # shellcheck disable=SC2045
  for p in $(ls /dev/cu.* 2>/dev/null || true); do
    case "$p" in
      *Bluetooth*|*debug-console*) continue ;;
      *) PORT="$p"; break ;;
    esac
  done
fi
if [ -z "$PORT" ] || [ ! -e "$PORT" ]; then
  echo "No USB serial port found. Plug in the handheld and try again."
  ls /dev/cu.* 2>/dev/null || true
  exit 1
fi
echo "Using port: $PORT"

CHIP_OUT="$("${ESPTOOL_CMD[@]}" --port "$PORT" --baud 115200 chip_id 2>&1 || true)"
echo "$CHIP_OUT"

if echo "$CHIP_OUT" | grep -qi "ESP32-S3"; then
  CHIP=esp32s3
  BUILD="$ROOT/build"
  BOOT_OFF=0x0
  FREQ=80m
elif echo "$CHIP_OUT" | grep -qi "ESP32"; then
  CHIP=esp32
  BUILD="$ROOT/build-esp32"
  BOOT_OFF=0x1000
  FREQ=40m
else
  echo "Could not detect chip. Hold BOOT, tap RESET, release BOOT, then retry."
  exit 1
fi

echo "Flashing $CHIP from $BUILD ..."
"${ESPTOOL_CMD[@]}" --chip "$CHIP" --port "$PORT" --baud 115200 \
  --before default_reset --after hard_reset --connect-attempts 15 \
  write_flash -z \
  --flash_mode dio --flash_freq "$FREQ" --flash_size 4MB \
  "$BOOT_OFF" "$BUILD/CFS_Handheld_v1.2_OTA.ino.bootloader.bin" \
  0x8000 "$BUILD/CFS_Handheld_v1.2_OTA.ino.partitions.bin" \
  0xe000 "$BOOT_APP0" \
  0x10000 "$BUILD/CFS_Handheld_v1.2_OTA.ino.bin"

echo "Done. Device should reboot to firmware 1.3.6."
