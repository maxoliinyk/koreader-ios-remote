# Distribution configurations

The project deliberately builds the same app sources into separate products. Do not add Labs files, private APIs, App Group entitlements, or shared-Keychain entitlements to a sideload target.

## Target matrix

### `KORemoteFull`

- Target: `KORemote`
- Audience: full-feature development and device testing
- Signing assumption: a team that can provision the configured App Groups and shared Keychain access
- Includes: iPhone/iPad app, Control Center extension, Apple Watch app, App Intents, App Groups, shared Keychain
- Volume buttons: public `AVAudioSession.outputVolume` observation while the app is foregrounded
- Locked alternatives: Controls, Action Button, Shortcuts, Siri, Apple Watch
- Excludes: background keep-alive audio, Labs, private volume events, private MediaRemote calls

This name describes the included feature set only. It does not claim successful physical-device provisioning, external review, or suitability for any release channel. Those remain separate validation tasks.

### `KORemoteFree`

- Audience: reliable Personal Team/Xcode install
- Requires: a Mac, Xcode, and the user's free Apple Account
- Includes: app, App Intents, QR/manual pairing, local networking, foreground and locked-screen volume mode, media controls
- Excludes: Controls extension, Watch, App Groups, shared Keychain
- Storage: app-local UserDefaults and Keychain
- Expiry: Personal Team provisioning normally requires reinstalling/re-signing after seven days

The source has no committed development team for this target. Each user selects their own Personal Team and may need to replace `com.maxoliinyk.koreaderremote.free` with a unique bundle identifier.

### `KORemoteFreeWatch`

- Audience: experimental Personal Team/Xcode install
- Includes: the same entitlement-free iPhone app plus `KORemoteWatchFree`
- Pairing transfer: WatchConnectivity; no App Group or shared Keychain
- Risk: simulator compilation cannot prove that a Personal Team will provision and install both bundles on a real iPhone/Watch pair

Use `KORemoteFree` if Watch provisioning fails. Treat the Watch configuration as experimental until it passes a physical iPhone + Apple Watch test using a genuinely free Personal Team.

### `KORemoteAltStore`

- Audience: AltStore Classic worldwide sideloading
- Includes: app-only build with the sideload volume/media behavior
- Excludes: Watch, Controls, App Groups, shared Keychain, Labs
- Artifact: unsigned IPA-shaped archive; AltStore re-signs it with each user's Apple Account

Build it with:

```bash
make ipa-altstore VERSION=2.0.0
```

The resulting `dist/KORemoteAltStore-2.0.0-unsigned.ipa` is not installable by itself. In AltStore Classic, use **My Apps → +** and select the IPA. The user still needs AltStore/AltServer, their own Apple Account, periodic refreshes, and available app/App-ID slots. Apple Watch installation is not documented by AltStore Classic, so it is intentionally absent from this IPA.

The manual GitHub workflow **Build AltStore Classic IPA** builds the same unsigned artifact and publishes a SHA-256 checksum. A GitHub runner cannot create a transferable Personal Team signature.

### `KORemoteLabs`

- Audience: local research and sideload testing only
- Includes: raw/private volume event experiments, private MediaRemote probes, background audio experiments
- Never include in: public or externally reviewed builds

Labs intentionally retains techniques that can break on any iOS update and can cause rejection. Sideloading does not bypass the sandbox, entitlement enforcement, suspension, or private-API instability.

## Personal Team install

1. Open `KOReaderiOSRemote.xcodeproj` in Xcode 26 or later.
2. Sign in under **Xcode → Settings → Accounts**.
3. Select `KORemoteFree` first. Select `KORemoteFreeWatch` only for the Watch experiment.
4. Select the app target under **Signing & Capabilities**, choose the user's Personal Team, and change the bundle identifier if Xcode says it is unavailable.
5. Connect and trust the iPhone, enable Developer Mode, then press **Run**.
6. Re-run from Xcode when the Personal Team provisioning expires.

There is no shared-Keychain access-group key in the sideload Info.plist and no sideload entitlements file. This is intentional. Adding the full configuration's entitlements back makes free signing unreliable and can cause Keychain error `-34018`.

For `KORemoteFreeWatch`, select the same Personal Team for both targets and keep the companion bundle identifiers matched:

```text
iPhone: com.maxoliinyk.koreaderremote.freewatch
Watch:  com.maxoliinyk.koreaderremote.freewatch.watch
```

If either identifier is changed, update the Watch companion identifier too.

## Automated verification

Run the whole compile and structure matrix:

```bash
make check-distributions
```

It runs RemoteCore tests plus unsigned Debug simulator and Release device builds for:

- Full on iOS Simulator, including Watch and Controls dependencies;
- app-only Personal Team on iOS Simulator;
- Personal Team + Watch on iOS Simulator;
- AltStore on iOS Simulator;
- Labs on iOS Simulator;
- entitlement-free Watch on watchOS Simulator.

It also verifies the expected embedded products, absence of shared-Keychain configuration in sideload products, and absence of private volume hooks from the distributed App source group.

The simulator cannot validate physical volume-button delivery, locked-screen survival, Personal Team provisioning/expiry, AltStore re-signing, real WatchConnectivity, or communication with a real KOReader device. Those require physical-device test passes.

For a full launch and authenticated-network smoke pass without a KOReader device:

```bash
make smoke-simulator
```

This creates isolated temporary iPhone and (when the runtime is installed) Watch simulators, launches every product, pairs each distributed iPhone app with the local authenticated mock server, confirms a correctly signed `/v1/ping`, and deletes the temporary devices. By default, approve each system **Open in KORemote** prompt while the script runs; this exercises the actual deep-link handoff. `INTERACTIVE_SIMULATOR=0 SKIP_WATCH=1 make smoke-simulator` uses a debug-only pairing injection for unattended iPhone CI. It never changes an existing simulator unless `SIMULATOR_UDID` or `WATCH_SIMULATOR_UDID` is explicitly supplied. A watchOS runtime must be installed before Watch apps can be launched; the compile matrix works with the watch simulator SDK alone.

The launch pass also restarts each distributable app through a debug-only simulator bridge that injects Volume Up (`next`) and Volume Down (`previous`) after pairing. The mock must receive and authenticate both actions. This covers storage, action mapping, request construction, HMAC, and response handling without adding a hook to device builds.

Both Watch products also run an authenticated `next` action. The harness first gives WatchConnectivity a chance to transfer the iPhone pairing, then uses a debug-simulator-only copy of the same mock pairing when Simulator does not deliver application context. This validates the Watch store/client/network path, but not real pairing transfer, reachability relay, or free-team provisioning.

Simulator's own Volume Up/Down toolbar controls did not produce observable `AVAudioSession.outputVolume` changes in the tested iOS 26.5 runtime. Consequently, the system-KVO boundary and locked-screen behavior remain physical-device-only tests. Debug simulator builds expose **Settings → System Controls → Simulator Volume Test** buttons for manual end-to-end checks of everything after that boundary.

## Current capability boundary

The full configuration is the only configuration here with cross-process state for Control Center and the original Watch app. Personal Team and AltStore builds keep page buttons, pairing, local networking, App Intents, public volume observation, volume recentering, and sideload background audio. They give up Controls, shared storage, and—for the reliable routes—the Watch companion.
