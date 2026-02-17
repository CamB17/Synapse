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

    var body: some View {
        HStack(spacing: 12) {
            if let onComplete {
                Button {
                    onComplete()
                } label: {
                    Image(systemName: isCompleted ? "checkmark.circle.fill" : "circle")
                        .font(.system(size: 22, weight: .semibold))
                }
                .buttonStyle(.plain)
            }

            VStack(alignment: .leading, spacing: 4) {
                Text(title)
                    .font(.system(size: prominent ? 17 : 16, weight: .semibold))

                if let subtitle {
                    Text(subtitle)
                        .font(.system(size: 13, weight: .medium))
                        .foregroundStyle(.secondary)
                }
            }

            Spacer()
        }
        .contentShape(Rectangle())
        .onTapGesture {
            onTap?()
        }
        .padding(14)
        .background(.thinMaterial,
                    in: RoundedRectangle(cornerRadius: 16, style: .continuous))
        .matchedGeometryEffect(id: id, in: namespace)
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
