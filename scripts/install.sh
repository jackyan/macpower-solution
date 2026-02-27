#!/usr/bin/env bash
set -euo pipefail

# Installer for macpower solution bundle
# - copies scripts to /opt/homebrew/bin (or /usr/local/bin)
# - copies launch agents to ~/Library/LaunchAgents (with path substitution)
# - creates log directory at ~/Library/Logs/macpower
# - optionally installs sudoers entry for pmset (recommended)

BUNDLE_DIR="$(cd "$(dirname "$0")/.." && pwd)"
DEFAULT_BIN_DIR="/opt/homebrew/bin"
ALT_BIN_DIR="/usr/local/bin"

choose_bin_dir() {
  if [[ -d "$DEFAULT_BIN_DIR" ]]; then
    echo "$DEFAULT_BIN_DIR"
    return
  fi
  echo "$ALT_BIN_DIR"
}

# Helper: try launchctl bootout/bootstrap (modern), fall back to unload/load (legacy)
launchctl_unload() {
  local plist="$1"
  local label
  label="$(/usr/libexec/PlistBuddy -c "Print :Label" "$plist" 2>/dev/null || true)"
  if [[ -n "$label" ]] && launchctl bootout "gui/$(id -u)/$label" 2>/dev/null; then
    return 0
  fi
  launchctl unload "$plist" 2>/dev/null || true
}

launchctl_load() {
  local plist="$1"
  if launchctl bootstrap "gui/$(id -u)" "$plist" 2>/dev/null; then
    return 0
  fi
  launchctl load "$plist" 2>/dev/null || true
}

BIN_DIR="$(choose_bin_dir)"

echo "== macpower installer =="
echo "Bundle: $BUNDLE_DIR"
echo "Install bin dir: $BIN_DIR"
echo ""

# Create bin directory (use sudo only if current user lacks write permission)
if [[ -w "$BIN_DIR" ]] 2>/dev/null; then
  mkdir -p "$BIN_DIR"
else
  sudo mkdir -p "$BIN_DIR"
fi

# Copy scripts (use sudo only if needed)
if [[ -w "$BIN_DIR" ]]; then
  cp "$BUNDLE_DIR/bin/macpower" "$BIN_DIR/macpower"
  cp "$BUNDLE_DIR/bin/macpower-auto" "$BIN_DIR/macpower-auto"
  chmod +x "$BIN_DIR/macpower" "$BIN_DIR/macpower-auto"
else
  sudo cp "$BUNDLE_DIR/bin/macpower" "$BIN_DIR/macpower"
  sudo cp "$BUNDLE_DIR/bin/macpower-auto" "$BIN_DIR/macpower-auto"
  sudo chmod +x "$BIN_DIR/macpower" "$BIN_DIR/macpower-auto"
fi

echo "Installed scripts to: $BIN_DIR"

# Create log directory
LOG_DIR="$HOME/Library/Logs/macpower"
mkdir -p "$LOG_DIR"
echo "Log directory: $LOG_DIR"

# Prepare LaunchAgents
mkdir -p "$HOME/Library/LaunchAgents"
NIGHT_PLIST_SRC="$BUNDLE_DIR/launchd/com.user.macpower.night.plist"
MORN_PLIST_SRC="$BUNDLE_DIR/launchd/com.user.macpower.morning.plist"
NIGHT_PLIST_DST="$HOME/Library/LaunchAgents/com.user.macpower.night.plist"
MORN_PLIST_DST="$HOME/Library/LaunchAgents/com.user.macpower.morning.plist"

# Substitute placeholders: __HOME__ -> actual HOME, /opt/homebrew/bin -> chosen BIN_DIR
sed -e "s|__HOME__|$HOME|g" -e "s|/opt/homebrew/bin|$BIN_DIR|g" "$NIGHT_PLIST_SRC" > "$NIGHT_PLIST_DST"
sed -e "s|__HOME__|$HOME|g" -e "s|/opt/homebrew/bin|$BIN_DIR|g" "$MORN_PLIST_SRC" > "$MORN_PLIST_DST"

echo "Copied LaunchAgents to:"
echo "  $NIGHT_PLIST_DST"
echo "  $MORN_PLIST_DST"
echo ""

echo "Step 1 (recommended): Create a pmset backup once:"
echo "  $BIN_DIR/macpower save"
echo ""

echo "Step 2 (required for automation): Install sudoers entry for passwordless pmset."
echo "We can attempt to install it now."
read -r -p "Install sudoers file at /etc/sudoers.d/macpower ? (y/N) " ans || true
if [[ "${ans:-}" =~ ^[Yy]$ ]]; then
  user="$(whoami)"
  tmp="$(mktemp /tmp/macpower_sudoers.XXXXXX)"
  sed "s/YOUR_USERNAME/${user}/g" "$BUNDLE_DIR/sudoers/macpower" > "$tmp"
  sudo cp "$tmp" /etc/sudoers.d/macpower
  sudo chmod 440 /etc/sudoers.d/macpower
  rm -f "$tmp"
  # Validate
  if sudo /usr/sbin/visudo -cf /etc/sudoers.d/macpower; then
    echo "sudoers installed and validated."
  else
    echo "sudoers validation failed. Removing file."
    sudo rm -f /etc/sudoers.d/macpower
    exit 1
  fi
else
  echo "Skipped sudoers install. Automation will not be able to change pmset without password."
  echo "Install later with:"
  echo "  sudo visudo -f /etc/sudoers.d/macpower"
  echo "and paste the template from: $BUNDLE_DIR/sudoers/macpower"
fi

echo ""
echo "Step 3: Load the scheduled tasks:"
launchctl_unload "$NIGHT_PLIST_DST"
launchctl_unload "$MORN_PLIST_DST"
launchctl_load "$NIGHT_PLIST_DST"
launchctl_load "$MORN_PLIST_DST"

echo "Installed & loaded."
echo ""
echo "Try:"
echo "  $BIN_DIR/macpower status"
echo "  $BIN_DIR/macpower-auto status"
echo ""
