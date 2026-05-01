#!/usr/bin/env bash
# Submits the packaged app for Apple notarization, staples the ticket, and refreshes the release zip.

set -euo pipefail

REPO_DIR="$(cd "$(dirname "$0")/.." && pwd)"
APP_NAME="InboxCourier"
VERSION="${VERSION:?VERSION is required}"
DIST_DIR="$REPO_DIR/dist"
APP_DIR="$DIST_DIR/$APP_NAME.app"
ARCHIVE_PATH="$DIST_DIR/$APP_NAME-$VERSION.zip"
KEY_PATH="${APPLE_NOTARY_KEY_PATH:?APPLE_NOTARY_KEY_PATH is required}"
KEY_ID="${APPLE_NOTARY_KEY_ID:?APPLE_NOTARY_KEY_ID is required}"
ISSUER_ID="${APPLE_NOTARY_ISSUER_ID:?APPLE_NOTARY_ISSUER_ID is required}"

if [ ! -d "$APP_DIR" ]; then
    echo "error: expected app bundle at $APP_DIR" >&2
    exit 1
fi

if [ ! -f "$ARCHIVE_PATH" ]; then
    echo "error: expected archive at $ARCHIVE_PATH" >&2
    exit 1
fi

echo "==> Submitting $ARCHIVE_PATH for notarization"
xcrun notarytool submit "$ARCHIVE_PATH" \
    --key "$KEY_PATH" \
    --key-id "$KEY_ID" \
    --issuer "$ISSUER_ID" \
    --wait

echo "==> Stapling notarization ticket"
xcrun stapler staple "$APP_DIR"
xcrun stapler validate "$APP_DIR"
spctl --assess --type execute --verbose=4 "$APP_DIR"

echo "==> Rebuilding release zip with stapled app"
rm -f "$ARCHIVE_PATH" "$ARCHIVE_PATH.sha256"
xattr -cr "$APP_DIR"
ditto -c -k --keepParent "$APP_DIR" "$ARCHIVE_PATH"
shasum -a 256 "$ARCHIVE_PATH" > "$ARCHIVE_PATH.sha256"

echo "Notarized:"
echo "  $APP_DIR"
echo "  $ARCHIVE_PATH"
echo "  $ARCHIVE_PATH.sha256"
