#!/usr/bin/env bash
# uninstall.sh — removes the inbox-courier launchd agent and script

set -euo pipefail

PLIST="$HOME/Library/LaunchAgents/com.tomrhudson.inboxcourier.agent.plist"
LEGACY_PLIST="$HOME/Library/LaunchAgents/com.siri-to-things.agent.plist"
SCRIPT="$HOME/Scripts/reminders_to_things.applescript"
RUNNER="$HOME/Scripts/inbox_courier_run.sh"
LEGACY_RUNNER="$HOME/Scripts/siri_to_things_run.sh"

# Unload the agent if it's running
if launchctl list | grep -q "com.tomrhudson.inboxcourier.agent"; then
    echo "==> Unloading launchd agent"
    launchctl unload "$PLIST" 2>/dev/null || true
fi

if launchctl list | grep -q "com.siri-to-things.agent"; then
    echo "==> Unloading legacy launchd agent"
    launchctl unload "$LEGACY_PLIST" 2>/dev/null || true
fi

# Remove installed files
if [ -f "$PLIST" ]; then
    echo "==> Removing $PLIST"
    rm "$PLIST"
fi

if [ -f "$LEGACY_PLIST" ]; then
    echo "==> Removing $LEGACY_PLIST"
    rm "$LEGACY_PLIST"
fi

if [ -f "$SCRIPT" ]; then
    echo "==> Removing $SCRIPT"
    rm "$SCRIPT"
fi

if [ -f "$RUNNER" ]; then
    echo "==> Removing $RUNNER"
    rm "$RUNNER"
fi

if [ -f "$LEGACY_RUNNER" ]; then
    echo "==> Removing $LEGACY_RUNNER"
    rm "$LEGACY_RUNNER"
fi

echo ""
echo "✓ Uninstalled successfully."
