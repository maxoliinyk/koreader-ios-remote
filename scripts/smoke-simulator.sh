#!/bin/sh

set -eu

SCRIPT_DIR=$(CDPATH= cd -- "$(dirname -- "$0")" && pwd)
REPO_DIR=$(CDPATH= cd -- "$SCRIPT_DIR/.." && pwd)
SMOKE_DIR=$(mktemp -d "${TMPDIR:-/tmp}/koreader-simulator-smoke.XXXXXX")
EVENTS_FILE="$SMOKE_DIR/mock-events.jsonl"
MOCK_LOG="$SMOKE_DIR/mock-server.log"
SECRET=AAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA
MOCK_PORT=${MOCK_PORT:-19090}
PAIR_ATTEMPTS=${PAIR_ATTEMPTS:-600}
WATCH_ACTION_ATTEMPTS=${WATCH_ACTION_ATTEMPTS:-300}
INTERACTIVE_SIMULATOR=${INTERACTIVE_SIMULATOR:-1}
SKIP_WATCH=${SKIP_WATCH:-0}
SMOKE_ONLY_SCHEME=${SMOKE_ONLY_SCHEME:-}
CREATED_PHONE=0
CREATED_WATCH=0
PHONE_UDID=${SIMULATOR_UDID:-}
WATCH_UDID=${WATCH_SIMULATOR_UDID:-}
SERVER_PID=

require_positive_integer() {
    name=$1
    value=$2
    case "$value" in
        ''|*[!0-9]*)
            echo "$name must be a positive integer" >&2
            exit 2
            ;;
    esac
    if test "$value" -le 0; then
        echo "$name must be a positive integer" >&2
        exit 2
    fi
}

require_positive_integer MOCK_PORT "$MOCK_PORT"
if test "$MOCK_PORT" -gt 65535; then
    echo "MOCK_PORT must be at most 65535" >&2
    exit 2
fi
require_positive_integer PAIR_ATTEMPTS "$PAIR_ATTEMPTS"
require_positive_integer WATCH_ACTION_ATTEMPTS "$WATCH_ACTION_ATTEMPTS"
case "$INTERACTIVE_SIMULATOR" in 0|1) ;; *) echo "INTERACTIVE_SIMULATOR must be 0 or 1" >&2; exit 2 ;; esac
case "$SKIP_WATCH" in 0|1) ;; *) echo "SKIP_WATCH must be 0 or 1" >&2; exit 2 ;; esac
case "$SMOKE_ONLY_SCHEME" in
    ''|KORemoteFull|KORemoteFree|KORemoteFreeWatch|KORemoteAltStore|KORemoteLabs) ;;
    *) echo "Unknown SMOKE_ONLY_SCHEME: $SMOKE_ONLY_SCHEME" >&2; exit 2 ;;
esac

cleanup() {
    if test -n "$SERVER_PID"; then
        kill "$SERVER_PID" >/dev/null 2>&1 || true
        wait "$SERVER_PID" >/dev/null 2>&1 || true
    fi
    if test "$CREATED_WATCH" -eq 1 && test -n "$WATCH_UDID"; then
        xcrun simctl shutdown "$WATCH_UDID" >/dev/null 2>&1 || true
        xcrun simctl delete "$WATCH_UDID" >/dev/null 2>&1 || true
    fi
    if test "$CREATED_PHONE" -eq 1 && test -n "$PHONE_UDID"; then
        xcrun simctl shutdown "$PHONE_UDID" >/dev/null 2>&1 || true
        xcrun simctl delete "$PHONE_UDID" >/dev/null 2>&1 || true
    fi
    rm -rf "$SMOKE_DIR"
}
trap cleanup EXIT HUP INT TERM

if test "$SKIP_WATCH" -eq 1; then
    WATCH_RUNTIME=
    WATCH_UDID=
else
    WATCH_RUNTIME=${WATCH_RUNTIME:-$(xcrun simctl list runtimes -j | python3 -c '
import json, sys
items = [item for item in json.load(sys.stdin)["runtimes"] if item.get("isAvailable") and ".watchOS-" in item["identifier"]]
items.sort(key=lambda item: tuple(int(part) for part in item["version"].split(".")))
print(items[-1]["identifier"] if items else "")
')}
fi

if test -z "$PHONE_UDID"; then
    IOS_RUNTIME=${IOS_RUNTIME:-$(xcrun simctl list runtimes -j | python3 -c '
import json, sys
items = [item for item in json.load(sys.stdin)["runtimes"] if item.get("isAvailable") and ".iOS-" in item["identifier"]]
items.sort(key=lambda item: tuple(int(part) for part in item["version"].split(".")))
print(items[-1]["identifier"] if items else "")
')}
    if test -z "$IOS_RUNTIME"; then
        echo "No available iOS Simulator runtime" >&2
        exit 1
    fi
    PHONE_DEVICE_TYPE=${PHONE_DEVICE_TYPE:-$(xcrun simctl list devicetypes -j | python3 -c '
import json, sys
items = [item for item in json.load(sys.stdin)["devicetypes"] if item["name"].startswith("iPhone")]
print(items[0]["identifier"] if items else "")
')}
    if test -z "$PHONE_DEVICE_TYPE"; then
        echo "No available iPhone Simulator device type" >&2
        exit 1
    fi
    PHONE_UDID=$(xcrun simctl create \
        "KORemote Distribution Smoke $$" \
        "$PHONE_DEVICE_TYPE" \
        "$IOS_RUNTIME")
    CREATED_PHONE=1
fi

if test -z "$WATCH_UDID" && test -n "$WATCH_RUNTIME" && test "$CREATED_PHONE" -eq 1; then
    WATCH_DEVICE_TYPE=$(xcrun simctl list devicetypes -j | python3 -c '
import json, sys
items = [item for item in json.load(sys.stdin)["devicetypes"] if item["name"].startswith("Apple Watch")]
print(items[0]["identifier"] if items else "")
')
    if test -n "$WATCH_DEVICE_TYPE"; then
        WATCH_UDID=$(xcrun simctl create "KORemote Watch Smoke $$" "$WATCH_DEVICE_TYPE" "$WATCH_RUNTIME")
        xcrun simctl pair "$WATCH_UDID" "$PHONE_UDID"
        CREATED_WATCH=1
    fi
fi

xcrun simctl boot "$PHONE_UDID" >/dev/null 2>&1 || true
xcrun simctl bootstatus "$PHONE_UDID" -b
if test -n "$WATCH_UDID"; then
    xcrun simctl boot "$WATCH_UDID" >/dev/null 2>&1 || true
    xcrun simctl bootstatus "$WATCH_UDID" -b
fi
if test "$INTERACTIVE_SIMULATOR" -eq 1; then
    open -a Simulator --args -CurrentDeviceUDID "$PHONE_UDID"
    echo "Approve each 'Open in KORemote' pairing-link prompt in the temporary simulator"
fi

python3 "$SCRIPT_DIR/mock-koreader-server.py" \
    --port "$MOCK_PORT" \
    --secret "$SECRET" \
    --events "$EVENTS_FILE" >"$MOCK_LOG" 2>&1 &
SERVER_PID=$!

server_ready=0
attempt=0
while test "$attempt" -lt 50; do
    if curl --silent --fail --max-time 1 --noproxy '*' "http://127.0.0.1:$MOCK_PORT/" >/dev/null 2>&1; then
        server_ready=1
        break
    fi
    attempt=$((attempt + 1))
    sleep 0.1
done
if test "$server_ready" -ne 1; then
    cat "$MOCK_LOG"
    exit 1
fi
if ! kill -0 "$SERVER_PID" >/dev/null 2>&1; then
    echo "Mock server exited before the smoke test started" >&2
    cat "$MOCK_LOG"
    exit 1
fi

build_scheme() {
    scheme=$1
    log="$SMOKE_DIR/$scheme-build.log"
    derived_data="$SMOKE_DIR/$scheme-derived-data"

    echo "Building $scheme for simulator launch"
    if ! xcodebuild \
        -project "$REPO_DIR/KOReaderiOSRemote.xcodeproj" \
        -scheme "$scheme" \
        -configuration Debug \
        -destination "platform=iOS Simulator,id=$PHONE_UDID" \
        -derivedDataPath "$derived_data" \
        build >"$log" 2>&1; then
        tail -n 100 "$log"
        return 1
    fi
}

launch_and_pair() {
    scheme=$1
    product=$2
    bundle_id=$3
    should_pair=$4
    watch_product=${5:-}
    watch_bundle_id=${6:-}
    app_path="$SMOKE_DIR/$scheme-derived-data/Build/Products/Debug-iphonesimulator/$product.app"

    test -d "$app_path"
    xcrun simctl install "$PHONE_UDID" "$app_path"
    xcrun simctl launch --terminate-running-process "$PHONE_UDID" "$bundle_id"
    sleep 1

    if ! xcrun simctl terminate "$PHONE_UDID" "$bundle_id" >/dev/null 2>&1; then
        echo "$scheme did not remain running after launch" >&2
        exit 1
    fi
    xcrun simctl launch "$PHONE_UDID" "$bundle_id"

    if test "$should_pair" = yes; then
        before=$(wc -l <"$EVENTS_FILE" | tr -d ' ')
        pairing_url="koreaderturner://pair?v=1&host=127.0.0.1&port=$MOCK_PORT&name=Mock%20KOReader&secret=$SECRET"
        if test "$INTERACTIVE_SIMULATOR" -eq 1; then
            xcrun simctl openurl "$PHONE_UDID" "$pairing_url"
        else
            xcrun simctl terminate "$PHONE_UDID" "$bundle_id" >/dev/null 2>&1 || true
            SIMCTL_CHILD_KOREMOTE_SIMULATOR_PAIRING_URL="$pairing_url" \
                xcrun simctl launch "$PHONE_UDID" "$bundle_id"
        fi

        paired=0
        attempt=0
        while test "$attempt" -lt "$PAIR_ATTEMPTS"; do
            after=$(wc -l <"$EVENTS_FILE" | tr -d ' ')
            if test "$after" -gt "$before"; then
                paired=1
                break
            fi
            attempt=$((attempt + 1))
            sleep 0.1
        done
        if test "$paired" -ne 1; then
            echo "$scheme launched but did not ping the authenticated mock KOReader" >&2
            cat "$MOCK_LOG"
            exit 1
        fi
        tail -n 1 "$EVENTS_FILE" | grep -q '"path": "/v1/ping"'
    fi

    if test "$should_pair" = yes; then
        for volume_action in next previous; do
            action_start=$(wc -l <"$EVENTS_FILE" | tr -d ' ')
            xcrun simctl terminate "$PHONE_UDID" "$bundle_id" >/dev/null 2>&1 || true
            SIMCTL_CHILD_KOREMOTE_SIMULATOR_VOLUME_ACTION="$volume_action" \
                xcrun simctl launch "$PHONE_UDID" "$bundle_id"

            action_sent=0
            attempt=0
            while test "$attempt" -lt 100; do
                new_events=$(tail -n "+$((action_start + 1))" "$EVENTS_FILE")
                if printf '%s\n' "$new_events" | grep -q "\"action\": \"$volume_action\""; then
                    action_sent=1
                    break
                fi
                attempt=$((attempt + 1))
                sleep 0.1
            done
            if test "$action_sent" -ne 1; then
                echo "$scheme did not send the simulated $volume_action volume action" >&2
                exit 1
            fi
        done
        echo "$scheme simulator volume-action bridge passed"
    fi

    if test -n "$WATCH_UDID" && test -n "$watch_product"; then
        watch_app_path="$app_path/Watch/$watch_product.app"
        test -d "$watch_app_path"
        xcrun simctl install "$WATCH_UDID" "$watch_app_path"

        # Activate both WCSession peers after the companion exists. The phone then
        # republishes its persisted pairing as application context for the Watch.
        xcrun simctl launch --terminate-running-process "$WATCH_UDID" "$watch_bundle_id"
        xcrun simctl launch --terminate-running-process "$PHONE_UDID" "$bundle_id"
        sleep 3

        watch_action_start=$(wc -l <"$EVENTS_FILE" | tr -d ' ')
        SIMCTL_CHILD_KOREMOTE_SIMULATOR_WATCH_ACTION=next \
            SIMCTL_CHILD_KOREMOTE_SIMULATOR_WATCH_PAIRING_URL="$pairing_url" \
            xcrun simctl launch --terminate-running-process "$WATCH_UDID" "$watch_bundle_id"

        watch_action_sent=0
        attempt=0
        while test "$attempt" -lt "$WATCH_ACTION_ATTEMPTS"; do
            new_events=$(tail -n "+$((watch_action_start + 1))" "$EVENTS_FILE")
            if printf '%s\n' "$new_events" | grep -q '"action": "next"'; then
                watch_action_sent=1
                break
            fi
            attempt=$((attempt + 1))
            sleep 0.1
        done
        if test "$watch_action_sent" -ne 1; then
            echo "$watch_product did not send its authenticated simulator action" >&2
            exit 1
        fi
        if ! xcrun simctl terminate "$WATCH_UDID" "$watch_bundle_id" >/dev/null 2>&1; then
            echo "$watch_product did not remain running after launch" >&2
            exit 1
        fi
        xcrun simctl launch "$WATCH_UDID" "$watch_bundle_id"
        xcrun simctl terminate "$WATCH_UDID" "$watch_bundle_id" >/dev/null 2>&1 || true
        xcrun simctl uninstall "$WATCH_UDID" "$watch_bundle_id"
        echo "$watch_product authenticated-action smoke passed"
    fi

    xcrun simctl terminate "$PHONE_UDID" "$bundle_id" >/dev/null 2>&1 || true
    xcrun simctl uninstall "$PHONE_UDID" "$bundle_id"
    echo "$scheme launch smoke passed"
}

if test -z "$SMOKE_ONLY_SCHEME" || test "$SMOKE_ONLY_SCHEME" = KORemoteFull; then
    build_scheme KORemoteFull
    launch_and_pair KORemoteFull KORemote com.maxoliinyk.koreaderremote yes KORemoteWatch com.maxoliinyk.koreaderremote.watch
fi

if test -z "$SMOKE_ONLY_SCHEME" || test "$SMOKE_ONLY_SCHEME" = KORemoteFree; then
    build_scheme KORemoteFree
    launch_and_pair KORemoteFree KORemoteFree com.maxoliinyk.koreaderremote.free yes
fi

if test -z "$SMOKE_ONLY_SCHEME" || test "$SMOKE_ONLY_SCHEME" = KORemoteFreeWatch; then
    build_scheme KORemoteFreeWatch
    launch_and_pair KORemoteFreeWatch KORemoteFreeWatch com.maxoliinyk.koreaderremote.freewatch yes KORemoteWatchFree com.maxoliinyk.koreaderremote.freewatch.watch
fi

if test -z "$SMOKE_ONLY_SCHEME" || test "$SMOKE_ONLY_SCHEME" = KORemoteAltStore; then
    build_scheme KORemoteAltStore
    launch_and_pair KORemoteAltStore KORemoteAltStore com.maxoliinyk.koreaderremote.altstore yes
fi

if test -z "$SMOKE_ONLY_SCHEME" || test "$SMOKE_ONLY_SCHEME" = KORemoteLabs; then
    build_scheme KORemoteLabs
    launch_and_pair KORemoteLabs KORemoteLabs com.maxoliinyk.koreaderremote.labs no
fi

if test -z "$SMOKE_ONLY_SCHEME"; then
    echo "All iOS Simulator products launched; every distributed app authenticated against the mock KOReader"
else
    echo "$SMOKE_ONLY_SCHEME focused simulator smoke passed"
fi
if test -z "$WATCH_UDID"; then
    echo "Watch launch skipped: no watchOS Simulator runtime is installed; generic watchOS Simulator builds remain covered by check-distributions.sh"
else
    echo "Both full and entitlement-free Watch products launched on watchOS Simulator"
fi
