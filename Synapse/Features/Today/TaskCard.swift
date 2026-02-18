import SwiftUI

struct TaskCard: View {
    let id: UUID
    let namespace: Namespace.ID
    let title: String
    let subtitle: String?
    let prominent: Bool
    let isCompleted: Bool
    let onTap: (() -> Void)?
    let onComplete: (() -> Void)?
    @State private var completedAppear = false

    @ViewBuilder
    var body: some View {
        if let onTap {
            cardContent
                .onTapGesture {
                    onTap()
                }
        } else {
            cardContent
        }
    }

    private var cardContent: some View {
        HStack(spacing: Theme.Spacing.sm) {
            if let onComplete {
                Button {
                    onComplete()
                } label: {
                    Image(systemName: isCompleted ? "checkmark.circle.fill" : "circle")
                        .font(Theme.Typography.iconXL)
                        .foregroundStyle(isCompleted ? Theme.accent : Theme.textSecondary)
                }
                .buttonStyle(.plain)
            }

            VStack(alignment: .leading, spacing: Theme.Spacing.xxs) {
                Text(title)
                    .font(prominent ? Theme.Typography.itemTitleProminent : Theme.Typography.itemTitleCompact)
                    .foregroundStyle(Theme.text)

                if let subtitle {
                    Text(subtitle)
                        .font(Theme.Typography.bodySmall)
                        .foregroundStyle(Theme.textSecondary)
                }
            }

            Spacer()
        }
        .contentShape(Rectangle())
        .padding(Theme.Spacing.cardInset)
        .surfaceCard(style: isCompleted ? .accentTint : .primary, cornerRadius: Theme.radius)
        .scaleEffect(isCompleted ? (completedAppear ? 1 : 0.985) : 1)
        .animation(.snappy(duration: 0.18), value: completedAppear)
        .matchedGeometryEffect(id: id, in: namespace)
        .onAppear {
            guard isCompleted else { return }
            withAnimation(.snappy(duration: 0.18)) {
                completedAppear = true
            }
        }
        .onChange(of: isCompleted) { oldValue, newValue in
            guard !oldValue, newValue else { return }
            completedAppear = false
            withAnimation(.snappy(duration: 0.18)) {
                completedAppear = true
            }
        }
        .contextMenu {
            if let onComplete {
                Button("Complete", systemImage: "checkmark") { onComplete() }
            }
            if let onTap {
                Button("Focus", systemImage: "timer") { onTap() }
            }
        }
    }
}
