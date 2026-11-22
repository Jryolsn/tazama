#!/usr/bin/env bash
# Save a screenshot of the dev device. Usage: tools/dev/screenshot.sh [output.png]
set -euo pipefail
source "$(dirname "${BASH_SOURCE[0]}")/env.sh"

OUT="${1:-.screenshots/tv.png}"
mkdir -p "$(dirname "$OUT")"
adb -s "$DEVICE_ID" exec-out screencap -p > "$OUT"
echo "$OUT"
