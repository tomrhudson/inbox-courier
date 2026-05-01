#!/usr/bin/env bash
# inbox_courier_run.sh — launchd worker wrapper with durable status and logs

set -u

LABEL="com.tomrhudson.inboxcourier.agent"
SCRIPT_PATH="${1:-$HOME/Scripts/reminders_to_things.applescript}"
APP_SUPPORT_DIR="$HOME/Library/Application Support/InboxCourier"
LOG_DIR="$HOME/Library/Logs/InboxCourier"
STATUS_FILE="$APP_SUPPORT_DIR/status.json"
RETENTION_DAYS="${INBOX_COURIER_LOG_RETENTION_DAYS:-${SIRI_TO_THINGS_LOG_RETENTION_DAYS:-14}}"

iso_now() {
    /bin/date -u +"%Y-%m-%dT%H:%M:%SZ"
}

stamp_now() {
    /bin/date -u +"%Y%m%dT%H%M%SZ"
}

json_escape() {
    local value="${1:-}"
    value="${value//\\/\\\\}"
    value="${value//\"/\\\"}"
    value="${value//$'\n'/\\n}"
    value="${value//$'\r'/\\r}"
    value="${value//$'\t'/\\t}"
    printf "%s" "$value"
}

write_status() {
    local state="$1"
    local started_at="$2"
    local finished_at="$3"
    local exit_code="$4"
    local pending_before="$5"
    local pending_after="$6"
    local migrated_count="$7"
    local last_error="$8"
    local log_file="$9"

    local finished_json="null"
    local exit_json="null"
    local error_json="null"

    if [ -n "$finished_at" ]; then
        finished_json="\"$(json_escape "$finished_at")\""
    fi

    if [ -n "$exit_code" ]; then
        exit_json="$exit_code"
    fi

    if [ -n "$last_error" ]; then
        error_json="\"$(json_escape "$last_error")\""
    fi

    /bin/mkdir -p "$APP_SUPPORT_DIR"
    /bin/cat > "$STATUS_FILE" <<JSON
{
  "label": "$(json_escape "$LABEL")",
  "state": "$(json_escape "$state")",
  "lastStartedAt": "$(json_escape "$started_at")",
  "lastFinishedAt": $finished_json,
  "lastExitCode": $exit_json,
  "pendingBeforeRun": $pending_before,
  "pendingAfterRun": $pending_after,
  "migratedCount": $migrated_count,
  "lastError": $error_json,
  "logFile": "$(json_escape "$log_file")",
  "scriptPath": "$(json_escape "$SCRIPT_PATH")"
}
JSON
}

prune_old_logs() {
    if [[ "$RETENTION_DAYS" =~ ^[0-9]+$ ]]; then
        /usr/bin/find "$LOG_DIR" -type f -name "run-*.log" -mtime +"$RETENTION_DAYS" -delete 2>/dev/null || true
    fi
}

parse_metrics() {
    local output="$1"
    pendingBeforeRun=0
    pendingAfterRun=0
    migratedCount=0

    while IFS="=" read -r key value; do
        case "$key" in
            pendingBeforeRun)
                if [[ "$value" =~ ^[0-9]+$ ]]; then
                    pendingBeforeRun="$value"
                fi
                ;;
            pendingAfterRun)
                if [[ "$value" =~ ^[0-9]+$ ]]; then
                    pendingAfterRun="$value"
                fi
                ;;
            migratedCount)
                if [[ "$value" =~ ^[0-9]+$ ]]; then
                    migratedCount="$value"
                fi
                ;;
        esac
    done <<< "$output"
}

/bin/mkdir -p "$APP_SUPPORT_DIR" "$LOG_DIR"
prune_old_logs

startedAt="$(iso_now)"
runStamp="$(stamp_now)"
runLog="$LOG_DIR/run-$runStamp.log"

write_status "running" "$startedAt" "" "" 0 0 0 "" "$runLog"

if [ ! -f "$SCRIPT_PATH" ]; then
    finishedAt="$(iso_now)"
    errorMessage="AppleScript not found at $SCRIPT_PATH"
    printf "%s\n" "$errorMessage" > "$runLog"
    write_status "failed" "$startedAt" "$finishedAt" 127 0 0 0 "$errorMessage" "$runLog"
    exit 127
fi

/usr/bin/osascript "$SCRIPT_PATH" > "$runLog" 2>&1
exitCode=$?
finishedAt="$(iso_now)"
runOutput="$(/bin/cat "$runLog")"
parse_metrics "$runOutput"

if [ "$exitCode" -eq 0 ]; then
    write_status "succeeded" "$startedAt" "$finishedAt" "$exitCode" "$pendingBeforeRun" "$pendingAfterRun" "$migratedCount" "" "$runLog"
else
    errorMessage="$(printf "%s" "$runOutput" | /usr/bin/tail -n 1)"
    if [ -z "$errorMessage" ]; then
        errorMessage="osascript exited with code $exitCode"
    fi
    write_status "failed" "$startedAt" "$finishedAt" "$exitCode" "$pendingBeforeRun" "$pendingAfterRun" "$migratedCount" "$errorMessage" "$runLog"
fi

exit "$exitCode"
