#!/bin/bash
set -euo pipefail

# -----------------------------------------------------------------------------
# Archive, notarize, DMG, sign for Sparkle, publish GitHub release,
# and update appcast.xml.
#
# Prerequisites:
#   - xcrun notarytool store-credentials 'notary' (one-time setup)
#   - gh auth login
#   - Sparkle EdDSA keys in keychain (run: ./Sparkle-tools/bin/generate_keys)
#
# Usage:
#   ./Scripts/build-and-notarize.sh [--version X.Y.Z] [--title "..."]
#
# Both values are prompted for when omitted. Supply them to run unattended;
# with no controlling terminal, a missing value is an error rather than a
# silently empty answer.
# -----------------------------------------------------------------------------

# --- Constants ---
SCHEME="DueDate (Release)"
APP_NAME="DueDate"
KEYCHAIN_PROFILE="notary"
SPARKLE_VERSION="2.9.1"
GITHUB_REPO="memfrag/DueDate"

# --- Paths ---
SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
PROJECT_DIR="$(cd "$SCRIPT_DIR/.." && pwd)"
BUILD_DIR="$PROJECT_DIR/build"
SPARKLE_TOOLS_DIR="$PROJECT_DIR/Sparkle-tools"
ARCHIVE_PATH="$BUILD_DIR/$APP_NAME.xcarchive"
EXPORT_DIR="$BUILD_DIR/export"
EXPORT_OPTIONS="$SCRIPT_DIR/ExportOptions.plist"
PBXPROJ="$PROJECT_DIR/$APP_NAME.xcodeproj/project.pbxproj"

# --- Helpers ---
error() {
    echo "ERROR: $1" >&2
    exit 1
}

usage() {
    cat <<USAGE
Usage: $(basename "$0") [options]

Options:
  -v, --version X.Y.Z   Version to release. Prompted for when omitted.
  -t, --title "..."     GitHub release title. Defaults to "<app> <version>".
  -h, --help            Show this help.
USAGE
}

# Prompts for a value, or fails when there is no terminal to prompt on. Reading
# from a non-tty would otherwise return empty and release the wrong thing.
#   $1 prompt, $2 default (may be empty), $3 what is missing (for the error)
prompt_for() {
    local prompt="$1" fallback="$2" what="$3" reply
    if [ ! -t 0 ]; then
        error "$what not supplied and stdin is not a terminal. Pass it as an option (see --help)."
    fi
    read -rp "$prompt" reply
    printf '%s' "${reply:-$fallback}"
}

VERSION_ARG=""
TITLE_ARG=""
while [ $# -gt 0 ]; do
    case "$1" in
        -v|--version)
            [ $# -ge 2 ] || error "--version requires a value."
            VERSION_ARG="$2"; shift 2 ;;
        --version=*)
            VERSION_ARG="${1#*=}"; shift ;;
        -t|--title)
            [ $# -ge 2 ] || error "--title requires a value."
            TITLE_ARG="$2"; shift 2 ;;
        --title=*)
            TITLE_ARG="${1#*=}"; shift ;;
        -h|--help)
            usage; exit 0 ;;
        *)
            usage >&2; error "Unknown argument: $1" ;;
    esac
done

if [ -n "$VERSION_ARG" ] && ! printf '%s' "$VERSION_ARG" | grep -Eq '^[0-9]+(\.[0-9]+)*$'; then
    error "Version must look like 1.2.3, got: $VERSION_ARG"
fi

# Fail before the build directory is wiped, rather than at the first prompt.
if [ ! -t 0 ] && [ -z "$VERSION_ARG" ]; then
    error "No terminal to prompt on. Pass --version (and optionally --title); see --help."
fi

# --- Clean and create build directory ---
echo "==> Cleaning build directory..."
rm -rf "$BUILD_DIR"
mkdir -p "$BUILD_DIR"

# --- Download Sparkle tools if needed ---
if [ ! -x "$SPARKLE_TOOLS_DIR/bin/sign_update" ]; then
    echo "==> Downloading Sparkle tools $SPARKLE_VERSION..."
    curl -sL "https://github.com/sparkle-project/Sparkle/releases/download/$SPARKLE_VERSION/Sparkle-$SPARKLE_VERSION.tar.xz" -o "$BUILD_DIR/Sparkle.tar.xz"
    mkdir -p "$SPARKLE_TOOLS_DIR"
    tar -xf "$BUILD_DIR/Sparkle.tar.xz" -C "$SPARKLE_TOOLS_DIR"
    rm "$BUILD_DIR/Sparkle.tar.xz"
    echo "    Sparkle tools installed at $SPARKLE_TOOLS_DIR"
fi

# --- Version checking ---
echo "==> Checking version..."
CURRENT_VERSION=$(grep 'MARKETING_VERSION' "$PBXPROJ" | head -1 | sed 's/.*= *//;s/ *;.*//' || true)
if [ -z "$CURRENT_VERSION" ]; then
    error "Could not read MARKETING_VERSION from project.pbxproj."
fi
echo "    Current version: $CURRENT_VERSION"

LATEST_TAG=$(gh release view --repo "$GITHUB_REPO" --json tagName -q '.tagName' 2>/dev/null || true)
if [ -n "$LATEST_TAG" ]; then
    echo "    Latest release: $LATEST_TAG"
fi

NEED_NEW_VERSION=false
if [ -z "$LATEST_TAG" ]; then
    echo "    No existing releases found."
elif [ "$CURRENT_VERSION" = "$LATEST_TAG" ]; then
    NEED_NEW_VERSION=true
    echo "    Current version matches latest release."
fi

if [ -n "$VERSION_ARG" ]; then
    VERSION="$VERSION_ARG"
elif [ "$NEED_NEW_VERSION" = true ]; then
    # Re-releasing the current version would collide with the existing tag.
    VERSION=$(prompt_for "    Enter new version: " "" "Version")
else
    VERSION=$(prompt_for "    Enter version to release [$CURRENT_VERSION]: " "$CURRENT_VERSION" "Version")
fi

if [ -z "$VERSION" ]; then
    error "Version cannot be empty."
fi
if [ "$NEED_NEW_VERSION" = true ] && [ "$VERSION" = "$LATEST_TAG" ]; then
    error "Version $VERSION is already released. Choose a new one."
fi
echo "    Releasing version: $VERSION"

if [ "$VERSION" != "$CURRENT_VERSION" ]; then
    echo "==> Updating version to $VERSION..."
    sed -i '' "s/MARKETING_VERSION = [^;]*/MARKETING_VERSION = $VERSION/" "$PBXPROJ" || error "Failed to update MARKETING_VERSION in project.pbxproj"
    sed -i '' "s/CURRENT_PROJECT_VERSION = [^;]*/CURRENT_PROJECT_VERSION = $VERSION/" "$PBXPROJ" || error "Failed to update CURRENT_PROJECT_VERSION in project.pbxproj"
    cd "$PROJECT_DIR"
    git add "$PBXPROJ"
    git commit -m "Bump version to $VERSION"
    git push origin HEAD
    echo "    Version updated and pushed."
fi

TAG="$VERSION"

# --- Archive ---
echo "==> Archiving..."
xcodebuild archive \
    -project "$PROJECT_DIR/$APP_NAME.xcodeproj" \
    -scheme "$SCHEME" \
    -archivePath "$ARCHIVE_PATH" \
    -configuration Release \
    -arch arm64 \
    -allowProvisioningUpdates \
    ENABLE_HARDENED_RUNTIME=YES \
    2>&1 | tee "$BUILD_DIR/archive.log" | tail -5

if [ ! -d "$ARCHIVE_PATH" ]; then
    echo "--- Last 30 lines of archive.log ---"
    tail -30 "$BUILD_DIR/archive.log"
    error "Archive failed. See $BUILD_DIR/archive.log for details."
fi
echo "    Archive created."

# --- Export ---
echo "==> Exporting..."
xcodebuild -exportArchive \
    -archivePath "$ARCHIVE_PATH" \
    -exportPath "$EXPORT_DIR" \
    -exportOptionsPlist "$EXPORT_OPTIONS" \
    -allowProvisioningUpdates \
    2>&1 | tee "$BUILD_DIR/export.log" | tail -5

APP_PATH="$EXPORT_DIR/$APP_NAME.app"
if [ ! -d "$APP_PATH" ]; then
    echo "--- Last 30 lines of export.log ---"
    tail -30 "$BUILD_DIR/export.log"
    error "Export failed. See $BUILD_DIR/export.log for details."
fi
echo "    Export complete."

# --- Read version from exported app ---
EXPORTED_VERSION=$(/usr/libexec/PlistBuddy -c "Print :CFBundleShortVersionString" "$APP_PATH/Contents/Info.plist")
echo "    Exported app version: $EXPORTED_VERSION"

# --- Create DMG ---
echo "==> Creating DMG..."
DMG_PATH="$BUILD_DIR/$APP_NAME-$VERSION.dmg"
DMG_STAGING="$BUILD_DIR/dmg-staging"
mkdir -p "$DMG_STAGING"
cp -a "$APP_PATH" "$DMG_STAGING/"
ln -s /Applications "$DMG_STAGING/Applications"
hdiutil create -volname "$APP_NAME" -srcfolder "$DMG_STAGING" -ov -format UDZO "$DMG_PATH" || error "Failed to create DMG."
rm -rf "$DMG_STAGING"
echo "    DMG created: $DMG_PATH"

# --- Verify codesign ---
echo "==> Verifying codesign..."
codesign --verify --deep --strict "$APP_PATH" || error "Codesign verification failed."
echo "    Codesign verified."

# --- Notarize ---
echo "==> Submitting for notarization..."
xcrun notarytool submit "$DMG_PATH" \
    --keychain-profile "$KEYCHAIN_PROFILE" \
    --wait || error "Notarization failed."
echo "    Notarization complete."

# --- Staple ---
echo "==> Stapling..."
xcrun stapler staple "$DMG_PATH" || error "Stapling failed."
echo "    Stapled."

# --- Sign for Sparkle ---
echo "==> Signing for Sparkle..."
"$SPARKLE_TOOLS_DIR/bin/sign_update" "$DMG_PATH" || error "Sparkle signing failed."

# --- Prompt for release title ---
if [ -n "$TITLE_ARG" ]; then
    RELEASE_TITLE="$TITLE_ARG"
elif [ -t 0 ]; then
    RELEASE_TITLE=$(prompt_for "==> Enter release title [$APP_NAME $VERSION]: " "$APP_NAME $VERSION" "Release title")
else
    # Unlike the version, the title has a safe default -- so take it rather than
    # failing here, which would be after notarization has already succeeded.
    RELEASE_TITLE="$APP_NAME $VERSION"
    echo "==> Release title: $RELEASE_TITLE"
fi

# --- Create GitHub release ---
echo "==> Creating GitHub release..."
cd "$PROJECT_DIR"
git tag "$TAG" || error "Failed to create tag $TAG."
git push origin "$TAG" || error "Failed to push tag $TAG."
gh release create "$TAG" "$DMG_PATH" \
    --repo "$GITHUB_REPO" \
    --title "$RELEASE_TITLE" \
    --generate-notes || error "Failed to create GitHub release."
echo "    Release created: $TAG"

# --- Generate appcast ---
echo "==> Generating appcast..."
APPCAST_DIR="$BUILD_DIR/appcast-assets"
mkdir -p "$APPCAST_DIR"

if [ -f "$PROJECT_DIR/appcast.xml" ]; then
    cp "$PROJECT_DIR/appcast.xml" "$APPCAST_DIR/"
fi

cp "$DMG_PATH" "$APPCAST_DIR/"

"$SPARKLE_TOOLS_DIR/bin/generate_appcast" \
    --download-url-prefix "https://github.com/$GITHUB_REPO/releases/download/$TAG/" \
    -o "$APPCAST_DIR/appcast.xml" \
    "$APPCAST_DIR" || error "Failed to generate appcast."

cp "$APPCAST_DIR/appcast.xml" "$PROJECT_DIR/appcast.xml"
cd "$PROJECT_DIR"
git add appcast.xml
git commit -m "Update appcast for $VERSION"
git push origin HEAD
echo "    Appcast updated and pushed."

echo ""
echo "==> Done! Released $APP_NAME $VERSION"
