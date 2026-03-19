# siri-to-things

Automatically migrates items from the **Reminders Inbox** (where Siri drops them) to the **Things 3 Inbox** on macOS — preserving due dates and times — then marks each Reminder as complete.

---

## The Problem

Siri can add reminders hands-free. Things 3 requires you to interact with the app. When you're driving, this means everything goes into Reminders and stays there.

This script bridges the gap: a lightweight AppleScript + launchd agent that runs in the background and continuously drains your Reminders Inbox into Things 3 — no interaction required.

---

## How It Works

1. Polls your Reminders **Inbox** on a configurable interval (default: every 15 minutes)
2. For each incomplete reminder, creates a corresponding to-do in the **Things 3 Inbox**
3. Copies the title, notes, and due date/time (if set)
4. Tags the new to-do with `siri` so you can filter or search for migrated items
5. Marks the original Reminder as **complete** so it is never processed twice

---

## Requirements

- macOS (tested on macOS Sequoia)
- [Things 3](https://culturedcode.com/things/) — Mac app must be installed
- Reminders app (built-in)

---

## Files

| File | Description |
|------|-------------|
| `reminders_to_things.applescript` | Core migration logic |
| `com.siri-to-things.agent.plist` | launchd agent for scheduled execution |
| `install.sh` | One-shot install script — auto-detects home directory, no editing required |
| `uninstall.sh` | Removes the launchd agent and installed script |

---

## Installation

### 1 — Clone the repo

```bash
git clone https://github.com/tomrhudson/siri-to-things.git
cd siri-to-things
```

### 2 — Run the install script

```bash
chmod +x install.sh
./install.sh
```

This will:
- Auto-detect your home directory — no username editing required
- Copy the script to `~/Scripts/`
- Write the plist with the correct path and install it to `~/Library/LaunchAgents/`
- Load the launchd agent

### 3 — Grant Automation permissions

Run the script once manually to trigger the macOS permission dialogs:

```bash
osascript ~/Scripts/reminders_to_things.applescript
```

When prompted, grant access to **Reminders** and **Things3**.

> ⚠️ This step must be done interactively before launchd can run the script unattended — launchd cannot respond to permission dialogs. You can verify or revoke permissions later at **System Settings → Privacy & Security → Automation**.

### 4 — Verify

```bash
launchctl list | grep siri-to-things
```

A line with exit code `0` and a PID of `-` means the agent is loaded and idle. It runs once immediately on load, then on schedule.

---

## Configuration

### Change the polling interval

Edit the `StartInterval` value in the plist (in seconds):

| Interval | Value |
|----------|-------|
| 5 min    | `300` |
| 15 min   | `900` |
| 30 min   | `1800` |

After any plist change, reload the agent:

```bash
launchctl unload ~/Library/LaunchAgents/com.siri-to-things.agent.plist
launchctl load   ~/Library/LaunchAgents/com.siri-to-things.agent.plist
```

> **Note:** `launchctl load/unload` still works but is deprecated on macOS Ventura and later. The modern equivalents are:
> ```bash
> launchctl bootout gui/$(id -u) ~/Library/LaunchAgents/com.siri-to-things.agent.plist
> launchctl bootstrap gui/$(id -u) ~/Library/LaunchAgents/com.siri-to-things.agent.plist
> ```

### Change the source Reminders list

The script targets the list named `"INBOX"` in your default account — the all-caps name Siri uses by default. If your list is named differently, edit this line in the script:

```applescript
set inboxList to list "INBOX" of default account
```

To verify your exact list and account names before deploying, run this in **Script Editor**:

```applescript
tell application "Reminders"
    get name of every account
    get name of every list of default account
end tell
```

If you have multiple accounts (e.g., iCloud + a local account), be explicit instead of relying on `default account`:

```applescript
set inboxList to list "INBOX" of account "iCloud"
```

---

## Debugging

Logs are written to `/tmp/` (cleared on reboot):

```bash
cat /tmp/reminders_to_things.log
cat /tmp/reminders_to_things_error.log
```

---

## Uninstall

```bash
chmod +x uninstall.sh
./uninstall.sh
```

---

## Notes

- Reminders are marked **complete**, not deleted — your Reminders history remains intact.
- Each migrated to-do is tagged `siri` in Things 3. The tag is created automatically if it doesn't exist.
- Things 3 does not need to be the frontmost app or even open at the time the script runs; the AppleScript dictionary activates it as needed.
- The agent runs immediately on login (via `RunAtLoad`) and then every 15 minutes.
- This is macOS only. There is no iOS equivalent; the Things 3 URL scheme on iOS does not support scripted batch operations in the same way.

---

## License

MIT
