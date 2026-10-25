# Distribution configurations

For installation steps and a feature comparison, start with the [README](README.md#run-the-app). This document covers signing, packaging, and release maintenance.

## Contents

- [Target matrix](#target-matrix)
- [Scheme names and build behavior](#scheme-names-and-build-behavior)
- [Personal Team install](#personal-team-install)
- [Third-party signing](#third-party-signing)
- [Downloads and updates](#downloads-and-updates)
- [Build an IPA](#build-an-ipa)
- [Creating a release](#creating-a-release)
- [Bundle identifiers](#bundle-identifiers)
- [Simulator setup](#simulator-setup)
- [Automated verification](#automated-verification)

## Target matrix

All four normal products share app sources and support pairing, page actions, Siri/Shortcuts, and opt-in volume/media controls. Their packaging and signing differ:

- **KORemoteFull**: builds the `KORemote` target with Controls and Watch. Requires provisioning for all three bundles, App Groups, and shared Keychain.
- **KORemoteFree**: app-only Personal Team build. Uses app-local UserDefaults and Keychain; no Controls, Watch, or shared capabilities.
- **KORemoteFreeWatch**: Free plus `KORemoteWatchFree`. Pairing uses WatchConnectivity without shared capabilities. Free-team installation on a physical iPhone/Watch pair remains unverified; use Free if provisioning fails.
- **KORemoteAltStore**: app-only unsigned IPA with the same app features as Free, for re-signing through AltStore Classic or a compatible service.

Keep Labs code, private APIs, and shared-capability entitlements out of the app-only targets. The separate [Labs app](LABS.md) is for local research and is excluded from public release downloads.

## Scheme names and build behavior

- `KORemote` is an alias for `KORemoteFull`; both select the same target.
- `KORemoteControls` launches its extension through the full app.
- `KORemoteWatch` and `KORemoteWatchFree` launch the companions for Full and FreeWatch, respectively.
- All schemes run Debug and archive Release. Debug builds include simulator hooks; Debug Watch builds also expose Gesture Lab.
- `KORemoteLabs` reads pairing shared by Full. It has no normal pairing screen; pairing in Free or AltStore does not populate Labs.

Compile flags: Full uses `KOREMOTE_FULL`, `KOREMOTE_HAS_CONTROLS`, and `KOREMOTE_HAS_WATCH`; Free uses `KOREMOTE_FREE`; FreeWatch adds `KOREMOTE_HAS_WATCH`; AltStore uses `KOREMOTE_ALTSTORE`.

Full shares endpoint metadata with Controls through an App Group and the secret through shared Keychain. Both Watch configurations receive pairing through WatchConnectivity. Full Watch requests its own App Group and Keychain group; FreeWatch uses local storage.

## Personal Team install

Follow the README's [source installation steps](README.md#install-from-source). Choose your own Personal Team; no development team is committed for Free. Change the bundle identifier if Xcode reports it is unavailable.

For FreeWatch, choose the same team for both targets. If you change either bundle identifier, also update the Watch companion identifier to match:

```text
iPhone: com.maxoliinyk.koreaderremote.freewatch
Watch:  com.maxoliinyk.koreaderremote.freewatch.watch
```

Keep the sideload targets free of shared-Keychain and App Group entitlements. Adding Full's capabilities can prevent Personal Team provisioning or cause Keychain error `-34018`.

Free Personal Team profiles normally expire after seven days; reconnect and run from Xcode to re-sign. Other installation routes follow their certificate/profile validity and may stop working if signing is revoked.

## Third-party signing

Use the unsigned `KORemoteAltStore` IPA with a service that supports custom IPA uploads. Follow that provider's installation instructions. AltStore is not required at runtime; provider compatibility, including Signulous, has not been tested.

Full requires the provider to support:

1. Signing the iPhone app and its nested Controls and Watch bundles, with device registration where required.
2. Authorized App Groups and shared Keychain access for the relevant bundles.
3. Matching app, companion, profile, and entitlement identifiers.

Buying a certificate alone does not establish this support. Releases contain the app-only IPA and plugin ZIP; there is no Full or standalone Watch IPA.

When adapting Full to another team, update `ProtocolConstants.appGroup`, entitlements, and the `KOReaderKeychainAccessGroup` Info.plist values consistently. The Keychain prefix expands from `AppIdentifierPrefix`; do not retain another team's prefix. Removing App Groups can break Controls pairing; an unauthorized Keychain group can cause error `-34018`.

Apple references: [registered-device distribution](https://developer.apple.com/documentation/xcode/distributing-your-app-to-registered-devices), [App Groups](https://developer.apple.com/help/account/identifiers/register-an-app-group), [Keychain sharing](https://developer.apple.com/documentation/xcode/configuring-keychain-sharing).

## Downloads and updates

[Releases](https://github.com/maxoliinyk/koreader-ios-remote/releases) contain the plugin ZIP, unsigned iPhone IPA, and `SHA256SUMS`. GitHub's automatic source archives are not installable iPhone apps. Watch installation uses Xcode.

To verify a download on macOS, compare its digest with the corresponding line in `SHA256SUMS`:

```bash
shasum -a 256 remote_turner-*.koplugin.zip
shasum -a 256 KORemoteAltStore-*-unsigned.ipa
```

On Linux, use `sha256sum`.

For updates, install over the existing app using the same Apple Account/team and bundle identifier. Source users pull the code and run from Xcode; AltStore users import the new IPA and keep refreshing it. Deleting the app or changing signing teams, products, or installation routes may require pairing again.

## Build an IPA

From a checkout, substitute the version you are packaging:

```bash
make ipa-altstore VERSION=0.6.1
```

Output: `dist/KORemoteAltStore-0.6.1-unsigned.ipa`. Sign it before installation; see the [AltStore instructions](README.md#install-an-ipa-with-altstore-classic). Keep app/App-ID slots available; see [AltStore's App ID limits](https://faq.altstore.io/altstore-classic/app-ids).

The **Build AltStore Classic IPA** workflow also produces an Actions artifact and checksum for pre-release testing. GitHub runners do not provide a transferable Personal Team signature. Keep signing credentials out of the repository and release assets.

## Creating a release

1. Update every target's `MARKETING_VERSION` and the plugin's `_meta.lua` version together. Change protocol version 1 only if the wire format changes.
2. Add `release-notes/<version>.md` with user-facing changes and the device/OS/KOReader versions tested. Label untested routes. A nonempty notes file matching the tag is required; keep older notes as history.
3. Run `make test-plugin`, `luacheck remote_turner.koplugin/ tests/`, and `make check-distributions`.
4. Test plugin installation, pairing, page actions, sleep, and wake/reconnect on real hardware. Check the intended signing route and iPhone controls; include a Watch for Watch releases.
5. Commit the release changes, push the branch, then push a matching `vX.Y` or `vX.Y.Z` tag. For example, for version `0.6.1`:

```bash
git push origin main
git tag v0.6.1
git push origin v0.6.1
```

Pushing the tag starts **Actions → Release**; pushing `main` alone does not. Push tags individually rather than using `git push --tags`.

The workflow validates versions, runs protocol tests, and builds the IPA, plugin ZIP, and checksums. It uploads to a draft and publishes only after all uploads succeed. Interrupted drafts can be retried; published assets are never replaced.

Release notes appear above the download/setup instructions. Review them in `dist/RELEASE_NOTES.md` when publishing locally, or on the finished GitHub release.

If a tag exists but its workflow did not start, use **Actions → Release → Run workflow**, select `main`, and enter the tag. Or run:

```bash
gh workflow run release.yml --ref main -f tag=v0.6.1
```

The recovery workflow must exist on `main`; all build/publishing jobs check out the supplied tag. Retrying a draft refreshes its release notes.

## Bundle identifiers

The project uses one reverse-domain identifier family:

- App: `com.maxoliinyk.koreaderremote`
- Controls: `com.maxoliinyk.koreaderremote.controls`
- Watch: `com.maxoliinyk.koreaderremote.watch`
- Labs: `com.maxoliinyk.koreaderremote.labs`
- Personal Team app: `com.maxoliinyk.koreaderremote.free`
- Personal Team + Watch app: `com.maxoliinyk.koreaderremote.freewatch`
- Entitlement-free Watch: `com.maxoliinyk.koreaderremote.freewatch.watch`
- AltStore Classic app: `com.maxoliinyk.koreaderremote.altstore`
- Shared App Group: `group.com.maxoliinyk.koreaderremote`

These identifiers intentionally remain stable across the KORemote rename, preserving pairing data and existing system controls for current users.

## Simulator setup

1. Open `KOReaderiOSRemote.xcodeproj` in Xcode 26 or later.
2. Select your app scheme and an iPhone simulator running iOS 26 or later, then press **Run**.
3. Tap **Pair KOReader**, switch to **Manual**, and enter the values shown by **Tools → Remote Turner → Show manual pairing details**. The simulator cannot scan a pairing QR code.

Let Xcode sign the simulator build normally. `CODE_SIGNING_ALLOWED=NO` is only for compile checks; an unsigned simulator build cannot save the pairing secret to Keychain.

If Xcode has an old paused process, stop it and run your selected app scheme again rather than using the SwiftUI Preview button. If needed, remove the app and reinstall; this may require pairing again.

## Automated verification

```bash
make check-distributions
```

Runs RemoteCore tests and the compile/structure matrix for Full, Free, FreeWatch, AltStore, Labs, and Watch targets. Checks embedded products, sideload sharing configuration, and absence of private volume hooks from distributed app sources.

For a launch and authenticated-network pass against a local mock server:

```bash
make smoke-simulator
```

Creates and deletes isolated temporary iPhone and available Watch simulators. It checks pairing, authenticated ping/page actions, and injected volume-button mappings. Approve **Open in KORemote** prompts to exercise deep-link handoff. For unattended iPhone CI:

```bash
INTERACTIVE_SIMULATOR=0 SKIP_WATCH=1 make smoke-simulator
```

Existing simulators are untouched unless you explicitly set `SIMULATOR_UDID` or `WATCH_SIMULATOR_UDID`. Watch launches require an installed watchOS runtime; compilation only needs the SDK.

Simulator checks use debug injection where system behavior is unavailable, including Watch pairing fallback and volume-button input. **Settings → Simulator Tools** exposes manual debug checks. Real volume events, locked-screen operation, signing/expiry, WatchConnectivity transfer/relay, and actual KOReader connectivity require physical-device testing.
