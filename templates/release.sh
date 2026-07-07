#!/bin/zsh
set -euo pipefail

# Template: replace all {{PLACEHOLDERS}} before use (see templates/README.md,
# including the backport rule). Placeholders:
#   {{APP_NAME}}         display name, e.g. My App (the .app is "{{APP_NAME}}.app")
#   {{ARTIFACT_PREFIX}}  zip name prefix, no spaces, e.g. MyApp
#   {{GITHUB_REPO}}      e.g. NoahCLR/MyApp
#   {{CASK_TOKEN}}       lowercase-hyphenated, e.g. my-app
#   {{BUNDLE_ID}}        e.g. com.noah.MyApp
#   {{XCODEPROJ}}        e.g. MyApp.xcodeproj
#   {{SCHEME}}           e.g. MyApp
#   {{INFO_PLIST_PATH}}  main app Info.plist, e.g. MyApp/Resources/Info.plist
#   {{MIN_MACOS}}        brew macOS symbol, e.g. :sonoma
#   {{CASK_DESC}}        one-line cask description, no trailing period
#   {{CASK_POSTFLIGHT}}  optional cask postflight block; use to register appex
#                        bundles with pluginkit, or leave blank
#
# Builds, signs, and publishes a release:
#   1. refuses to run on a dirty tree, runs the tests
#   2. builds Release and signs it with the stable identity (see signing-common.sh)
#   3. zips the app, pushes the version tag, creates the GitHub release
#   4. rewrites the cask in the Homebrew tap with the new version + sha256
# The version comes from CFBundleShortVersionString in the main app Info.plist.

ROOT_DIR="$(cd "$(dirname "$0")/.." && pwd)"
APP_NAME="{{APP_NAME}}.app"
APP_REPO="{{GITHUB_REPO}}"
TAP_REPO="NoahCLR/homebrew-tap"
CASK_TOKEN="{{CASK_TOKEN}}"

source "$ROOT_DIR/Scripts/signing-common.sh"

if [[ -n "$(git -C "$ROOT_DIR" status --porcelain)" ]]; then
  echo "Working tree is not clean. Commit or stash before releasing." >&2
  exit 1
fi

VERSION="$(/usr/libexec/PlistBuddy -c 'Print :CFBundleShortVersionString' "$ROOT_DIR/{{INFO_PLIST_PATH}}")"
TAG="v$VERSION"

if gh release view "$TAG" --repo "$APP_REPO" >/dev/null 2>&1; then
  echo "Release $TAG already exists on $APP_REPO. Bump CFBundleShortVersionString first." >&2
  exit 1
fi

BUILD_DIR="$(mktemp -d /tmp/{{CASK_TOKEN}}-release.XXXXXX)"
trap 'rm -rf "$BUILD_DIR"' EXIT
DERIVED_DATA="$BUILD_DIR/DerivedData"
BUILT_APP="$DERIVED_DATA/Build/Products/Release/$APP_NAME"

echo "Running tests..."
xcodebuild \
  -project "$ROOT_DIR/{{XCODEPROJ}}" \
  -scheme "{{SCHEME}}" \
  -configuration Debug \
  -destination 'platform=macOS' \
  CODE_SIGNING_ALLOWED=NO \
  test

echo "Building Release $VERSION..."
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

ZIP_PATH="$BUILD_DIR/{{ARTIFACT_PREFIX}}-$VERSION.zip"
ditto -c -k --sequesterRsrc --keepParent "$BUILT_APP" "$ZIP_PATH"
SHA256="$(shasum -a 256 "$ZIP_PATH" | awk '{print $1}')"
echo "Artifact: $ZIP_PATH"
echo "SHA256:   $SHA256"

echo "Tagging $TAG and pushing..."
git -C "$ROOT_DIR" tag "$TAG" 2>/dev/null || echo "Tag $TAG already exists locally."
git -C "$ROOT_DIR" push origin HEAD "$TAG"

echo "Creating GitHub release $TAG..."
gh release create "$TAG" "$ZIP_PATH" \
  --repo "$APP_REPO" \
  --title "{{APP_NAME}} $VERSION" \
  --notes "Install or upgrade with:

\`\`\`sh
brew install NoahCLR/tap/$CASK_TOKEN
xattr -dr com.apple.quarantine \"/Applications/{{APP_NAME}}.app\"
\`\`\`

The \`xattr\` line clears Gatekeeper quarantine (the app is signed but not notarized)."

echo "Updating cask in $TAP_REPO..."
TAP_DIR="$BUILD_DIR/homebrew-tap"
gh repo clone "$TAP_REPO" "$TAP_DIR" -- --depth 1
mkdir -p "$TAP_DIR/Casks"
cat > "$TAP_DIR/Casks/$CASK_TOKEN.rb" <<EOF
cask "$CASK_TOKEN" do
  version "$VERSION"
  sha256 "$SHA256"

  url "https://github.com/$APP_REPO/releases/download/v#{version}/{{ARTIFACT_PREFIX}}-#{version}.zip"
  name "{{APP_NAME}}"
  desc "{{CASK_DESC}}"
  homepage "https://github.com/$APP_REPO"

  depends_on macos: {{MIN_MACOS}}

  app "{{APP_NAME}}.app"

{{CASK_POSTFLIGHT}}

  uninstall quit: "{{BUNDLE_ID}}"

  # List specific files only — never a whole Application Support directory
  # (on the dev machine it can contain the local signing key).
  zap trash: [
    "~/Library/Preferences/{{BUNDLE_ID}}.plist",
  ]

  caveats <<~EOS
    {{APP_NAME}} is signed with a development certificate and is not notarized,
    so Gatekeeper blocks the first launch. Either clear the quarantine flag:
      xattr -dr com.apple.quarantine "/Applications/{{APP_NAME}}.app"
    or launch once, then approve it under
    System Settings > Privacy & Security > Open Anyway.
    The same applies after every brew upgrade.
  EOS
end
EOF

git -C "$TAP_DIR" add "Casks/$CASK_TOKEN.rb"
if git -C "$TAP_DIR" diff --cached --quiet; then
  echo "Cask unchanged; nothing to push to the tap."
else
  git -C "$TAP_DIR" commit -m "$CASK_TOKEN $VERSION"
  git -C "$TAP_DIR" push
fi

echo ""
echo "Released {{APP_NAME}} $VERSION."
echo "Install with: brew install NoahCLR/tap/$CASK_TOKEN"
