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
MARK_FILE="${HOME}/.macpower.night.enabled"

echo "== macpower uninstall =="
echo "Bin dir: $BIN_DIR"
echo ""

# [H-6] Restore power settings before uninstalling if night policy is active
if [[ -x "$BIN_DIR/macpower" ]]; then
  # Check if night policy is currently active by looking at pmset values
  local_out="$(/usr/bin/pmset -g 2>/dev/null | sed -n '/Currently in use:/,$p')" || true
  if echo "$local_out" | grep -qE "^\s*sleep\s+0(\s|$)" 2>/dev/null && \
     echo "$local_out" | grep -qE "^\s*standby\s+0(\s|$)" 2>/dev/null; then
    echo "Night policy appears to be active. Restoring power settings before uninstall..."
    "$BIN_DIR/macpower" restore 2>/dev/null || "$BIN_DIR/macpower" off 2>/dev/null || true
    echo ""
  fi
fi

# Clean up mark file
rm -f "$MARK_FILE" 2>/dev/null || true

# [C-4] Use modern launchctl bootout instead of deprecated unload
DOMAIN="gui/$(id -u)"
launchctl bootout "${DOMAIN}" "$NIGHT_PLIST" 2>/dev/null || true
launchctl bootout "${DOMAIN}" "$MORN_PLIST" 2>/dev/null || true
rm -f "$NIGHT_PLIST" "$MORN_PLIST"

sudo rm -f "$BIN_DIR/macpower" "$BIN_DIR/macpower-auto" 2>/dev/null || true

echo "Optional: remove sudoers entry:"
echo "  sudo rm -f /etc/sudoers.d/macpower"
echo ""
echo "Optional: remove log directory:"
echo "  rm -rf ~/Library/Logs/macpower"
echo ""
echo "✅ Uninstalled."
