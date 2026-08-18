// swift-tools-version: 6.2

import PackageDescription

let package = Package(
    name: "RemoteCore",
    platforms: [
        .iOS(.v26),
        .watchOS(.v26),
        .macOS(.v15),
    ],
    products: [
        .library(name: "RemoteCore", targets: ["RemoteCore"]),
    ],
    targets: [
        .target(name: "RemoteCore"),
        .testTarget(name: "RemoteCoreTests", dependencies: ["RemoteCore"]),
    ],
    swiftLanguageModes: [.v6]
)
