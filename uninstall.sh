#!/usr/bin/env bash
# uninstall.sh — removes the siri-to-things launchd agent and script

set -euo pipefail

PLIST="$HOME/Library/LaunchAgents/com.siri-to-things.agent.plist"
SCRIPT="$HOME/Scripts/reminders_to_things.applescript"

# Unload the agent if it's running
if launchctl list | grep -q "com.siri-to-things.agent"; then
    echo "==> Unloading launchd agent"
    launchctl unload "$PLIST" 2>/dev/null || true
fi

# Remove installed files
if [ -f "$PLIST" ]; then
    echo "==> Removing $PLIST"
    rm "$PLIST"
fi

if [ -f "$SCRIPT" ]; then
    echo "==> Removing $SCRIPT"
    rm "$SCRIPT"
fi

echo ""
echo "✓ Uninstalled successfully."
