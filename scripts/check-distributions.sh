#!/bin/sh

set -eu

SCRIPT_DIR=$(CDPATH= cd -- "$(dirname -- "$0")" && pwd)
REPO_DIR=$(CDPATH= cd -- "$SCRIPT_DIR/.." && pwd)
CHECK_DIR=$(mktemp -d "${TMPDIR:-/tmp}/koreader-distributions.XXXXXX")
trap 'rm -rf "$CHECK_DIR"' EXIT HUP INT TERM

build_scheme() {
    scheme=$1
    platform=$2
    configuration=${3:-Debug}
    log="$CHECK_DIR/$scheme-$configuration.log"

    echo "Building $scheme $configuration for $platform"
    if ! xcodebuild \
        -project "$REPO_DIR/KOReaderiOSRemote.xcodeproj" \
        -scheme "$scheme" \
        -configuration "$configuration" \
        -destination "generic/platform=$platform" \
        -derivedDataPath "$CHECK_DIR/DerivedData" \
        CODE_SIGNING_ALLOWED=NO \
        CODE_SIGNING_REQUIRED=NO \
        CODE_SIGN_IDENTITY= \
        build >"$log" 2>&1; then
        tail -n 80 "$log"
        return 1
    fi
}

echo "Checking locked-screen controls configuration"
python3 -m unittest discover -s "$REPO_DIR/tests" -p test_system_controls_configuration.py

echo "Testing RemoteCore"
xcrun swift test --package-path "$REPO_DIR/Packages/RemoteCore"

build_scheme KORemoteFull "iOS Simulator"
build_scheme KORemoteFree "iOS Simulator"
build_scheme KORemoteFreeWatch "iOS Simulator"
build_scheme KORemoteAltStore "iOS Simulator"
build_scheme KORemoteLabs "iOS Simulator"
build_scheme KORemoteWatchFree "watchOS Simulator"

build_scheme KORemoteFull iOS Release
build_scheme KORemoteFree iOS Release
build_scheme KORemoteFreeWatch iOS Release
build_scheme KORemoteAltStore iOS Release
build_scheme KORemoteLabs iOS Release
build_scheme KORemoteWatchFree watchOS Release

full_app="$CHECK_DIR/DerivedData/Build/Products/Debug-iphonesimulator/KORemote.app"
free_app="$CHECK_DIR/DerivedData/Build/Products/Debug-iphonesimulator/KORemoteFree.app"
free_watch_app="$CHECK_DIR/DerivedData/Build/Products/Debug-iphonesimulator/KORemoteFreeWatch.app"
altstore_app="$CHECK_DIR/DerivedData/Build/Products/Debug-iphonesimulator/KORemoteAltStore.app"
labs_app="$CHECK_DIR/DerivedData/Build/Products/Debug-iphonesimulator/KORemoteLabs.app"
full_release_app="$CHECK_DIR/DerivedData/Build/Products/Release-iphoneos/KORemote.app"
free_release_app="$CHECK_DIR/DerivedData/Build/Products/Release-iphoneos/KORemoteFree.app"
free_watch_release_app="$CHECK_DIR/DerivedData/Build/Products/Release-iphoneos/KORemoteFreeWatch.app"
altstore_release_app="$CHECK_DIR/DerivedData/Build/Products/Release-iphoneos/KORemoteAltStore.app"
labs_release_app="$CHECK_DIR/DerivedData/Build/Products/Release-iphoneos/KORemoteLabs.app"

test -d "$full_app/PlugIns/KORemoteControls.appex"
test -d "$full_app/Watch/KORemoteWatch.app"
test ! -e "$full_app/KORemoteLabs.app"
test ! -e "$free_app/PlugIns"
test ! -e "$free_app/Watch"
test -d "$free_watch_app/Watch/KORemoteWatchFree.app"
test ! -e "$free_watch_app/PlugIns"
test ! -e "$altstore_app/PlugIns"
test ! -e "$altstore_app/Watch"
test -d "$labs_app"
test -d "$full_release_app/PlugIns/KORemoteControls.appex"
test -d "$full_release_app/Watch/KORemoteWatch.app"
test ! -e "$full_release_app/KORemoteLabs.app"
test ! -e "$free_release_app/PlugIns"
test ! -e "$free_release_app/Watch"
test -d "$free_watch_release_app/Watch/KORemoteWatchFree.app"
test ! -e "$free_watch_release_app/PlugIns"
test ! -e "$altstore_release_app/PlugIns"
test ! -e "$altstore_release_app/Watch"
test -d "$labs_release_app"

plutil -extract KOReaderKeychainAccessGroup raw "$full_app/Info.plist" >/dev/null
if plutil -extract KOReaderKeychainAccessGroup raw "$free_app/Info.plist" >/dev/null 2>&1; then
    echo "KORemoteFree unexpectedly requests a shared Keychain access group" >&2
    exit 1
fi
if plutil -extract KOReaderKeychainAccessGroup raw "$altstore_app/Info.plist" >/dev/null 2>&1; then
    echo "KORemoteAltStore unexpectedly requests a shared Keychain access group" >&2
    exit 1
fi
for release_app in "$full_release_app" "$free_release_app" "$free_watch_release_app" "$altstore_release_app"; do
    plutil -extract UIBackgroundModes.0 raw "$release_app/Info.plist" | grep -qx audio
done

for release_app in \
    "$full_release_app" \
    "$free_release_app" \
    "$free_watch_release_app" \
    "$altstore_release_app" \
    "$full_release_app/Watch/KORemoteWatch.app" \
    "$free_watch_release_app/Watch/KORemoteWatchFree.app"; do
    executable=$(plutil -extract CFBundleExecutable raw "$release_app/Info.plist")
    if strings "$release_app/$executable" | grep -q KOREMOTE_SIMULATOR; then
        echo "Simulator test bridge leaked into $release_app" >&2
        exit 1
    fi
done

if rg -n 'setWantsVolumeButtonEvents|MediaRemote\.framework' "$REPO_DIR/App"; then
    echo "Private volume APIs leaked into the distributed app source group" >&2
    exit 1
fi

echo "All distribution builds and structural checks passed"
echo "Physical volume buttons, lock-screen execution, provisioning, and WatchConnectivity still require real devices"
