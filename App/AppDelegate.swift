import RemoteCore
import UIKit

final class AppDelegate: NSObject, UIApplicationDelegate {
    func application(
        _ application: UIApplication,
        performActionFor shortcutItem: UIApplicationShortcutItem,
        completionHandler: @escaping (Bool) -> Void
    ) {
        let action: RemoteAction?
        switch shortcutItem.type {
        case "com.maxoliinyk.koreaderremote.next": action = .nextPage
        case "com.maxoliinyk.koreaderremote.previous": action = .previousPage
        default: action = nil
        }

        guard let action else {
            completionHandler(false)
            return
        }
        Task {
            do {
                guard let configuration = try PairingStore().load() else {
                    completionHandler(false)
                    return
                }
                _ = try await KindleClient().send(action, using: configuration)
                completionHandler(true)
            } catch {
                completionHandler(false)
            }
        }
    }
}
