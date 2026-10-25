# KOReader iOS Remote

A native iPhone and Apple Watch remote for KOReader. It sends authenticated page actions directly over your local Wi-Fi network. There is no cloud service or account.

The plugin is developed and tested on a jailbroken Kindle. Other KOReader devices should work if they support external plugins, can accept an inbound TCP connection, and expose the same KOReader page and suspend events. Automatic firewall configuration is currently Kindle-specific.

## Contents

- [Requirements](#requirements)
- [Install the KOReader plugin](#install-the-koreader-plugin)
- [Run the app](#run-the-app)
  - [Choose a build](#choose-a-build)
  - [Install an IPA with AltStore Classic](#install-an-ipa-with-altstore-classic)
  - [Install from source](#install-from-source)
- [Pair and use it](#pair-and-use-it)
- [Use it while the iPhone is locked](#use-it-while-the-iphone-is-locked)
- [Apple Watch](#apple-watch)
- [Troubleshooting](#troubleshooting)
- [Development](#development)
- [License](#license)

## Requirements

- A network-connected device running KOReader
- An iPhone running iOS 26 or later
- For source installation: a Mac with Xcode 26 or later
- Both devices on the same Wi-Fi network

## Install the KOReader plugin

1. Open [Releases](https://github.com/maxoliinyk/koreader-ios-remote/releases) and download `remote_turner-<version>.koplugin.zip` from **Assets**. The IPA is a separate download for the iPhone app.
2. Extract the ZIP and copy `remote_turner.koplugin` into KOReader's `plugins` directory.
3. Check the folder layout below: do not leave an extra directory level around `remote_turner.koplugin`.
4. Restart KOReader completely, open a book, then choose **Tools → Remote Turner** from the top menu. Confirm it is listening on port `9090`.

```text
koreader/
└── plugins/
    └── remote_turner.koplugin/
        ├── _meta.lua
        ├── httpserver.lua
        └── main.lua
```

The KOReader directory depends on your device; `koreader/plugins/` is the usual path. The Remote Turner menu provides QR/manual pairing details, listener start/stop, port settings, and secret regeneration.

<details>
<summary>Install without a release</summary>

Use GitHub's **Code → Download ZIP**, extract it, and copy the `remote_turner.koplugin` folder from the source archive into KOReader's `plugins` directory. Then follow steps 3–4 above.

Or build the plugin archive from a checkout:

```bash
make koplugin VERSION=dev
```

Extract `dist/remote_turner-dev.koplugin.zip` and follow steps 2–4 above.

</details>

The listener runs only while KOReader is active. It closes during suspend or exit and starts again when KOReader resumes. Keep Wi-Fi enabled on the KOReader device. The plugin does not wake a suspended device; wake it using its hardware button before reconnecting.

To update, stop Remote Turner, exit KOReader, replace the plugin folder, and restart KOReader. Pairing settings are stored separately and normally survive an update. To remove it, stop the listener first, exit KOReader, delete `remote_turner.koplugin`, and restart. Stopping the listener removes the Kindle firewall rules it added.

## Run the app

Choose an installation route: [install an IPA with AltStore Classic](#install-an-ipa-with-altstore-classic), or [build from source with Xcode](#install-from-source).

### Choose a build

Every build includes QR/manual pairing, Previous/Next/Sleep, Siri and Shortcuts (including Action Button shortcuts), and opt-in locked-screen volume/media controls. Pairing secrets are stored in Keychain.

- **KORemoteFree** — iPhone app for a free Apple Account; install with Xcode.
- **KORemoteAltStore** — the same app features as Free, packaged as an unsigned IPA for AltStore Classic or a compatible signing service.
- **KORemoteFull** — adds native Lock Screen / Control Center controls and Apple Watch; requires a team that can provision the app, extension, Watch, and shared capabilities.
- **KORemoteFreeWatch** — Free plus an experimental Apple Watch companion; install with Xcode. Free-team Watch installation is unverified.

For third-party signing, use the app-only AltStore IPA unless your provider confirms Full and Watch support. Buying a certificate alone does not guarantee those features; service-specific installation is unverified. See [signing requirements](DISTRIBUTION.md#third-party-signing) and [other Xcode schemes](DISTRIBUTION.md#scheme-names-and-build-behavior).

### Install an IPA with AltStore Classic

1. Follow the official [AltStore Classic setup guide](https://faq.altstore.io/altstore-classic/your-altstore) for your computer and iPhone.
2. Download `KORemoteAltStore-<version>-unsigned.ipa` from a [release](https://github.com/maxoliinyk/koreader-ios-remote/releases), when available. Save the IPA in Files; do not extract it.
3. In AltStore Classic, open **My Apps → +** and select the IPA. AltStore signs it using your Apple Account.
4. Open KORemote, pair KOReader, and allow Local Network access. Keep the app refreshed in AltStore before its signature expires.

For checksums, updates, and building an IPA yourself, see [DISTRIBUTION.md](DISTRIBUTION.md#downloads-and-updates).

### Install from source

You need a Mac, an iPhone, an Apple Account, and [Xcode 26](https://apps.apple.com/app/xcode/id497799835) or later.

```bash
git clone https://github.com/maxoliinyk/koreader-ios-remote.git
cd koreader-ios-remote
open KOReaderiOSRemote.xcodeproj
```

1. Connect and unlock the iPhone. Tap **Trust** if asked.
2. In Xcode, sign in under **Xcode → Settings → Accounts**.
3. Select the **KORemoteFree** scheme and your iPhone. Under **Signing & Capabilities**, choose your Personal Team. If Xcode says the bundle identifier is unavailable, change it to a unique one.
4. Press **Run**. Enable Developer Mode on the iPhone if asked.

For Full or FreeWatch, choose the corresponding scheme and follow the [signing and target configuration](DISTRIBUTION.md#target-matrix).

With a free Personal Team, supported apps expire after 7 days. To sign one again, reconnect the iPhone, reopen the project, and press **Run**. You do not need to clone it again. See Apple's [free-account limits](https://developer.apple.com/support/compare-memberships/).

## Pair and use it

On a physical iPhone, tap **Pair KOReader** and scan **Tools → Remote Turner → Show pairing QR code**. Allow Camera access when scanning and Local Network access when prompted. You can also choose **Manual** and enter the address, port, and secret from **Show manual pairing details**.

After pairing, the app tests the connection. A successful test shows **KOReader is ready**. The Remote tab provides Previous, Next, and Sleep controls. Settings can test the connection, rescan, or forget the device.

For the first test:

1. Keep a book open in KOReader.
2. Confirm **Remote Turner** says it is listening.
3. Keep the KOReader device awake and on the same Wi-Fi as the iPhone.
4. Tap **Test Connection**, then **Next**.

## Use it while the iPhone is locked

The full build includes native **Next Page** and **Previous Page** controls for the Lock Screen and Control Center. All app configurations include Siri and Shortcuts actions. They can run without opening the app after pairing and approving Local Network access once.

- Full build — Lock Screen: touch and hold the Lock Screen, choose **Customize**, select a control slot, then add **KORemote — Next Page**.
- Full build — Control Center: touch and hold an empty area, choose **Add a Control**, then add **Next Page**.
- Action Button: open **Settings → Action Button**, choose Controls (full build) or Shortcut, then select **KORemote — Next Page**.
- Siri and Shortcuts: use the supplied Next Page or Previous Page action.
- Volume buttons: open **Settings → Controls** and enable **Use Volume Buttons**. Volume Up sends Next; Volume Down sends Previous. The app keeps system volume near 50% so both directions remain available.
- Now Playing: All builds can enable **Capture Media Controls** for the Lock Screen or connected media accessories.

When volume or media controls are enabled, all iPhone builds retain an effectively inaudible background-audio session for locked-screen capture; it can interrupt other audio and use more battery. Locked-screen delivery depends on iOS and the audio session. KOReader still needs to be active and reachable on the same network.

## Apple Watch

Install a build with Watch support, then pair KOReader in the iPhone app first. Pairing transfers to the Watch automatically. The Watch tries KOReader directly over Wi-Fi and falls back through the paired iPhone when a direct connection cannot be established. It does not automatically resend after a timeout or interrupted response, because the first action may already have reached KOReader.

On supported watches, Double Tap activates Next while the app is visible.

## Troubleshooting

- **Scanner unavailable:** expected in the simulator; use Manual pairing.
- **Connection refused:** start Remote Turner in KOReader and check that the port matches.
- **Connection timed out:** wake the KOReader device, enable Wi-Fi, and confirm both devices are on the same LAN. Guest or mesh networks may block communication between devices; try the main network and check client isolation.
- **Authentication failed:** pair again or copy the current secret exactly. Regenerating the secret invalidates older pairings.
- **No Remote Turner menu:** verify the final path ends in `koreader/plugins/remote_turner.koplugin/main.lua`, then restart KOReader.
- **Keychain error `-34018` in the simulator:** rebuild without `CODE_SIGNING_ALLOWED=NO`.

## Development

```bash
xcrun swift test --package-path Packages/RemoteCore

make test-plugin

make check-distributions
```

Plugin checks need Lua (5.1 on KOReader), Python 3, and optionally `luacheck`; the app has no third-party package dependencies.

- [Protocol and authentication](CONNECTION.md)
- [Build configurations and signing](DISTRIBUTION.md)
- [Simulator setup](DISTRIBUTION.md#simulator-setup)
- [Bundle identifiers](DISTRIBUTION.md#bundle-identifiers)

Unsupported experiments stay isolated in the Labs target; see [LABS.md](LABS.md).

## License

Based on [Remote Turner by tachibana-shin](https://github.com/tachibana-shin/koreader_remote_turner). Copyright and attribution from the original project are retained. The project is available under the [AGPL-3.0 license](LICENSE).
