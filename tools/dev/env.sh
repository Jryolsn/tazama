#!/usr/bin/env bash
# Sourced by dev.sh and tools/dev/*.sh. Resolves the target device into $DEVICE_ID.

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
cd "$REPO_ROOT" || exit 1

[[ -f .devrc ]] && source .devrc

if [[ -z "${JAVA_HOME:-}" && -d /opt/homebrew/opt/openjdk@17 ]]; then
  export JAVA_HOME="/opt/homebrew/opt/openjdk@17/libexec/openjdk.jdk/Contents/Home"
fi
[[ -n "${JAVA_HOME:-}" ]] && export PATH="$JAVA_HOME/bin:$PATH"
export PATH="$PATH:$HOME/Library/Android/sdk/platform-tools:$HOME/Library/Android/sdk/emulator"

if [[ -n "${TV_IP:-}" ]]; then
  DEVICE_ID="$TV_IP"
  if ! adb devices | grep -q "^$DEVICE_ID[[:space:]]*device"; then
    echo "Connecting to $DEVICE_ID"
    adb connect "$DEVICE_ID" >/dev/null
    if ! adb devices | grep -q "^$DEVICE_ID[[:space:]]*device"; then
      echo "Could not reach $DEVICE_ID. Is the TV on, with network debugging enabled?" >&2
      exit 1
    fi
  fi
else
  DEVICE_ID="emulator-5554"
  if ! adb devices | grep -q "^$DEVICE_ID[[:space:]]*device"; then
    echo "TV_IP is not set in .devrc and no emulator is running." >&2
    echo "Set TV_IP, or start the emulator: emulator -avd android_tv_arm64" >&2
    exit 1
  fi
fi
export DEVICE_ID
