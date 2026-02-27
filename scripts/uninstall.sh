#!/usr/bin/env bash
set -euo pipefail

DEFAULT_BIN_DIR="/opt/homebrew/bin"
ALT_BIN_DIR="/usr/local/bin"

BIN_DIR="$DEFAULT_BIN_DIR"
if [[ ! -x "$BIN_DIR/macpower" && -x "$ALT_BIN_DIR/macpower" ]]; then
  BIN_DIR="$ALT_BIN_DIR"
fi

NIGHT_PLIST="$HOME/Library/LaunchAgents/com.user.macpower.night.plist"
MORN_PLIST="$HOME/Library/LaunchAgents/com.user.macpower.morning.plist"

echo "== macpower uninstall =="
echo "Bin dir: $BIN_DIR"
echo ""

launchctl unload "$NIGHT_PLIST" 2>/dev/null || true
launchctl unload "$MORN_PLIST" 2>/dev/null || true
rm -f "$NIGHT_PLIST" "$MORN_PLIST"

sudo rm -f "$BIN_DIR/macpower" "$BIN_DIR/macpower-auto" 2>/dev/null || true

echo "Optional: remove sudoers entry:"
echo "  sudo rm -f /etc/sudoers.d/macpower"
echo ""
echo "✅ Uninstalled."
