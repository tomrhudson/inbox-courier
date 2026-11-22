# Inbox Courier

> [!IMPORTANT]
> **Archived — November 22, 2026.** This project is no longer maintained and the repository is read-only.
>
> Things 3 now does this natively. In **Things → Settings → Reminders**, check **Show to-dos from `INBOX` in Inbox**. Reminders from that list (including ones added with Siri) appear in your Things Inbox, where you can import them; imported to-dos are deleted from Reminders.
>
> Things' built-in import has a few differences from Inbox Courier:
> - Reminders with attachments, sub-tasks, or location-based alerts are hidden from the Things Inbox and can't be imported.
> - Imported reminders are **deleted** from Reminders (Inbox Courier marked them complete instead).
> - Items aren't tagged `siri` automatically.

## Migrating off Inbox Courier

1. Turn on the built-in integration in **Things → Settings → Reminders** (pick the list Siri uses, usually `INBOX`).
2. Remove the background agent and scripts:

   ```bash
   ./uninstall.sh
   ```

3. If you installed the menu bar app, turn off **Launch at Login** in its menu, quit it, and delete `Inbox Courier.app` from `/Applications`.
4. Optionally delete leftover status and logs:

   ```bash
   rm -rf ~/Library/Application\ Support/InboxCourier ~/Library/Logs/InboxCourier
   ```

The rest of this README is kept for reference and describes the project as it was last released (May 2026).

---

Automatically migrates items from the **Reminders Inbox** (where Siri drops them) to the **Things 3 Inbox** on macOS — preserving due dates and times — then marks each Reminder as complete.

---

## The Problem

Siri can add reminders hands-free. Things 3 requires you to interact with the app. When you're driving, this means everything goes into Reminders and stays there.

This script bridges the gap: a lightweight AppleScript + launchd agent that runs in the background and continuously drains your Reminders Inbox into Things 3 — no interaction required. A small optional SwiftUI menu bar companion can show sync health, pending queue state, and last-run details.

---

## How It Works

1. Polls your Reminders **Inbox** on a configurable interval (default: every 15 minutes)
2. For each incomplete reminder, creates a corresponding to-do in the **Things 3 Inbox**
3. Copies the title, notes, and due date/time (if set)
4. Tags the new to-do with `siri` so you can filter or search for migrated items
5. Marks the original Reminder as **complete** so it is never processed twice

---

## Requirements

- macOS (core automation tested on macOS Sequoia)
- [Things 3](https://culturedcode.com/things/) — Mac app must be installed
- Reminders app (built-in)
- Optional menu bar companion: macOS 13 or later and Xcode Command Line Tools / Swift 5.9 or later when running from source

---

## Files

| File | Description |
|------|-------------|
| `reminders_to_things.applescript` | Core migration logic |
| `inbox_courier_run.sh` | Worker wrapper that records structured status and per-run logs |
| `com.tomrhudson.inboxcourier.agent.plist` | launchd agent for scheduled execution |
| `Package.swift`, `Sources/InboxCourier/` | Optional SwiftUI menu bar status app |
| `scripts/package_app.sh` | Builds and signs a distributable `.app` zip |
| `.github/workflows/` | CI and tag-based GitHub release workflows |
| `install.sh` | One-shot install script — auto-detects home directory, no editing required |
| `uninstall.sh` | Removes the launchd agent, installed script, and worker wrapper |

---

## Installation

### 1 — Clone the repo

```bash
git clone https://github.com/tomrhudson/inbox-courier.git
cd inbox-courier
```

### 2 — Run the install script

```bash
chmod +x install.sh
./install.sh
```

This will:
- Auto-detect your home directory — no username editing required
- Copy the script to `~/Scripts/`
- Copy the worker wrapper to `~/Scripts/`
- Write the plist with the correct path and install it to `~/Library/LaunchAgents/`
- Load the launchd agent
- Create durable status/log directories under `~/Library/`

### 3 — Grant Automation permissions

Run the script once manually to trigger the macOS permission dialogs:

```bash
osascript ~/Scripts/reminders_to_things.applescript
```

When prompted, grant access to **Reminders** and **Things3**.

> ⚠️ This step must be done interactively before launchd can run the script unattended — launchd cannot respond to permission dialogs. Because the installer loads the agent immediately, the first scheduled run may fail until permissions are granted. After granting permissions, either wait for the next scheduled run or trigger one manually:
>
> ```bash
> launchctl kickstart -k gui/$(id -u)/com.tomrhudson.inboxcourier.agent
> ```
>
> You can verify or revoke permissions later at **System Settings → Privacy & Security → Automation**.

### 4 — Verify

```bash
launchctl list | grep inbox-courier
```

A line with exit code `0` and a PID of `-` means the agent is loaded and idle. It runs once immediately on load, then on schedule.

### Optional — run the menu bar companion

The companion is a lightweight SwiftUI `MenuBarExtra` app that reads the worker's status file and controls the launchd job. It is not installed by `install.sh`; for development, run it from the repo:

```bash
swift run InboxCourier
```

It shows:

- Pending items still queued after the last run
- Last run time and migrated count
- Agent health: healthy, running, stale, failed, or unknown
- Launch at Login status and toggle
- Install/Repair Agent for first-run setup or damaged launchd files
- Quick actions for Run Now, Reload Agent, Reminders, Things, logs, and status

The companion is intentionally menu-bar-only and does not show a Dock icon.

### Install the released app

For normal use, download the latest `InboxCourier-<version>.zip` from GitHub Releases, unzip it, and move `Inbox Courier.app` to `/Applications`.

Open the app once, then use **Install/Repair Agent** from the menu bar item to install the worker script and LaunchAgent. Then enable **Launch at Login** if you want the menu bar companion to start automatically. macOS may show it in **System Settings → General → Login Items & Extensions**.

> Local artifacts are ad-hoc signed by default so the launch-at-login API has a signed app bundle to register. GitHub Releases are designed to use Developer ID signing and Apple notarization once the required repository secrets are configured.

### Build a local app bundle

```bash
VERSION=0.1.0 BUILD_NUMBER=1 scripts/package_app.sh
```

This creates:

```bash
dist/Inbox Courier.app
dist/InboxCourier-0.1.0.zip
dist/InboxCourier-0.1.0.zip.sha256
```

To sign with a Developer ID identity instead of ad-hoc signing:

```bash
SIGN_IDENTITY="Developer ID Application: Your Name (TEAMID)" VERSION=0.1.0 scripts/package_app.sh
```

### Release a version

CI runs on pull requests and pushes to `main`. Versioned releases are created from tags:

```bash
git tag v0.1.0
git push origin v0.1.0
```

The release workflow builds a universal macOS app, signs it with your Developer ID Application certificate, submits it to Apple's notary service, staples the notarization ticket, packages it as a zip, writes a SHA-256 checksum, and attaches both files to the GitHub Release. You can also run the release workflow manually from GitHub Actions and provide a version.

### Configure notarized GitHub releases

You need an active Apple Developer Program account with permission to create Developer ID certificates and App Store Connect API keys.

1. Create a **Developer ID Application** certificate in your Apple Developer account or Xcode.
2. Export the certificate and private key from Keychain Access as a password-protected `.p12`.
3. Create an App Store Connect API **Team Key**. Individual API keys do not work with `notarytool`.
4. Add these GitHub repository secrets:

| Secret | Description |
|--------|-------------|
| `APPLE_CERTIFICATE_BASE64` | Base64-encoded `.p12` export |
| `APPLE_CERTIFICATE_PASSWORD` | Password used when exporting the `.p12` |
| `APPLE_NOTARY_KEY_BASE64` | Base64-encoded App Store Connect API `.p8` key |
| `APPLE_NOTARY_KEY_ID` | App Store Connect API key ID |
| `APPLE_NOTARY_ISSUER_ID` | App Store Connect API issuer ID |
| `DEVELOPER_ID_APPLICATION` | Full signing identity, for example `Developer ID Application: Thomas Hudson (JZPZ8PQR46)` |

To base64-encode the local files before adding them as GitHub secrets:

```bash
base64 -i DeveloperIDApplication.p12 | pbcopy
base64 -i AuthKey_ABC123DEFG.p8 | pbcopy
```

Your downloaded `developerID_application.cer` is the public certificate. GitHub Actions also needs the matching private key, so install the certificate locally, confirm it appears in Keychain Access with a disclosure arrow/private key under it, then export the certificate and private key together as a `.p12`.

### Create the App Store Connect Team Key

1. Open [App Store Connect](https://appstoreconnect.apple.com/).
2. Go to **Users and Access → Integrations → App Store Connect API**.
3. Select **Team Keys**, not Individual Keys.
4. Click **Generate API Key**.
5. Name it something like `Inbox Courier Notarization`.
6. Choose an access role. **Developer** is typically enough for notarization; use a higher role only if your team policy requires it.
7. Copy the **Key ID** into `APPLE_NOTARY_KEY_ID`.
8. Copy the **Issuer ID** into `APPLE_NOTARY_ISSUER_ID`.
9. Download the `.p8` key once, then store its base64 value in `APPLE_NOTARY_KEY_BASE64`.

---

## Configuration

### Change the polling interval

Edit the `StartInterval` value in the installed plist at `~/Library/LaunchAgents/com.tomrhudson.inboxcourier.agent.plist` (in seconds):

| Interval | Value |
|----------|-------|
| 5 min    | `300` |
| 15 min   | `900` |
| 30 min   | `1800` |

After any plist change, reload the agent:

```bash
launchctl bootout gui/$(id -u) ~/Library/LaunchAgents/com.tomrhudson.inboxcourier.agent.plist
launchctl bootstrap gui/$(id -u) ~/Library/LaunchAgents/com.tomrhudson.inboxcourier.agent.plist
```

> **Note:** `launchctl load/unload` still works but is deprecated on macOS Ventura and later:
> ```bash
> launchctl unload ~/Library/LaunchAgents/com.tomrhudson.inboxcourier.agent.plist
> launchctl load   ~/Library/LaunchAgents/com.tomrhudson.inboxcourier.agent.plist
> ```

### Change the source Reminders list

The script targets the list named `"INBOX"` in your default account — the all-caps name Siri uses by default. If your list is named differently, edit this line in `~/Scripts/reminders_to_things.applescript`:

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

If you edit the repo copy instead, run `./install.sh` again so the installed copy in `~/Scripts/` is refreshed.

---

## Debugging

The worker writes structured status here:

```bash
cat ~/Library/Application\ Support/InboxCourier/status.json
```

Per-run logs and launchd stdout/stderr are written here:

```bash
ls ~/Library/Logs/InboxCourier/
```

Per-run logs older than 14 days are pruned automatically each time the worker runs. To change that retention period, set `INBOX_COURIER_LOG_RETENTION_DAYS` in the launchd environment or worker environment before running the wrapper.

To run the worker immediately and refresh the status file:

```bash
launchctl kickstart -k gui/$(id -u)/com.tomrhudson.inboxcourier.agent
```

---

## Uninstall

```bash
chmod +x uninstall.sh
./uninstall.sh
```

Status and log files under `~/Library/Application Support/InboxCourier/` and `~/Library/Logs/InboxCourier/` are left in place for troubleshooting.

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
