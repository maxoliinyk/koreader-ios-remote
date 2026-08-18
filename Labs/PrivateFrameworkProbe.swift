import Darwin
import Foundation

struct PrivateSymbolStatus: Identifiable {
    let name: String
    let available: Bool
    var id: String { name }
}

enum PrivateFrameworkProbe {
    static func inspectMediaRemote() -> [PrivateSymbolStatus] {
        let path = "/System/Library/PrivateFrameworks/MediaRemote.framework/MediaRemote"
        guard let handle = dlopen(path, RTLD_LAZY | RTLD_LOCAL) else {
            return [PrivateSymbolStatus(name: "MediaRemote framework", available: false)]
        }
        defer { dlclose(handle) }

        return [
            "MRMediaRemoteRegisterForNowPlayingNotifications",
            "MRMediaRemoteSendCommand",
            "MRMediaRemoteGetNowPlayingInfo",
        ].map { name in
            PrivateSymbolStatus(name: name, available: dlsym(handle, name) != nil)
        }
    }
}
