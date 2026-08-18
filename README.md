# KOReader Remote

A native Apple remote for KOReader. Turn pages or put a Kindle to sleep over the local network—no cloud, account, analytics, or third-party app dependencies.

## Architecture

```text
iPhone / Apple Watch / App Intent
→ authenticated short HTTP request
→ KOReader plugin listener on Kindle
→ KOReader page action
```

- Native SwiftUI application for iOS 26 and later.
- Shared Swift `RemoteCore` package for pairing, HMAC authentication, storage, and networking.
- KOReader plugin built on LuaSocket and KOReader's TCP-server integration.
- Pairing through a KOReader QR code or manual host, port, and secret entry.
- HMAC-SHA256 authentication and bounded nonce replay protection.
- English, Vietnamese, Japanese, and Simplified Chinese localization.

## Install the KOReader plugin

Copy `remote_turner.koplugin` into KOReader's `plugins` directory, restart KOReader, then open **Tools → Remote Turner → Show pairing QR code**.

The listener defaults to TCP port `9090`, starts while KOReader is active, and closes during suspend, standby, or exit. On Kindle hardware, its firewall rules follow the listener lifecycle.

## Build the Apple app

Requirements: Xcode 27 beta 5 or newer with the iOS 27 SDK.

```bash
open KOReaderRemote.xcodeproj
swift test --package-path Packages/RemoteCore
xcodebuild -project KOReaderRemote.xcodeproj -scheme KOReaderRemote \
  -destination 'generic/platform=iOS Simulator' CODE_SIGNING_ALLOWED=NO build
```

Select your development team before running on an iPhone. The first connection attempt asks for Local Network access.

## Package the plugin

```bash
make koplugin VERSION=2.0.0
```

See [CONNECTION.md](CONNECTION.md) for the protocol.

## License

Copyright and attribution from the original project are retained. Source is available under the [AGPL-3.0 license](LICENSE).
