#!/usr/bin/env bash
set -euo pipefail

# Installer for macpower solution bundle
# - copies scripts to /opt/homebrew/bin (or /usr/local/bin if chosen)
# - copies launch agents to ~/Library/LaunchAgents
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

BIN_DIR="$(choose_bin_dir)"

echo "== macpower installer =="
echo "Bundle: $BUNDLE_DIR"
echo "Install bin dir: $BIN_DIR"
echo ""

mkdir -p "$BIN_DIR"
sudo mkdir -p "$BIN_DIR" >/dev/null 2>&1 || true

# Copy scripts
sudo cp "$BUNDLE_DIR/bin/macpower" "$BIN_DIR/macpower"
sudo cp "$BUNDLE_DIR/bin/macpower-auto" "$BIN_DIR/macpower-auto"
sudo chmod +x "$BIN_DIR/macpower" "$BIN_DIR/macpower-auto"

# Fix plist paths if bin dir isn't /opt/homebrew/bin
mkdir -p "$HOME/Library/LaunchAgents"
NIGHT_PLIST_SRC="$BUNDLE_DIR/launchd/com.user.macpower.night.plist"
MORN_PLIST_SRC="$BUNDLE_DIR/launchd/com.user.macpower.morning.plist"
NIGHT_PLIST_DST="$HOME/Library/LaunchAgents/com.user.macpower.night.plist"
MORN_PLIST_DST="$HOME/Library/LaunchAgents/com.user.macpower.morning.plist"

# Replace hardcoded /opt/homebrew/bin with chosen bin dir
sed "s|/opt/homebrew/bin|$BIN_DIR|g" "$NIGHT_PLIST_SRC" > "$NIGHT_PLIST_DST"
sed "s|/opt/homebrew/bin|$BIN_DIR|g" "$MORN_PLIST_SRC" > "$MORN_PLIST_DST"

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
  tmp="/tmp/macpower_sudoers.tmp"
  sed "s/YOUR_USERNAME/${user}/g" "$BUNDLE_DIR/sudoers/macpower" > "$tmp"
  sudo cp "$tmp" /etc/sudoers.d/macpower
  sudo chmod 440 /etc/sudoers.d/macpower
  rm -f "$tmp"
  # Validate
  if sudo /usr/sbin/visudo -cf /etc/sudoers.d/macpower; then
    echo "✅ sudoers installed and validated."
  else
    echo "❌ sudoers validation failed. Removing file."
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
launchctl unload "$NIGHT_PLIST_DST" 2>/dev/null || true
launchctl unload "$MORN_PLIST_DST" 2>/dev/null || true
launchctl load "$NIGHT_PLIST_DST"
launchctl load "$MORN_PLIST_DST"

echo "✅ Installed & loaded."
echo ""
echo "Try:"
echo "  $BIN_DIR/macpower status"
echo "  $BIN_DIR/macpower-auto status"
echo ""
