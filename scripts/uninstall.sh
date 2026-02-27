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

# Unload LaunchAgents (try modern API first, fall back to legacy)
for plist in "$NIGHT_PLIST" "$MORN_PLIST"; do
  if [[ -f "$plist" ]]; then
    label="$(/usr/libexec/PlistBuddy -c "Print :Label" "$plist" 2>/dev/null || true)"
    if [[ -n "$label" ]]; then
      launchctl bootout "gui/$(id -u)/$label" 2>/dev/null || launchctl unload "$plist" 2>/dev/null || true
    else
      launchctl unload "$plist" 2>/dev/null || true
    fi
  fi
done
rm -f "$NIGHT_PLIST" "$MORN_PLIST"

# Remove scripts (use sudo only if needed)
if [[ -w "$BIN_DIR" ]]; then
  rm -f "$BIN_DIR/macpower" "$BIN_DIR/macpower-auto"
else
  sudo rm -f "$BIN_DIR/macpower" "$BIN_DIR/macpower-auto" 2>/dev/null || true
fi

# Clean up mark file (always safe to remove)
MARK_FILE="${HOME}/.macpower.night.enabled"
if [[ -f "$MARK_FILE" ]]; then
  rm -f "$MARK_FILE"
  echo "Removed night mark file: $MARK_FILE"
fi

# Clean up backup file (ask user)
BACKUP_FILE="${HOME}/.macpower.pmset.bak"
if [[ -f "$BACKUP_FILE" ]]; then
  read -r -p "Remove pmset backup file ($BACKUP_FILE)? (y/N) " ans || true
  if [[ "${ans:-}" =~ ^[Yy]$ ]]; then
    rm -f "$BACKUP_FILE"
    echo "Removed: $BACKUP_FILE"
  else
    echo "Kept: $BACKUP_FILE"
  fi
fi

# Clean up log directory (ask user)
LOG_DIR="$HOME/Library/Logs/macpower"
if [[ -d "$LOG_DIR" ]]; then
  read -r -p "Remove log directory ($LOG_DIR)? (y/N) " ans || true
  if [[ "${ans:-}" =~ ^[Yy]$ ]]; then
    rm -rf "$LOG_DIR"
    echo "Removed: $LOG_DIR"
  else
    echo "Kept: $LOG_DIR"
  fi
fi

# Also clean up old /tmp log files if they exist (from pre-v1.0.0 installations)
for f in /tmp/macpower_night.log /tmp/macpower_night.err /tmp/macpower_morning.log /tmp/macpower_morning.err; do
  if [[ -f "$f" ]]; then
    rm -f "$f"
    echo "Removed legacy log: $f"
  fi
done

echo ""
echo "Optional: remove sudoers entry:"
echo "  sudo rm -f /etc/sudoers.d/macpower"
echo ""
echo "Uninstalled."
