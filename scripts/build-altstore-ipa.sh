#!/bin/sh

set -eu

SCRIPT_DIR=$(CDPATH= cd -- "$(dirname -- "$0")" && pwd)
REPO_DIR=$(CDPATH= cd -- "$SCRIPT_DIR/.." && pwd)
BUILD_DIR=$(mktemp -d "${TMPDIR:-/tmp}/koreader-altstore.XXXXXX")
trap 'rm -rf "$BUILD_DIR"' EXIT HUP INT TERM

VERSION=${1:-dev}
case "$VERSION" in
    ""|-*|*[!A-Za-z0-9._-]*)
        echo "Version label may contain only letters, digits, dots, underscores, and hyphens" >&2
        exit 2
        ;;
esac
OUTPUT_DIR=${DIST_DIR:-"$REPO_DIR/dist"}
DERIVED_DATA="$BUILD_DIR/DerivedData"
STAGING_DIR="$BUILD_DIR/Staging"
APP_PATH="$DERIVED_DATA/Build/Products/Release-iphoneos/KORemoteAltStore.app"
IPA_PATH="$OUTPUT_DIR/KORemoteAltStore-$VERSION-unsigned.ipa"
BUILD_LOG="$BUILD_DIR/xcodebuild.log"

mkdir -p "$OUTPUT_DIR" "$STAGING_DIR/Payload"

echo "Building unsigned AltStore Classic product"
if ! xcodebuild \
    -project "$REPO_DIR/KOReaderiOSRemote.xcodeproj" \
    -scheme KORemoteAltStore \
    -configuration Release \
    -destination 'generic/platform=iOS' \
    -derivedDataPath "$DERIVED_DATA" \
    CODE_SIGNING_ALLOWED=NO \
    CODE_SIGNING_REQUIRED=NO \
    CODE_SIGN_IDENTITY= \
    build >"$BUILD_LOG" 2>&1; then
    tail -n 100 "$BUILD_LOG"
    exit 1
fi

test -d "$APP_PATH"
test ! -e "$APP_PATH/PlugIns"
test ! -e "$APP_PATH/Watch"
if plutil -extract KOReaderKeychainAccessGroup raw "$APP_PATH/Info.plist" >/dev/null 2>&1; then
    echo "AltStore product unexpectedly requests a shared Keychain access group" >&2
    exit 1
fi
plutil -extract UIBackgroundModes.0 raw "$APP_PATH/Info.plist" | grep -qx audio

cp -R "$APP_PATH" "$STAGING_DIR/Payload/"
/usr/bin/ditto -c -k --sequesterRsrc --keepParent "$STAGING_DIR/Payload" "$IPA_PATH"

test "$(unzip -Z1 "$IPA_PATH" | grep -Ec '^Payload/[^/]+\.app/$')" -eq 1
if unzip -Z1 "$IPA_PATH" | grep -Eq '(^|/)(PlugIns|Watch|KORemoteLabs)(/|$)'; then
    echo "AltStore IPA contains an unsupported embedded product" >&2
    exit 1
fi

echo "Created $IPA_PATH"
echo "Unsigned artifact: AltStore Classic must re-sign it with each user's Apple Account"
