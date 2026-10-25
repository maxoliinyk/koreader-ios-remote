# KOReader iOS Remote

A native iPhone and Apple Watch remote for KOReader. It sends authenticated page actions directly over your local Wi-Fi network. There is no cloud service or account.

The plugin is developed and tested on a jailbroken Kindle. Other KOReader devices should work if they support external plugins, can accept an inbound TCP connection, and expose the same KOReader page and suspend events. Automatic firewall configuration is currently Kindle-specific.

## Contents

- [Requirements](#requirements)
- [Install the KOReader plugin](#install-the-koreader-plugin)
- [Run the app](#run-the-app)
  - [Choose a build](#choose-a-build)
  - [Third-party certificates and signing services](#third-party-certificates-and-signing-services)
  - [Install an IPA with AltStore Classic](#install-an-ipa-with-altstore-classic)
  - [Install from source](#install-from-source)
  - [Simulator](#simulator)
  - [Physical iPhone](#physical-iphone)
- [Pair and use it](#pair-and-use-it)
- [Use it while the iPhone is locked](#use-it-while-the-iphone-is-locked)
- [Apple Watch](#apple-watch)
- [Bundle identifiers](#bundle-identifiers)
- [Troubleshooting](#troubleshooting)
- [Development checks](#development-checks)
- [License](#license)

## Requirements

- A network-connected device running KOReader
- An iPhone running iOS 26 or later
- For source installation: a Mac with Xcode 26 or later
- Both devices on the same Wi-Fi network

The simulator is useful for interface testing but cannot scan a pairing QR code. Use manual pairing there.

## Install the KOReader plugin

Open [Releases](https://github.com/maxoliinyk/koreader-ios-remote/releases) and download `remote_turner-<version>.koplugin.zip` from **Assets**. This is the plugin download; the IPA is the iPhone app. No Xcode is needed to install the plugin.

If no release is available yet, use GitHub's **Code → Download ZIP**, extract it, and copy the `remote_turner.koplugin` folder from inside the source archive. Or build the plugin archive from a checkout:

```bash
make koplugin VERSION=dev
```

This creates `dist/remote_turner-dev.koplugin.zip`. Extract it and copy the enclosed `remote_turner.koplugin` directory into KOReader's `plugins` directory. A common installation looks like this:

```text
koreader/
└── plugins/
    └── remote_turner.koplugin/
        ├── _meta.lua
        ├── httpserver.lua
        └── main.lua
```

Do not leave an extra directory level around `remote_turner.koplugin`. Restart KOReader completely after copying the plugin. The exact KOReader directory depends on the device; `koreader/plugins/` is the usual path and the layout used by the [KOReader community plugin collection](https://github.com/koreader/contrib).

Open a book, open KOReader's top menu, then choose **Tools → Remote Turner**. The menu should show that it is listening on port `9090`. From there you can:

- show the pairing QR code;
- show the address, port, and secret as text;
- stop or start the listener;
- change the port;
- generate a new pairing secret.

The listener runs only while KOReader is active. It closes during suspend or exit and starts again when KOReader resumes. Keep Wi-Fi enabled on the KOReader device. The plugin does not wake a suspended device; wake it using its hardware button before reconnecting.

To update, stop Remote Turner, exit KOReader, replace the plugin folder, and restart KOReader. Pairing settings are stored separately and normally survive an update. To remove it, stop the listener first, exit KOReader, delete `remote_turner.koplugin`, and restart. Stopping the listener removes the Kindle firewall rules it added.

## Run the app

Open `KOReaderiOSRemote.xcodeproj` in Xcode 26 or later. The normal builds share the same remote interface and protocol; the differences are bundled components and signing requirements.

### Choose a build

| Feature                                      | Full  | Free  |  FreeWatch   |  AltStore   |
| :------------------------------------------- | :---: | :---: | :----------: | :---------: |
| QR/manual pairing · Next/Previous/Sleep      |   ✓   |   ✓   |      ✓       |      ✓      |
| Locked-screen volume & media controls        |   ✓   |   ✓   |      ✓       |      ✓      |
| Siri · Shortcuts · Action Button shortcut    |   ✓   |   ✓   |      ✓       |      ✓      |
| Native Lock Screen / Control Center controls |   ✓   |   —   |      —       |      —      |
| Apple Watch companion                        |   ✓   |   —   | Experimental |      —      |
| App Groups & shared Keychain                 |   ✓   |   —   |      —       |      —      |
| Installation route                           | Xcode | Xcode |    Xcode     | Re-sign IPA |

**✓ Included · — Not bundled.** Volume/media capture is opt-in and uses background audio; real locked-screen delivery still depends on iOS and the audio session. Every build keeps the pairing secret in Keychain. “Shared Keychain” means sharing with another bundle, not stronger secret storage.

- **KORemoteFull**: includes Controls and Watch; needs provisioning for the app, extension, Watch, and their sharing capabilities.
- **KORemoteFree**: app-only build for a free Personal Team; no shared capabilities or embedded products to provision.
- **KORemoteFreeWatch**: Free plus the Watch companion, paired through WatchConnectivity. Free-team Watch installation remains experimental; the Watch interface is the same as Full.
- **KORemoteAltStore**: the same app-only features as Free, packaged as an unsigned IPA. It is not locked to AltStore: compatible third-party signing services can also re-sign it. Service-specific installation is unverified.

Full does **not** disable locked-screen volume or media controls. Free and AltStore retain these features; they omit native Controls and Watch to simplify signing. Siri/Shortcuts remain available without the Controls extension.

<details>
<summary>Other Xcode schemes</summary>

- **KORemote** builds the same full app target as **KORemoteFull**; it is not another edition.
- **KORemoteControls** builds the Controls extension with the full app as its launch host.
- **KORemoteWatch** launches the full build's Watch companion.
- **KORemoteWatchFree** launches the FreeWatch companion; use **KORemoteFreeWatch** for its iPhone app.
- **KORemoteLabs** is a separate research app with private volume/media experiments. It uses pairing saved by Full and is excluded from public release downloads.

Run uses Debug; Archive uses Release. Debug Watch builds additionally expose Gesture Lab; it is absent from Release.

</details>

### Third-party certificates and signing services

**A paid signing service may install Full, but buying a certificate alone does not guarantee all Full features.** Full needs correctly provisioned App Groups, shared Keychain access, its Controls extension, and the embedded Watch app. An iPhone registration alone does not provision the Watch. These are signing requirements, not a paywall in KORemote.

For an app-only install, the existing `KORemoteAltStore-<version>-unsigned.ipa` is the simpler candidate: upload it to a compatible signing service instead of importing it into AltStore. It retains pairing, page actions, volume/media modes, and Shortcuts. Full and Watch support must be confirmed with the service; no Signulous installation has been verified for this project.

See [the scheme and signing review](DISTRIBUTION.md#third-party-signing) for exactly what a provider must support. Signature expiry depends on the signing account/profile, not the scheme name.

### Install an IPA with AltStore Classic

1. Follow the official [AltStore Classic setup guide](https://faq.altstore.io/altstore-classic/your-altstore) for your computer and iPhone.
2. Download `KORemoteAltStore-<version>-unsigned.ipa` from a [release](https://github.com/maxoliinyk/koreader-ios-remote/releases), when available. Save the IPA in Files; do not extract it.
3. In AltStore Classic, open **My Apps → +** and select the IPA. AltStore signs it using your Apple Account.
4. Open KORemote, pair KOReader, and allow Local Network access. Keep the app refreshed in AltStore before its signature expires.

This route includes the iPhone app and Shortcuts, volume, and media controls. It does not include the Apple Watch app or Control Center extension. For details, checksums, and building an IPA yourself, see [DISTRIBUTION.md](DISTRIBUTION.md).

### Install from source

You need a Mac, an iPhone, an Apple Account, and [Xcode 26](https://apps.apple.com/app/xcode/id497799835) or later.

Clone the project:

```bash
git clone https://github.com/maxoliinyk/koreader-ios-remote.git
```

Enter the project folder:

```bash
cd koreader-ios-remote
```

Open the project in Xcode:

```bash
open KOReaderiOSRemote.xcodeproj
```

Then:

1. Connect and unlock the iPhone. Tap **Trust** if asked.
2. In Xcode, sign in under **Xcode → Settings → Accounts**.
3. Select **KORemoteFree**, select the iPhone, and choose your Personal Team under **Signing & Capabilities**.
4. Press **Run**. Enable Developer Mode on the iPhone if asked.

The full target uses App Groups and shared Keychain access for its Controls and Watch app. `KORemoteFree` removes those capabilities and stores pairing data inside the app, so each user can attempt signing it with a free Personal Team.

With a free Personal Team, supported apps expire after 7 days. To sign one again, reconnect the iPhone, reopen the project, and press **Run**. You do not need to clone it again. See Apple's [free-account limits](https://developer.apple.com/support/compare-memberships/).

### Simulator

1. Select an iPhone simulator running iOS 26 or later.
2. Press Run.
3. Tap **Pair KOReader**, switch to **Manual**, and enter the values shown by **Tools → Remote Turner → Show manual pairing details**.

Let Xcode sign the simulator build normally. `CODE_SIGNING_ALLOWED=NO` is only for compile checks; an unsigned simulator build cannot save the pairing secret to Keychain.

### Physical iPhone

1. Connect and unlock the iPhone. Enable Developer Mode if Xcode requests it.
2. Select `KORemoteFree` for a free Apple Account, open **Signing & Capabilities**, and choose your Personal Team.
3. For the full build, use `KORemoteFull` and select a team that supports App Groups for `KORemote`, `KORemoteControls`, and `KORemoteWatch`. Labs is a separate experiment.
4. Select the iPhone and press Run.
5. Accept Camera access when scanning and Local Network access when the app first tests KOReader.

If Xcode still has an old paused process, stop it, remove KORemote from the device or simulator, and run again. Launch the `KORemote` scheme rather than the SwiftUI Preview button.

## Pair and use it

On a physical iPhone, tap **Pair KOReader** and scan **Tools → Remote Turner → Show pairing QR code**. Manual entry is always available.

After pairing, the app tests the connection. A successful test shows **KOReader is ready**. The Remote tab provides Previous, Next, and Sleep controls. Settings can test the connection, rescan, or forget the device.

For the first test:

1. Keep a book open in KOReader.
2. Confirm **Remote Turner** says it is listening.
3. Keep the KOReader device awake and on the same Wi-Fi as the iPhone.
4. Tap **Test Connection**, then **Next**.

Some guest and mesh networks block communication between clients. If pairing succeeds but the connection times out, try the main Wi-Fi network and confirm client isolation is disabled.

## Use it while the iPhone is locked

The full build includes native **Next Page** and **Previous Page** controls for the Lock Screen and Control Center. All app configurations include Siri and Shortcuts actions. They can run without opening the app after pairing and approving Local Network access once.

- Full build — Lock Screen: touch and hold the Lock Screen, choose **Customize**, select a control slot, then add **KORemote — Next Page**.
- Full build — Control Center: touch and hold an empty area, choose **Add a Control**, then add **Next Page**.
- Action Button: open **Settings → Action Button**, choose Controls (full build) or Shortcut, then select **KORemote — Next Page**.
- Siri and Shortcuts: use the supplied Next Page or Previous Page action.
- Volume buttons: open **Settings → Controls** and enable **Use Volume Buttons**. Volume Up sends Next; Volume Down sends Previous. The app keeps system volume near 50% so both directions remain available.
- Now Playing: All builds can enable **Capture Media Controls** for the Lock Screen or connected media accessories.

When volume or media controls are enabled, all iPhone builds retain an effectively inaudible background-audio session for locked-screen capture; it can interrupt other audio and use more battery. KOReader still needs to be active and reachable on the same network.

## Apple Watch

Pair KOReader in the iPhone app first. The full build includes `KORemoteWatch`. `KORemoteFreeWatch` includes an entitlement-free experimental companion that receives pairing through WatchConnectivity. AltStore Classic and the app-only `KORemoteFree` route do not include Watch. The watch tries KOReader directly over Wi-Fi and falls back through the paired iPhone when a direct connection cannot be established. It does not automatically resend after a timeout or interrupted response, because the first action may already have reached KOReader.

The Next button is the watch scene's primary hand-gesture action, so supported watches can use Double Tap while the app is visible. Debug builds also contain Gesture Lab, an experimental Core Motion impulse detector that requires physical-watch calibration.

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

## Troubleshooting

- **Scanner unavailable:** expected in the simulator; use Manual pairing.
- **Connection refused:** start Remote Turner in KOReader and check that the port matches.
- **Connection timed out:** wake the KOReader device, enable Wi-Fi, and confirm both devices are on the same LAN.
- **Authentication failed:** pair again or copy the current secret exactly. Regenerating the secret invalidates older pairings.
- **No Remote Turner menu:** verify the final path ends in `koreader/plugins/remote_turner.koplugin/main.lua`, then restart KOReader.
- **Keychain error `-34018` in the simulator:** rebuild without `CODE_SIGNING_ALLOWED=NO`.

## Development checks

```bash
xcrun swift test --package-path Packages/RemoteCore

make test-plugin

make check-distributions
```

The request format and authentication details are documented in [CONNECTION.md](CONNECTION.md). Install routes and their exact losses are in [DISTRIBUTION.md](DISTRIBUTION.md). Plugin checks need Lua (5.1 on KOReader), Python 3, and optionally `luacheck`; the app has no third-party package dependencies.

Unsupported experiments stay isolated in the Labs target; see [LABS.md](LABS.md).

## License

Based on [Remote Turner by tachibana-shin](https://github.com/tachibana-shin/koreader_remote_turner). Copyright and attribution from the original project are retained. The project is available under the [AGPL-3.0 license](LICENSE).
