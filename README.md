# KOReader Remote

A native iPhone and Apple Watch remote for KOReader. It turns pages over your local Wi-Fi network. There is no cloud service or account.

## What you need

- A jailbroken Kindle with a working KOReader installation
- An iPhone on iOS 26 or later
- Xcode 27 beta 5 or later
- The Kindle and iPhone on the same Wi-Fi network

The simulator is useful for checking the interface, but it cannot scan the Kindle's QR code. Use manual pairing there.

## Install the KOReader plugin

Build the plugin archive from the repository root:

```bash
make koplugin VERSION=dev
```

This creates `dist/remote_turner-dev.koplugin.zip`. Unzip it and copy the enclosed `remote_turner.koplugin` folder to the Kindle over USB:

```text
Kindle USB storage/
└── koreader/
    └── plugins/
        └── remote_turner.koplugin/
            ├── _meta.lua
            ├── httpserver.lua
            └── main.lua
```

Do not leave an extra folder level around `remote_turner.koplugin`. Eject the Kindle, quit KOReader completely, and start it again. KOReader loads external plugins from `koreader/plugins/`; this is also the layout used by the [KOReader community plugin collection](https://github.com/koreader/contrib).

Open a book, open KOReader's top menu, then choose **Tools → Remote Turner**. The menu should show that it is listening on port `9090`. From there you can:

- show the pairing QR code;
- show the same address, port, and secret as text;
- stop or start the listener;
- change the port;
- generate a new pairing secret.

The listener runs only while KOReader is active. It closes when the Kindle suspends or KOReader exits, then starts again when KOReader resumes. Leave Wi-Fi enabled on the Kindle.

## Run the iPhone app

Open `KOReaderRemote.xcodeproj` in Xcode 27 beta 5. In the toolbar, select the **KOReaderRemote** scheme—not the Labs, Controls, or Watch scheme.

### Simulator

1. Select an iPhone simulator running iOS 26 or later.
2. Press Run.
3. Tap **Pair Kindle**, switch to **Manual**, and enter the values shown by **Tools → Remote Turner → Show manual pairing details** on the Kindle.

Let Xcode sign the simulator build normally. `CODE_SIGNING_ALLOWED=NO` is only for compile checks; an unsigned simulator build cannot save the pairing secret to Keychain.

### Physical iPhone

1. Connect and unlock the iPhone. Enable Developer Mode if Xcode asks for it.
2. Select the `KOReaderRemote` target, open **Signing & Capabilities**, and choose your development team.
3. Use the same team for `KOReaderControls` and `WatchRemote` if Xcode reports a signing error for an embedded target.
4. Select the iPhone in the toolbar and press Run.
5. Accept Camera access when scanning and Local Network access when the app first tests the Kindle connection.

If Xcode still has an old paused process from a failed run, stop it, delete KOReader Remote from the device or simulator, and run again. Do not use the SwiftUI Preview play button to launch the app; run the `KOReaderRemote` scheme.

## Pair and use it

On a physical iPhone, tap **Pair Kindle** and scan **Tools → Remote Turner → Show pairing QR code**. Manual entry is always available.

After pairing, the app immediately tests the connection. A successful test shows **KOReader is ready**. The Remote tab then provides Previous, Next, and Sleep controls. The Settings tab can test the connection, rescan, or forget the Kindle.

For the first test:

1. Keep a book open in KOReader.
2. Confirm **Remote Turner** says it is listening.
3. Keep the Kindle awake and on the same Wi-Fi as the iPhone.
4. Tap **Test Connection**, then **Next**.

Some guest and mesh networks block devices from talking to each other. If pairing succeeds but connection tests time out, try the main Wi-Fi network and confirm that client isolation is disabled.

## Apple Watch

Pair the Kindle in the iPhone app first. Install or run the `WatchRemote` companion through Xcode, then open KOReader Remote on the watch. It tries the Kindle directly over Wi-Fi and falls back to the paired iPhone. The iPhone must have completed its first Local Network permission prompt before relay actions can work.

## Troubleshooting

- **App stops in `_dispatch_assert_queue_fail`:** update to the current source, stop the old Xcode process, remove the installed app, and run again. The crash was caused by a WatchConnectivity callback using the wrong actor.
- **Keychain error `-34018` in the simulator:** rebuild without `CODE_SIGNING_ALLOWED=NO`.
- **Scanner unavailable:** expected in the simulator; use Manual pairing.
- **Connection refused:** start the listener in KOReader and check that the port matches.
- **Connection timed out:** wake the Kindle, enable its Wi-Fi, and check both devices are on the same LAN.
- **Authentication failed:** scan again or copy the current secret exactly. Generating a new secret invalidates older pairings.
- **No Remote Turner menu:** verify the final path is `koreader/plugins/remote_turner.koplugin/main.lua`, then restart KOReader.

## Development checks

```bash
DEVELOPER_DIR=/Applications/Xcode-27.0.0-beta.app/Contents/Developer \
  xcrun swift test --package-path Packages/RemoteCore

DEVELOPER_DIR=/Applications/Xcode-27.0.0-beta.app/Contents/Developer \
  xcodebuild -project KOReaderRemote.xcodeproj -scheme KOReaderRemote \
  -destination 'generic/platform=iOS Simulator' CODE_SIGNING_ALLOWED=NO build
```

The request format and authentication details are documented in [CONNECTION.md](CONNECTION.md). Private API experiments stay isolated in the Labs target; see [LABS.md](LABS.md).

## License

Copyright and attribution from the original project are retained. The project is available under the [AGPL-3.0 license](LICENSE).
