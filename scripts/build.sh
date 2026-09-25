#!/bin/bash
# Builds an unofficial Compositor for macOS 15 (Intel and Apple silicon) from an upstream checkout.
#
#   scripts/build.sh <upstream checkout> <output directory>
#
# Applies patches/macos15.patch, archives a universal Release with a macOS 15 deployment target, signs it ad hoc
# (no Developer ID, so no notarization) and writes <output>/Compositor-<version>-macos15.zip.
# The deployment target is passed to xcodebuild instead of patched into project.pbxproj: the lines around it change
# with every release and would break the patch.
# The hardened runtime is off: it only matters for notarization, and its library validation refuses to load the
# embedded Sparkle framework when app and framework are signed ad hoc, with no Team ID.
set -euo pipefail

SOURCE="$(cd "$1" && pwd)"
mkdir -p "$2"
OUT="$(cd "$2" && pwd)"
HERE="$(cd "$(dirname "$0")/.." && pwd)"
PATCH="$HERE/patches/macos15.patch"
TARGET=15.0
APP=Compositor
WORK="$OUT/work"

echo "==> Applying $(basename "$PATCH")"
if git -C "$SOURCE" apply --check --reverse "$PATCH" 2>/dev/null; then
  echo "already applied"
else
  git -C "$SOURCE" apply --3way "$PATCH"
fi

rm -rf "$WORK"
mkdir -p "$WORK"

echo "==> Archiving a universal Release for macOS $TARGET"
xcodebuild archive -quiet \
  -project "$SOURCE/$APP.xcodeproj" -scheme "$APP" -configuration Release \
  -destination "generic/platform=macOS" \
  -archivePath "$WORK/$APP.xcarchive" -derivedDataPath "$WORK/DerivedData" \
  MACOSX_DEPLOYMENT_TARGET="$TARGET" \
  CODE_SIGN_STYLE=Manual CODE_SIGN_IDENTITY=- DEVELOPMENT_TEAM= \
  ENABLE_HARDENED_RUNTIME=NO

APP_PATH="$WORK/$APP.xcarchive/Products/Applications/$APP.app"
BINARY="$APP_PATH/Contents/MacOS/$APP"
PLIST="$APP_PATH/Contents/Info.plist"
VERSION=$(/usr/libexec/PlistBuddy -c "Print :CFBundleShortVersionString" "$PLIST")

echo "==> Checking the build"
archs=$(lipo -archs "$BINARY")
minimum=$(/usr/libexec/PlistBuddy -c "Print :LSMinimumSystemVersion" "$PLIST")
echo "version $VERSION, architectures: $archs, LSMinimumSystemVersion: $minimum"
[[ "$archs" == *x86_64* && "$archs" == *arm64* ]] || { echo "Not a universal binary."; exit 1; }
[[ "$minimum" == "$TARGET" ]] || { echo "LSMinimumSystemVersion is $minimum, expected $TARGET."; exit 1; }
codesign --verify --deep --strict "$APP_PATH"

ZIP="$OUT/$APP-$VERSION-macos15.zip"
ditto -c -k --keepParent "$APP_PATH" "$ZIP"
echo "$ZIP"
