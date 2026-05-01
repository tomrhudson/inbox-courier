#!/usr/bin/env bash
# Builds a distributable InboxCourier.app bundle from the SwiftPM executable.

set -euo pipefail

REPO_DIR="$(cd "$(dirname "$0")/.." && pwd)"
APP_NAME="InboxCourier"
PRODUCT_NAME="InboxCourier"
BUNDLE_ID="${BUNDLE_ID:-com.tomrhudson.inboxcourier}"
VERSION="${VERSION:-0.0.0-dev}"
BUILD_NUMBER="${BUILD_NUMBER:-1}"
CONFIGURATION="${CONFIGURATION:-release}"
SIGN_IDENTITY="${SIGN_IDENTITY:--}"
DIST_DIR="$REPO_DIR/dist"
APP_DIR="$DIST_DIR/$APP_NAME.app"
CONTENTS_DIR="$APP_DIR/Contents"
MACOS_DIR="$CONTENTS_DIR/MacOS"
RESOURCES_DIR="$CONTENTS_DIR/Resources"

cd "$REPO_DIR"

echo "==> Building $PRODUCT_NAME ($CONFIGURATION)"
swift build -c "$CONFIGURATION" --arch arm64 --arch x86_64

if [ "$CONFIGURATION" = "debug" ]; then
    PRODUCTS_DIR="Debug"
else
    PRODUCTS_DIR="Release"
fi

EXECUTABLE_PATH="$REPO_DIR/.build/apple/Products/$PRODUCTS_DIR/$PRODUCT_NAME"
if [ ! -x "$EXECUTABLE_PATH" ]; then
    echo "error: expected executable at $EXECUTABLE_PATH" >&2
    exit 1
fi

echo "==> Creating app bundle"
rm -rf "$APP_DIR"
mkdir -p "$MACOS_DIR" "$RESOURCES_DIR"
cp "$EXECUTABLE_PATH" "$MACOS_DIR/$PRODUCT_NAME"

/usr/libexec/PlistBuddy -c "Clear dict" "$CONTENTS_DIR/Info.plist" >/dev/null 2>&1 || true
/usr/libexec/PlistBuddy -c "Add :CFBundleDevelopmentRegion string en" "$CONTENTS_DIR/Info.plist"
/usr/libexec/PlistBuddy -c "Add :CFBundleExecutable string $PRODUCT_NAME" "$CONTENTS_DIR/Info.plist"
/usr/libexec/PlistBuddy -c "Add :CFBundleIdentifier string $BUNDLE_ID" "$CONTENTS_DIR/Info.plist"
/usr/libexec/PlistBuddy -c "Add :CFBundleInfoDictionaryVersion string 6.0" "$CONTENTS_DIR/Info.plist"
/usr/libexec/PlistBuddy -c "Add :CFBundleName string Inbox Courier" "$CONTENTS_DIR/Info.plist"
/usr/libexec/PlistBuddy -c "Add :CFBundleDisplayName string Inbox Courier" "$CONTENTS_DIR/Info.plist"
/usr/libexec/PlistBuddy -c "Add :CFBundlePackageType string APPL" "$CONTENTS_DIR/Info.plist"
/usr/libexec/PlistBuddy -c "Add :CFBundleShortVersionString string $VERSION" "$CONTENTS_DIR/Info.plist"
/usr/libexec/PlistBuddy -c "Add :CFBundleVersion string $BUILD_NUMBER" "$CONTENTS_DIR/Info.plist"
/usr/libexec/PlistBuddy -c "Add :LSMinimumSystemVersion string 13.0" "$CONTENTS_DIR/Info.plist"
/usr/libexec/PlistBuddy -c "Add :LSUIElement bool true" "$CONTENTS_DIR/Info.plist"
/usr/libexec/PlistBuddy -c "Add :NSHighResolutionCapable bool true" "$CONTENTS_DIR/Info.plist"
/usr/libexec/PlistBuddy -c "Add :NSPrincipalClass string NSApplication" "$CONTENTS_DIR/Info.plist"

echo "==> Removing extended attributes"
xattr -cr "$APP_DIR"

echo "==> Signing app bundle"
if [ "$SIGN_IDENTITY" = "-" ]; then
    codesign --force --sign - "$APP_DIR"
else
    codesign --force --options runtime --timestamp --sign "$SIGN_IDENTITY" "$APP_DIR"
fi

echo "==> Verifying signature"
codesign --verify --deep --strict --verbose=2 "$APP_DIR"

ARCHIVE_NAME="$APP_NAME-$VERSION.zip"
ARCHIVE_PATH="$DIST_DIR/$ARCHIVE_NAME"

echo "==> Creating $ARCHIVE_NAME"
xattr -cr "$APP_DIR"
codesign --verify --deep --strict --verbose=2 "$APP_DIR"
ditto -c -k --keepParent "$APP_DIR" "$ARCHIVE_PATH"
shasum -a 256 "$ARCHIVE_PATH" > "$ARCHIVE_PATH.sha256"

echo "Packaged:"
echo "  $APP_DIR"
echo "  $ARCHIVE_PATH"
echo "  $ARCHIVE_PATH.sha256"
