# KOReader iOS Remote

A native iPhone and Apple Watch remote for KOReader. It sends authenticated page actions directly over your local Wi-Fi network. There is no cloud service or account.

The plugin is developed and tested on a jailbroken Kindle. Other KOReader devices should work if they support external plugins, can accept an inbound TCP connection, and expose the same KOReader page and suspend events. Automatic firewall configuration is currently Kindle-specific.

## Requirements

- A network-connected device running KOReader
- An iPhone running iOS 26 or later
- Xcode 26 or later
- Both devices on the same Wi-Fi network

The simulator is useful for interface testing but cannot scan a pairing QR code. Use manual pairing there.

## Install the KOReader plugin

Build the plugin archive from the repository root:

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

The listener runs only while KOReader is active. It closes during suspend or exit and starts again when KOReader resumes. Keep Wi-Fi enabled on the KOReader device.

## Run the app

Open `KOReaderiOSRemote.xcodeproj` in Xcode 26 or later. Select the **KORemote** scheme, not Labs, Controls, or Watch.

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
3. Select the **KORemote** scheme, select the iPhone, and choose your team under **Signing & Capabilities**.
4. Press **Run**. Enable Developer Mode on the iPhone if asked.

The full KORemote target currently needs a paid Apple Developer team because its controls and Watch app use App Groups and shared Keychain access. A free-account target is not included yet.

With a free Personal Team, supported apps expire after 7 days. To sign one again, reconnect the iPhone, reopen the project, and press **Run**. You do not need to clone it again. See Apple's [free-account limits](https://developer.apple.com/support/compare-memberships/).

### Simulator

1. Select an iPhone simulator running iOS 26 or later.
2. Press Run.
3. Tap **Pair KOReader**, switch to **Manual**, and enter the values shown by **Tools → Remote Turner → Show manual pairing details**.

Let Xcode sign the simulator build normally. `CODE_SIGNING_ALLOWED=NO` is only for compile checks; an unsigned simulator build cannot save the pairing secret to Keychain.

### Physical iPhone

1. Connect and unlock the iPhone. Enable Developer Mode if Xcode requests it.
2. Select the `KORemote` target, open **Signing & Capabilities**, and choose your development team.
3. Use the same team for `KORemoteControls`, `KORemoteWatch`, and `KORemoteLabs` when building those targets.
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

The normal app includes native **Next Page** and **Previous Page** controls. They can run without opening the app after pairing and approving Local Network access once.

- Lock Screen: touch and hold the Lock Screen, choose **Customize**, select a control slot, then add **KORemote — Next Page**.
- Control Center: touch and hold an empty area, choose **Add a Control**, then add **Next Page**.
- Action Button: open **Settings → Action Button**, choose Controls or Shortcut, then select **KORemote — Next Page**.
- Siri and Shortcuts: use the supplied Next Page or Previous Page action.
- Volume buttons: open **Settings → System Controls** and enable **Use Volume Buttons**. Volume Up sends Next; Volume Down sends Previous. The app keeps system volume near 50% so both directions remain available.
- Now Playing: enable **Capture Media Controls** on the same screen to use Previous and Next from the Lock Screen or connected media accessories.

Volume and media capture keep an effectively inaudible background-audio session active. They can interrupt other audio and use more battery. KOReader still needs to be active and reachable on the same network.

## Apple Watch

Pair KOReader in the iPhone app first. Install or run the `KORemoteWatch` companion through Xcode, then open KORemote on the watch. It tries the KOReader device directly over Wi-Fi and falls back through the paired iPhone.

The Next button is the watch scene's primary hand-gesture action, so supported watches can use Double Tap while the app is visible. Debug builds also contain Gesture Lab, an experimental Core Motion impulse detector that requires physical-watch calibration.

## Bundle identifiers

The project uses one reverse-domain identifier family:

- App: `com.maxoliinyk.koreaderremote`
- Controls: `com.maxoliinyk.koreaderremote.controls`
- Watch: `com.maxoliinyk.koreaderremote.watch`
- Labs: `com.maxoliinyk.koreaderremote.labs`
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

xcodebuild -project KOReaderiOSRemote.xcodeproj -scheme KORemote \
  -destination 'generic/platform=iOS Simulator' \
  CODE_SIGNING_ALLOWED=NO build
```

The request format and authentication details are documented in [CONNECTION.md](CONNECTION.md). Unsupported experiments stay isolated in the Labs target; see [LABS.md](LABS.md).

## License

Copyright and attribution from the original project are retained. The project is available under the [AGPL-3.0 license](LICENSE).
