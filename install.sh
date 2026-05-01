#!/usr/bin/env bash
# install.sh — sets up inbox-courier with no manual path editing required

set -euo pipefail

# Resolve the directory this script lives in, so it works when called from any path
REPO_DIR="$(cd "$(dirname "$0")" && pwd)"

SCRIPT_NAME="reminders_to_things.applescript"
RUNNER_NAME="inbox_courier_run.sh"
PLIST_NAME="com.tomrhudson.inboxcourier.agent.plist"
LEGACY_RUNNER_NAME="siri_to_things_run.sh"
LEGACY_PLIST_NAME="com.siri-to-things.agent.plist"
SCRIPTS_DIR="$HOME/Scripts"
LAUNCH_AGENTS_DIR="$HOME/Library/LaunchAgents"
LOG_DIR="$HOME/Library/Logs/InboxCourier"
SCRIPT_DEST="$SCRIPTS_DIR/$SCRIPT_NAME"
RUNNER_DEST="$SCRIPTS_DIR/$RUNNER_NAME"
PLIST_DEST="$LAUNCH_AGENTS_DIR/$PLIST_NAME"
LEGACY_RUNNER_DEST="$SCRIPTS_DIR/$LEGACY_RUNNER_NAME"
LEGACY_PLIST_DEST="$LAUNCH_AGENTS_DIR/$LEGACY_PLIST_NAME"
STDOUT_DEST="$LOG_DIR/launchd.out.log"
STDERR_DEST="$LOG_DIR/launchd.err.log"

echo "==> Creating $SCRIPTS_DIR"
mkdir -p "$SCRIPTS_DIR"

echo "==> Copying script to $SCRIPT_DEST"
cp "$REPO_DIR/$SCRIPT_NAME" "$SCRIPT_DEST"

echo "==> Copying worker to $RUNNER_DEST"
cp "$REPO_DIR/$RUNNER_NAME" "$RUNNER_DEST"
chmod +x "$RUNNER_DEST"

echo "==> Writing plist with resolved path to $PLIST_DEST"
mkdir -p "$LAUNCH_AGENTS_DIR"
mkdir -p "$LOG_DIR"
sed \
    -e "s|RUNNER_PATH_PLACEHOLDER|$RUNNER_DEST|g" \
    -e "s|SCRIPT_PATH_PLACEHOLDER|$SCRIPT_DEST|g" \
    -e "s|STDOUT_PATH_PLACEHOLDER|$STDOUT_DEST|g" \
    -e "s|STDERR_PATH_PLACEHOLDER|$STDERR_DEST|g" \
    "$REPO_DIR/$PLIST_NAME" > "$PLIST_DEST"

# Unload first in case a previous version is already loaded
if launchctl list | grep -q "com.tomrhudson.inboxcourier.agent"; then
    echo "==> Unloading existing agent"
    launchctl unload "$PLIST_DEST" 2>/dev/null || true
fi

if launchctl list | grep -q "com.siri-to-things.agent"; then
    echo "==> Unloading legacy siri-to-things agent"
    launchctl unload "$LEGACY_PLIST_DEST" 2>/dev/null || true
fi

if [ -f "$LEGACY_PLIST_DEST" ]; then
    echo "==> Removing legacy $LEGACY_PLIST_DEST"
    rm "$LEGACY_PLIST_DEST"
fi

if [ -f "$LEGACY_RUNNER_DEST" ]; then
    echo "==> Removing legacy $LEGACY_RUNNER_DEST"
    rm "$LEGACY_RUNNER_DEST"
fi

echo "==> Loading launchd agent"
launchctl load "$PLIST_DEST"

echo ""
echo "✓ Installed successfully."
echo ""
echo "Next step: run the script once manually to grant macOS permissions:"
echo "  osascript $SCRIPT_DEST"
echo ""
echo "If the first launchd run failed before permissions were granted, trigger a fresh run with:"
echo "  launchctl kickstart -k gui/$(id -u)/com.tomrhudson.inboxcourier.agent"
echo ""
echo "The worker writes status to:"
echo "  $HOME/Library/Application Support/InboxCourier/status.json"
echo ""
echo "Logs are kept in:"
echo "  $LOG_DIR"
echo ""
echo "Then verify the agent is loaded:"
echo "  launchctl list | grep inbox-courier"
