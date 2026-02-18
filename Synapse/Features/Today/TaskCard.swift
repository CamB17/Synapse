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
        HStack(spacing: 12) {
            if let onComplete {
                Button {
                    onComplete()
                } label: {
                    Image(systemName: isCompleted ? "checkmark.circle.fill" : "circle")
                        .font(.system(size: 22, weight: .semibold))
                        .foregroundStyle(isCompleted ? Theme.accent : Theme.textSecondary)
                }
                .buttonStyle(.plain)
            }

            VStack(alignment: .leading, spacing: 4) {
                Text(title)
                    .font(.system(size: prominent ? 17 : 16, weight: .semibold, design: .rounded))
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
        .padding(14)
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
