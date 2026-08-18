// swift-tools-version: 6.2
//
//  Package.swift
//  KORemote
//
//  Created by Max Oliinyk on 18.08.26.
//

import PackageDescription

let package = Package(
    name: "RemoteCore",
    defaultLocalization: "en",
    platforms: [
        .iOS(.v26),
        .watchOS(.v26),
        .macOS(.v15),
    ],
    products: [
        .library(name: "RemoteCore", targets: ["RemoteCore"]),
    ],
    targets: [
        .target(name: "RemoteCore", resources: [.process("Resources")]),
        .testTarget(name: "RemoteCoreTests", dependencies: ["RemoteCore"]),
    ],
    swiftLanguageModes: [.v6]
)
