import SwiftUI

struct RootView: View {
    var body: some View {
        TabView {
            TodayView()
                .tabItem { Label("Today", systemImage: "checklist") }

            InboxView()
                .tabItem { Label("Inbox", systemImage: "tray") }

            ReviewView()
                .tabItem { Label("Review", systemImage: "chart.bar") }
        }
    }
}