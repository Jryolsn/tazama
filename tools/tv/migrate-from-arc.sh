#!/usr/bin/env bash
# One-time move from the old Arc fork (com.jryolsn.arc) to Tazama (com.jryolsn.tazama).
# The new application id makes Tazama a separate app: settings, PIN and categories start fresh.
#
#   TV_HOST=192.168.1.163 tools/tv/migrate-from-arc.sh          # stable release
#   TV_HOST=192.168.1.163 tools/tv/migrate-from-arc.sh --pre    # newest pre-release (test TV)
set -euo pipefail
source "$(dirname "$0")/lib.sh"
OLD="com.jryolsn.arc"
OLD_HOME="$OLD/com.omeda.arc.MainActivity"
OLD_A11Y="$OLD/com.omeda.arc.ArcAccessibilityService"
ensure_connected

was_home=false
[[ "$(home_activity)" == "$OLD_HOME" ]] && was_home=true

echo "== Install Tazama, allow its overlay, enable its accessibility service"
TV_HOST="${TV_HOST:-}" TV_SERIAL="${TV_SERIAL:-}" "$TOOLS/setup-tv.sh" 4 "$@"

# Home must point at Tazama before Arc goes, or the TV is left without a home screen.
if [[ "$was_home" == true ]]; then
    tv am start -n "$ARC_HOME" >/dev/null
    tv cmd package set-home-activity --user 0 "$ARC_HOME"
fi
echo "  Home: $(home_activity)"

current=$(tv settings get secure enabled_accessibility_services)
cleaned=$(tr ':' '\n' <<<"$current" | grep -vx "$OLD_A11Y" | paste -sd: - || true)
[[ "$cleaned" != "$current" ]] && tv settings put secure enabled_accessibility_services "${cleaned:-null}"

if has_package "$OLD"; then
    if confirm "Uninstall the old Arc ($OLD) now?"; then
        adb -s "$TV" uninstall "$OLD"
    fi
fi
echo
echo "Done. In Obtainium: remove Arc and add https://github.com/$ARC_REPO (test TV: include pre-releases)."
echo "Set up PIN, app lock and categories again in Tazama's settings."
