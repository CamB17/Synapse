import SwiftUI
import UIKit

struct RootView: View {
    @Namespace private var taskNamespace
    @State private var selectedTab: Tab = .today
    @State private var didConfigureTabBarAppearance = false

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
        .tint(Theme.accent)
        .toolbarColorScheme(.light, for: .tabBar)
        .toolbarBackground(Theme.surface, for: .tabBar)
        .toolbarBackground(.visible, for: .tabBar)
        .onAppear {
            configureTabBarAppearance()
        }
    }

    private func configureTabBarAppearance() {
        guard !didConfigureTabBarAppearance else { return }
        didConfigureTabBarAppearance = true

        let appearance = UITabBarAppearance()
        appearance.configureWithOpaqueBackground()
        appearance.backgroundColor = UIColor(Theme.surface)
        appearance.shadowColor = UIColor.black.withAlphaComponent(0.08)

        let normalIcon = UIColor(Theme.textSecondary).withAlphaComponent(0.85)
        let selectedIcon = UIColor(Theme.accent)

        let normalTitle = UIColor(Theme.textSecondary)
        let selectedTitle = UIColor(Theme.accent)
        let labelFont = roundedTabFont()

        let itemAppearance = UITabBarItemAppearance(style: .stacked)
        itemAppearance.normal.iconColor = normalIcon
        itemAppearance.normal.titleTextAttributes = [
            .foregroundColor: normalTitle,
            .font: labelFont
        ]
        itemAppearance.selected.iconColor = selectedIcon
        itemAppearance.selected.titleTextAttributes = [
            .foregroundColor: selectedTitle,
            .font: labelFont
        ]

        appearance.stackedLayoutAppearance = itemAppearance
        appearance.inlineLayoutAppearance = itemAppearance
        appearance.compactInlineLayoutAppearance = itemAppearance

        UITabBar.appearance().standardAppearance = appearance
        UITabBar.appearance().scrollEdgeAppearance = appearance
        UITabBar.appearance().unselectedItemTintColor = normalIcon
    }

    private func roundedTabFont() -> UIFont {
        let base = UIFont.systemFont(ofSize: 11, weight: .semibold)
        guard let descriptor = base.fontDescriptor.withDesign(.rounded) else { return base }
        return UIFont(descriptor: descriptor, size: 11)
    }
}
