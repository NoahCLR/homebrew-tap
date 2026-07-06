#!/bin/zsh
set -euo pipefail

# Template: replace all {{PLACEHOLDERS}} before use (see templates/README.md,
# including the backport rule). Placeholders:
#   {{APP_NAME}}      display name, e.g. My App (the .app is "{{APP_NAME}}.app")
#   {{XCODEPROJ}}     e.g. MyApp.xcodeproj
#   {{SCHEME}}        e.g. MyApp
#   {{EXTENSION_ID}}  bundle id of an embedded appex, e.g. com.noah.MyApp.Extension
#                     (delete the pluginkit block if the app has no extension)
#
# Builds, signs with the stable local identity, installs to /Applications,
# and launches. Works without a paid Apple Developer account.

ROOT_DIR="$(cd "$(dirname "$0")/.." && pwd)"
BUILD_DIR="$(mktemp -d /tmp/{{SCHEME}}-install.XXXXXX)"
DERIVED_DATA="$BUILD_DIR/DerivedData"
APP_NAME="{{APP_NAME}}.app"
BUILT_APP="$DERIVED_DATA/Build/Products/Release/$APP_NAME"
INSTALL_APP="/Applications/$APP_NAME"
EXTENSION_ID="{{EXTENSION_ID}}"

source "$ROOT_DIR/Scripts/signing-common.sh"

echo "Building {{APP_NAME}}..."
trap 'rm -rf "$BUILD_DIR"' EXIT
xcodebuild \
  -project "$ROOT_DIR/{{XCODEPROJ}}" \
  -scheme "{{SCHEME}}" \
  -configuration Release \
  -destination 'generic/platform=macOS' \
  -derivedDataPath "$DERIVED_DATA" \
  CODE_SIGNING_ALLOWED=NO \
  build

if [[ ! -d "$BUILT_APP" ]]; then
  echo "Build did not produce $BUILT_APP" >&2
  exit 1
fi

ensure_signing_identity
sign_app_bundle "$BUILT_APP"

echo "Installing to /Applications..."
osascript -e 'tell application "{{APP_NAME}}" to quit' >/dev/null 2>&1 || true
rm -rf "$INSTALL_APP"
ditto "$BUILT_APP" "$INSTALL_APP"
codesign --verify --deep --strict "$INSTALL_APP"

echo "Registering app extension..."
pluginkit -a "$INSTALL_APP/Contents/PlugIns/"*.appex || true
sleep 1
pluginkit -e use -i "$EXTENSION_ID" || true

echo "Launching {{APP_NAME}}..."
open "$INSTALL_APP"
