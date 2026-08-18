import RemoteCore
import SwiftUI
import WidgetKit

@main
struct KOReaderControls: WidgetBundle {
    var body: some Widget {
        NextPageControl()
        PreviousPageControl()
    }
}

struct NextPageControl: ControlWidget {
    var body: some ControlWidgetConfiguration {
        StaticControlConfiguration(kind: "com.maxoliinyk.koreaderremote.next") {
            ControlWidgetButton(action: NextPageIntent()) {
                Label("Next Page", systemImage: "chevron.forward")
                    .controlWidgetActionHint("Turn the next page")
            }
        }
        .displayName("Next Page")
        .description("Turn forward one page in KOReader.")
    }
}

struct PreviousPageControl: ControlWidget {
    var body: some ControlWidgetConfiguration {
        StaticControlConfiguration(kind: "com.maxoliinyk.koreaderremote.previous") {
            ControlWidgetButton(action: PreviousPageIntent()) {
                Label("Previous Page", systemImage: "chevron.backward")
                    .controlWidgetActionHint("Turn the previous page")
            }
        }
        .displayName("Previous Page")
        .description("Turn back one page in KOReader.")
    }
}
