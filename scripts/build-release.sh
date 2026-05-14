#!/usr/bin/env bash
set -euo pipefail

export PATH="/opt/homebrew/opt/zig@0.15/bin:$PATH"

REPO="giggs-lynx/ghostty"
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ROOT_DIR="$(cd "$SCRIPT_DIR/.." && pwd)"
TAP_DIR="$(cd "$ROOT_DIR/../homebrew-tap" && pwd)"

# Read version from build.zig.zon and append build date
BASE_VERSION=$(grep '\.version = ' "$ROOT_DIR/build.zig.zon" | sed 's/.*\.version = "\(.*\)".*/\1/')
VERSION="${BASE_VERSION}.quickterm-tab.$(date +%Y%m%d)"
TAG="quickterm-tab"

echo "==> Version: $VERSION"
echo ""

# Build GhosttyKit
echo "==> Building GhosttyKit..."
cd "$ROOT_DIR"
zig build \
    -Doptimize=ReleaseFast \
    -Demit-macos-app=false \
    -Dversion-string="$VERSION"

# Build Ghostty.app
echo "==> Building Ghostty.app..."
cd "$ROOT_DIR/macos"
xcodebuild \
    -target Ghostty \
    -configuration Release \
    CODE_SIGN_IDENTITY="" \
    CODE_SIGNING_REQUIRED=NO \
    CODE_SIGNING_ALLOWED=NO

# Ad-hoc sign
echo "==> Signing..."
codesign --deep --force --sign - \
    --entitlements "$ROOT_DIR/macos/Ghostty.entitlements" \
    "$ROOT_DIR/macos/build/Release/Ghostty.app"

# Zip
echo "==> Zipping..."
cd "$ROOT_DIR/macos/build/Release"
rm -f "$ROOT_DIR/ghostty-macos.zip"
zip -9 -r --symlinks "$ROOT_DIR/ghostty-macos.zip" Ghostty.app

# GitHub Release
echo "==> Updating GitHub Release $TAG..."
cd "$ROOT_DIR"
gh release upload "$TAG" ghostty-macos.zip --clobber --repo "$REPO" 2>/dev/null || \
gh release create "$TAG" \
    --repo "$REPO" \
    --title "Ghostty (quickterm-tab)" \
    ghostty-macos.zip

# Update Homebrew tap
echo "==> Updating Homebrew tap..."
SHA256=$(shasum -a 256 ghostty-macos.zip | awk '{print $1}')
sed -i '' "s/version \".*\"/version \"${VERSION}\"/" "$TAP_DIR/Casks/ghostty.rb"
sed -i '' "s/sha256 \".*\"/sha256 \"${SHA256}\"/" "$TAP_DIR/Casks/ghostty.rb"

cd "$TAP_DIR"
git pull --rebase
git add Casks/ghostty.rb
git commit -m "ghostty: update to ${VERSION}"
git push

echo ""
echo "==> Done! Install with:"
echo "    brew upgrade ghostty"
echo "    # or fresh install:"
echo "    brew install --no-quarantine giggs-lynx/tap/ghostty"
