//
//  PrivateFrameworkProbe.swift
//  KORemote
//
//  Created by Max Oliinyk on 18.08.26.
//

import Darwin
import Foundation

struct PrivateSymbolStatus: Identifiable {
    let name: String
    let available: Bool
    var id: String { name }
}

enum PrivateFrameworkProbe {
    private static let path = "/System/Library/PrivateFrameworks/MediaRemote.framework/MediaRemote"

    static func inspectMediaRemote() -> [PrivateSymbolStatus] {
        guard let handle = dlopen(path, RTLD_LAZY | RTLD_LOCAL) else {
            return [PrivateSymbolStatus(name: "MediaRemote framework", available: false)]
        }
        defer { dlclose(handle) }
        return [
            "MRMediaRemoteRegisterForNowPlayingNotifications",
            "MRMediaRemoteSetCanBeNowPlayingApplication",
            "MRMediaRemoteSetNowPlayingInfo",
            "MRMediaRemoteSendCommand",
            "MRMediaRemoteGetNowPlayingInfo",
        ].map { name in
            PrivateSymbolStatus(name: name, available: dlsym(handle, name) != nil)
        }
    }

    static func claimNowPlaying(_ enabled: Bool) -> String {
        guard let handle = dlopen(path, RTLD_LAZY | RTLD_LOCAL) else {
            return "MediaRemote could not be loaded"
        }
        defer { dlclose(handle) }
        guard let symbol = dlsym(handle, "MRMediaRemoteSetCanBeNowPlayingApplication") else {
            return "Private claim symbol is missing"
        }
        typealias Function = @convention(c) (UInt8) -> UInt8
        let accepted = unsafeBitCast(symbol, to: Function.self)(enabled ? 1 : 0) != 0
        return accepted ? "MediaRemote accepted the request" : "MediaRemote returned false"
    }
}
