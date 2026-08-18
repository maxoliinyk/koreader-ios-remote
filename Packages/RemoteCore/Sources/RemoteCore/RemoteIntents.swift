#if canImport(AppIntents)
import AppIntents
import Foundation

private enum IntentRunner {
    static func run(_ action: RemoteAction) async throws {
        let storage = PairingStore()
        guard let configuration = try storage.load() else {
            throw RemoteIntentError.unpaired
        }
        do {
            _ = try await KindleClient().send(action, using: configuration)
        } catch let error as KindleClientError {
            throw RemoteIntentError.client(error)
        }
    }
}

public enum RemoteIntentError: Error, CustomLocalizedStringResourceConvertible {
    case unpaired
    case client(KindleClientError)

    public var localizedStringResource: LocalizedStringResource {
        switch self {
        case .unpaired:
            "Open KOReader Remote and pair a Kindle first."
        case let .client(error):
            LocalizedStringResource(stringLiteral: error.localizedDescription)
        }
    }
}

public struct NextPageIntent: AppIntent {
    public static let title: LocalizedStringResource = "Next Page"
    public static let description = IntentDescription("Turn forward one page in KOReader.")
    public static let openAppWhenRun = false

    public init() {}

    public func perform() async throws -> some IntentResult & ProvidesDialog {
        try await IntentRunner.run(.nextPage)
        return .result(dialog: "Next page sent.")
    }
}

public struct PreviousPageIntent: AppIntent {
    public static let title: LocalizedStringResource = "Previous Page"
    public static let description = IntentDescription("Turn back one page in KOReader.")
    public static let openAppWhenRun = false

    public init() {}

    public func perform() async throws -> some IntentResult & ProvidesDialog {
        try await IntentRunner.run(.previousPage)
        return .result(dialog: "Previous page sent.")
    }
}

public struct SleepKindleIntent: AppIntent {
    public static let title: LocalizedStringResource = "Sleep Kindle"
    public static let description = IntentDescription("Put the paired Kindle to sleep.")
    public static let openAppWhenRun = false

    public init() {}

    public func perform() async throws -> some IntentResult & ProvidesDialog {
        try await IntentRunner.run(.sleep)
        return .result(dialog: "Sleep sent.")
    }
}
#endif
