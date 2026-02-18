import SwiftUI
import UIKit

struct RootView: View {
    @Namespace private var taskNamespace
    @State private var selectedTab: Tab = .today
    @State private var captureRequestID = 0

    private enum Tab: Hashable {
        case today
        case inbox
        case rituals
        case review
    }

    var body: some View {
        ZStack {
            TodayView(
                taskNamespace: taskNamespace,
                externalCaptureRequestID: $captureRequestID
            )
            .opacity(selectedTab == .today ? 1 : 0)
            .allowsHitTesting(selectedTab == .today)

            InboxView(
                taskNamespace: taskNamespace,
                onCommitToToday: {
                    withAnimation(.snappy(duration: 0.22)) {
                        selectedTab = .today
                    }
                }
            )
            .opacity(selectedTab == .inbox ? 1 : 0)
            .allowsHitTesting(selectedTab == .inbox)

            ManageHabitsView(title: "Rituals", showsDoneButton: false)
                .opacity(selectedTab == .rituals ? 1 : 0)
                .allowsHitTesting(selectedTab == .rituals)

            ReviewView()
                .opacity(selectedTab == .review ? 1 : 0)
                .allowsHitTesting(selectedTab == .review)
        }
        .animation(.snappy(duration: 0.18), value: selectedTab)
        .safeAreaInset(edge: .bottom, spacing: 0) {
            customTabBar
        }
    }

    private var customTabBar: some View {
        VStack(spacing: 0) {
            HStack(spacing: Theme.Spacing.sm) {
                tabButton(tab: .today, title: "Today", icon: "checklist")
                tabButton(tab: .inbox, title: "Inbox", icon: "tray")

                addCaptureButton

                tabButton(tab: .rituals, title: "Rituals", icon: "leaf")
                tabButton(tab: .review, title: "Review", icon: "chart.bar")
            }
            .padding(.horizontal, Theme.Spacing.lg)
            .padding(.top, Theme.Spacing.compact)
            .padding(.bottom, Theme.Spacing.sm)
        }
        .frame(maxWidth: .infinity)
        .background(Theme.surface)
        .shadow(color: Theme.cardShadow().opacity(0.45), radius: 12, y: -3)
    }

    private func tabButton(tab: Tab, title: String, icon: String) -> some View {
        let isSelected = selectedTab == tab

        return Button {
            withAnimation(.snappy(duration: 0.18)) {
                selectedTab = tab
            }
        } label: {
            VStack(spacing: Theme.Spacing.xxxs) {
                Image(systemName: icon)
                    .font(Theme.Typography.iconCard)
                Text(title)
                    .font(Theme.Typography.caption.weight(.semibold))
            }
            .foregroundStyle(isSelected ? Theme.accent : Theme.textSecondary)
            .frame(maxWidth: .infinity)
        }
        .buttonStyle(.plain)
    }

    private var addCaptureButton: some View {
        Button {
            let haptic = UIImpactFeedbackGenerator(style: .medium)
            haptic.impactOccurred()

            withAnimation(.snappy(duration: 0.18)) {
                selectedTab = .today
            }
            DispatchQueue.main.async {
                captureRequestID += 1
            }
        } label: {
            Image(systemName: "plus")
                .font(Theme.Typography.iconMedium)
                .foregroundStyle(.white)
                .frame(width: 44, height: 44)
                .background(Theme.accent, in: Circle())
                .shadow(color: Theme.cardShadow(), radius: Theme.shadowRadius, y: Theme.shadowY)
        }
        .buttonStyle(.plain)
        .accessibilityLabel("Capture task")
        .frame(maxWidth: .infinity)
    }
}
