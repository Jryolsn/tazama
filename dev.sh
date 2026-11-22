#!/usr/bin/env bash
# Run the TV app with hot reload on the device in .devrc (TV_IP), or a running emulator.
set -euo pipefail
source "$(dirname "${BASH_SOURCE[0]}")/tools/dev/env.sh"

echo "Running on $DEVICE_ID (r = hot reload, R = hot restart, q = quit)"
exec fvm flutter run -d "$DEVICE_ID" --flavor github "$@"
