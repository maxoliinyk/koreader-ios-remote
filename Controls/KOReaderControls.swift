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
        StaticControlConfiguration(kind: "git.shin.koreaderRemoteTurner.next") {
            ControlWidgetButton(action: NextPageIntent()) {
                Label("Next Page", systemImage: "chevron.forward")
            }
        }
        .displayName("Next Page")
        .description("Turn forward one page in KOReader.")
    }
}

struct PreviousPageControl: ControlWidget {
    var body: some ControlWidgetConfiguration {
        StaticControlConfiguration(kind: "git.shin.koreaderRemoteTurner.previous") {
            ControlWidgetButton(action: PreviousPageIntent()) {
                Label("Previous Page", systemImage: "chevron.backward")
            }
        }
        .displayName("Previous Page")
        .description("Turn back one page in KOReader.")
    }
}
