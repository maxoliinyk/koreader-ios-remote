# Distribution configurations

The four normal app products build the same app sources. Full bundles Controls and Watch; the other products remove shared capabilities or embedded products to simplify provisioning. Labs is a separate research app. The README contains the [compact feature comparison](README.md#choose-a-build).

Do not add Labs files, private APIs, App Group entitlements, or shared-Keychain entitlements to the app-only sideload targets. Background audio and public volume/media capture are available in every normal app product.

## Target matrix

### `KORemoteFull`

- Target: `KORemote`
- Audience: full-feature development and device testing
- Signing assumption: a team that can provision the configured App Groups and shared Keychain access
- Includes: iPhone/iPad app, Control Center extension, Apple Watch app, App Intents, App Groups, shared Keychain
- Volume buttons: public `AVAudioSession.outputVolume` observation with opt-in background audio for locked-screen capture
- Media controls: opt-in Now Playing Previous/Next
- Locked alternatives: Controls, Action Button, Shortcuts, Siri, Apple Watch
- Excludes: Labs, private volume events, private MediaRemote calls

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
make ipa-altstore VERSION=0.5
```

The resulting `dist/KORemoteAltStore-0.5-unsigned.ipa` is not installable by itself. Install [AltStore Classic](https://faq.altstore.io/altstore-classic/your-altstore) first. Save the IPA in Files, then use **My Apps → +** and select it. Follow the official setup for AltStore/AltServer, use your own Apple Account, refresh the app before expiry, and keep app/App-ID slots available. See the official [App ID limits](https://faq.altstore.io/altstore-classic/app-ids). Apple Watch installation is not documented by AltStore Classic, so it is intentionally absent from this IPA.

Tagged GitHub releases package the plugin, build the unsigned IPA, and publish `SHA256SUMS`. The manual **Build AltStore Classic IPA** workflow also provides an Actions artifact and checksum for testing before a release. A GitHub runner cannot create a transferable Personal Team signature.

### `KORemoteLabs`

- Audience: local research and sideload testing only
- Includes: raw/private volume event experiments, private MediaRemote probes, background audio experiments
- Never include in: public or externally reviewed builds

Labs intentionally retains techniques that can break on any iOS update and can cause rejection. Sideloading does not bypass the sandbox, entitlement enforcement, suspension, or private-API instability.

## Scheme names and build behavior

- `KORemote` and `KORemoteFull` select the same `KORemote` target and bundle identifier. They do not have different feature sets.
- `KORemoteControls` builds the Controls extension and uses the full app as its launch host. It is not an independently installable remote app.
- `KORemoteWatch` launches the full Watch target; `KORemoteWatchFree` launches the entitlement-free Watch target. Their iPhone companion schemes are `KORemoteFull` and `KORemoteFreeWatch` respectively.
- All schemes run Debug and archive Release. Debug adds simulator test hooks where supported; Debug Watch builds also expose Gesture Lab. Those experiments are excluded from Release.
- `KORemoteLabs` launches its own research interface. It has no normal pairing screen and reads the pairing shared by Full; pairing only in Free or AltStore does not populate Labs.

The compile flags describe the bundle contents: Full defines `KOREMOTE_FULL`, `KOREMOTE_HAS_CONTROLS`, and `KOREMOTE_HAS_WATCH`; Free defines `KOREMOTE_FREE`; FreeWatch adds `KOREMOTE_HAS_WATCH`; AltStore defines `KOREMOTE_ALTSTORE`. Free and AltStore currently have the same app features, with different product names, bundle identifiers, and packaging routes. There is no AltStore account check in the app.

On iPhone, Full and Controls share endpoint metadata through an App Group and the pairing secret through shared Keychain. **Phone-to-Watch pairing always uses WatchConnectivity**, including in Full. The Full Watch target currently requests its own App Group and Keychain group; FreeWatch omits those entitlements and uses local storage without removing the Watch page controls or Double Tap action.

## Third-party signing

**Full is technically possible with third-party signing, but compatibility is conditional and has not been verified with Signulous or another provider.** A certificate proves who signed a binary; its provisioning profile determines which app identifiers, devices, and entitlements are authorized. Paying a provider for signing does not automatically give the customer access to manage that provider's developer team. Apple's [registered-device distribution guide](https://developer.apple.com/documentation/xcode/distributing-your-app-to-registered-devices) describes the certificate, profile, and device requirements.

### App-only installation

The existing unsigned `KORemoteAltStore` IPA is the simplest candidate for a compatible IPA-signing service. The name identifies our packaging route; AltStore itself is not required at runtime. [Signulous advertises custom IPA uploads](https://www.signulous.com/), but this project has not tested its signing or installation flow. Use the provider's own upload/install instructions.

This build keeps QR/manual pairing, Next/Previous/Sleep, opt-in locked-screen volume/media capture, Siri, and Shortcuts. It omits the Controls extension, Watch, and shared capabilities. Normal app-local Keychain storage remains enabled. Paying for a certificate does not add the omitted bundles back into this IPA.

### What Full needs

For every included bundle, the provider must supply an appropriate profile and correctly sign the nested products:

1. **iPhone app**: an authorized app identifier and the user's registered iPhone for ad hoc distribution.
2. **Controls extension**: extension signing plus the same authorized App Group and shared Keychain group used by the iPhone app.
3. **Watch app**: watchOS signing and installation support, a correctly linked companion identifier, and the Watch's registration/profile where required. An iPhone-only signing slot is not enough to establish this support.
4. **Consistent identifiers**: the values used by the app, extension, profiles, and signed entitlements must agree. Simply changing a certificate or stripping entitlements is insufficient.

In this project's code, the App Group identifier is in `ProtocolConstants.appGroup` and the entitlements files. The full app, Controls, and full Watch Info.plists also contain `KOReaderKeychainAccessGroup`; its `AppIdentifierPrefix` is expanded at build time. Signing under another team may require rebuilding with that team's authorized group identifiers and updating these values consistently. An external signer must not leave the previous keychain prefix behind.

Removing App Groups can leave the app using local settings while Controls has no shared pairing. Leaving an unauthorized Keychain group can cause Keychain error `-34018`. Therefore, an IPA appearing on the Home Screen does not prove that pairing, Controls, or Watch works. These consequences follow from the current storage code; they are not results from a provider test.

Apple documents [App Group registration](https://developer.apple.com/help/account/identifiers/register-an-app-group) and [Keychain sharing](https://developer.apple.com/documentation/xcode/configuring-keychain-sharing). A provider's general claim to support entitlements does not confirm this exact combination of bundles and identifiers.

### What determines expiry

A scheme does not enforce a subscription or a seven-day timer. Free Personal Team profiles normally expire after seven days; paid-account or provider installs follow the validity of their actual certificate/profile and can stop working if signing is revoked. A provider's purchase term is not proof that a particular installed signature remains valid for that whole term. Switching signing teams, product identifiers, or installation routes may also require pairing again.

Full is currently documented as a source/Xcode route. The automated release workflow produces the app-only IPA and plugin ZIP; it does not produce a Full IPA or a separate Watch IPA. Providing a Full download would require another packaging path and validation with the intended signer's profiles. No change of scheme alone establishes third-party compatibility.

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

## Downloads and updates

The release page labels the three downloads **iOS IPA — AltStore Classic**, **KOReader Plugin**, and **SHA-256 Checksums**. Apple Watch installation uses Xcode; there is no standalone Watch IPA. GitHub adds the two source archives automatically.

Release assets live on the [Releases page](https://github.com/maxoliinyk/koreader-ios-remote/releases). The plugin ZIP and IPA are separate downloads. GitHub's automatically generated source ZIP is a source checkout, not an installable iPhone app.

To check a download on macOS, put it beside `SHA256SUMS` and compare its digest:

```bash
shasum -a 256 remote_turner-*.koplugin.zip
shasum -a 256 KORemoteAltStore-*-unsigned.ipa
```

Use the corresponding line in `SHA256SUMS`. On Linux, use `sha256sum`. A matching checksum verifies the download matches the release asset; it is not a signing certificate.

For app updates, install over the existing app using the same route, Apple Account/team, and bundle identifier. Deleting the app or switching distribution products may require pairing again. Source users pull the new code and run from Xcode again; AltStore users import the new IPA and continue refreshing it.

## Creating a release

1. Update every target's `MARKETING_VERSION` and the plugin's `_meta.lua` version together. Keep protocol version 1 unless the wire format changes.
2. Run `make test-plugin`, `luacheck remote_turner.koplugin/ tests/`, and `make check-distributions`.
3. Verify plugin installation, pairing, next/previous/sleep, and wake/reconnect on a real KOReader device. Verify the intended signing route and hardware controls on an iPhone; include a real Watch for Watch releases.
4. Push a matching `vX.Y` or `vX.Y.Z` tag when ready to publish (currently `v0.5`). The **Release** workflow validates matching versions, runs protocol tests, builds both downloads, and attaches checksums. It uploads the labeled assets to a draft, then publishes only after every upload succeeds; Labs is excluded from the IPA. An interrupted draft can be retried, while published assets are never replaced by this workflow.
5. Review the generated release notes and record the device/OS/KOReader versions actually tested. Label untested routes clearly.

For the current version, run these commands only when you want to publish:

```bash
git push origin main
git tag v0.5
git push origin v0.5
```

`git tag v0.5` labels the current commit locally; pushing that tag starts the release workflow. Pushing `main` by itself does not publish a release. Follow progress under **Actions → Release**; the finished downloads appear under **Releases**. The Xcode version is `0.5`, without the `v` prefix. For the next release, update the versions together, commit them, and use a new matching tag such as `v0.5.1`.


No signing certificate or Apple Account credential belongs in the repository or release assets. The IPA is intentionally unsigned; each user signs their own copy.

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

Simulator's own Volume Up/Down toolbar controls did not produce observable `AVAudioSession.outputVolume` changes in the tested iOS 26.5 runtime. Consequently, the system-KVO boundary and locked-screen behavior remain physical-device-only tests. Debug simulator builds expose **Settings → Simulator Tools** buttons for manual end-to-end checks of everything after that boundary.

## Current capability boundary

The full configuration is the only configuration here with cross-process pairing storage for the Controls extension. Both Watch configurations receive pairing through WatchConnectivity. Personal Team and AltStore builds keep page buttons, pairing, local networking, App Intents, public volume observation, volume recentering, and opt-in background audio, as does the full build. They give up Controls, shared storage, and—for the reliable routes—the Watch companion.
