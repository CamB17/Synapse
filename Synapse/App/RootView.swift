import SwiftUI

struct RootView: View {
    @Namespace private var taskNamespace
    @State private var selectedTab: Tab = .today

    private enum Tab: Hashable {
        case today
        case inbox
        case review
    }

    var body: some View {
        TabView(selection: $selectedTab) {
            TodayView(taskNamespace: taskNamespace)
                .tabItem { Label("Today", systemImage: "checklist") }
                .tag(Tab.today)

            InboxView(
                taskNamespace: taskNamespace,
                onCommitToToday: {
                    withAnimation(.snappy(duration: 0.22)) {
                        selectedTab = .today
                    }
                }
            )
                .tabItem { Label("Inbox", systemImage: "tray") }
                .tag(Tab.inbox)

            ReviewView()
                .tabItem { Label("Review", systemImage: "chart.bar") }
                .tag(Tab.review)
        }
    }
}
