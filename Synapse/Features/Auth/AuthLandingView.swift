import SwiftUI

struct AuthLandingView: View {
    @EnvironmentObject private var session: AppSession

    @State private var showEmailPrompt = false

    var body: some View {
        NavigationStack {
            ScreenCanvas {
                VStack(alignment: .leading, spacing: Theme.Spacing.md) {
                    Spacer(minLength: 0)

                    VStack(alignment: .leading, spacing: Theme.Spacing.xs) {
                        Text("All-in-one planning and productivity")
                            .font(.system(size: 34, weight: .semibold, design: .rounded))
                            .foregroundStyle(Theme.text)
                            .fixedSize(horizontal: false, vertical: true)

                        Text("Habits, tasks, focus, and calendar, without the clutter.")
                            .font(Theme.Typography.bodyMedium)
                            .foregroundStyle(Theme.textSecondary)
                            .fixedSize(horizontal: false, vertical: true)
                    }

                    VStack(spacing: Theme.Spacing.xs) {
                        authButton(title: "Continue with Apple", icon: "applelogo") {
                            completeAuth()
                        }

                        authButton(title: "Continue with Google", icon: "g.circle") {
                            completeAuth()
                        }

                        authButton(title: "Continue with Email", icon: "envelope") {
                            showEmailPrompt = true
                        }

                        Button {
                            completeAuth()
                        } label: {
                            Text("Log in")
                                .font(Theme.Typography.bodySmallStrong)
                                .foregroundStyle(Theme.textSecondary)
                                .frame(maxWidth: .infinity)
                                .padding(.vertical, Theme.Spacing.xs)
                        }
                        .buttonStyle(.plain)
                    }

                    Spacer(minLength: 0)
                }
                .padding(Theme.Spacing.md)
            }
            .alert("Continue with Email", isPresented: $showEmailPrompt) {
                Button("Continue") {
                    completeAuth()
                }
                Button("Cancel", role: .cancel) {}
            } message: {
                Text("Email login is enabled as a local auth path in this build.")
            }
        }
    }

    private func authButton(title: String, icon: String, action: @escaping () -> Void) -> some View {
        Button {
            action()
        } label: {
            HStack(spacing: Theme.Spacing.xs) {
                Image(systemName: icon)
                    .font(Theme.Typography.iconCompact)
                Text(title)
                    .font(Theme.Typography.bodySmallStrong)
            }
            .foregroundStyle(.white)
            .frame(maxWidth: .infinity)
            .padding(.vertical, Theme.Spacing.sm)
            .background(
                RoundedRectangle(cornerRadius: 14, style: .continuous)
                    .fill(Theme.text)
            )
        }
        .buttonStyle(AuthPressStyle())
    }

    private func completeAuth() {
        withAnimation(Motion.easing) {
            session.signIn()
        }
    }
}

private struct AuthPressStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .opacity(configuration.isPressed ? 0.95 : 1)
            .scaleEffect(configuration.isPressed ? 0.99 : 1)
            .animation(Motion.easing, value: configuration.isPressed)
    }
}
