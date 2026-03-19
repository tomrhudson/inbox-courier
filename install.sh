#!/usr/bin/env bash
# install.sh — sets up siri-to-things with no manual path editing required

set -euo pipefail

# Resolve the directory this script lives in, so it works when called from any path
REPO_DIR="$(cd "$(dirname "$0")" && pwd)"

SCRIPT_NAME="reminders_to_things.applescript"
PLIST_NAME="com.siri-to-things.agent.plist"
SCRIPTS_DIR="$HOME/Scripts"
LAUNCH_AGENTS_DIR="$HOME/Library/LaunchAgents"
SCRIPT_DEST="$SCRIPTS_DIR/$SCRIPT_NAME"
PLIST_DEST="$LAUNCH_AGENTS_DIR/$PLIST_NAME"

echo "==> Creating $SCRIPTS_DIR"
mkdir -p "$SCRIPTS_DIR"

echo "==> Copying script to $SCRIPT_DEST"
cp "$REPO_DIR/$SCRIPT_NAME" "$SCRIPT_DEST"

echo "==> Writing plist with resolved path to $PLIST_DEST"
mkdir -p "$LAUNCH_AGENTS_DIR"
sed "s|SCRIPT_PATH_PLACEHOLDER|$SCRIPT_DEST|g" "$REPO_DIR/$PLIST_NAME" > "$PLIST_DEST"

# Unload first in case a previous version is already loaded
if launchctl list | grep -q "com.siri-to-things.agent"; then
    echo "==> Unloading existing agent"
    launchctl unload "$PLIST_DEST" 2>/dev/null || true
fi

echo "==> Loading launchd agent"
launchctl load "$PLIST_DEST"

echo ""
echo "✓ Installed successfully."
echo ""
echo "Next step: run the script once manually to grant macOS permissions:"
echo "  osascript $SCRIPT_DEST"
echo ""
echo "Then verify the agent is loaded:"
echo "  launchctl list | grep siri-to-things"
