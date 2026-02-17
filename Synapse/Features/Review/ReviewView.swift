import SwiftUI
import SwiftData

struct ReviewView: View {
    @Query(sort: [SortDescriptor(\FocusSession.startedAt, order: .reverse)])
    private var sessions: [FocusSession]

    var body: some View {
        NavigationStack {
            VStack(alignment: .leading, spacing: 10) {
                Text("Review (Week 1)")
                    .font(.system(size: 18, weight: .semibold))

                Text("Keep this minimal. Add weekly rollups after Today + Inbox feel tight.")
                    .font(.system(size: 15))
                    .foregroundStyle(.secondary)

                Divider().padding(.vertical, 6)

                Text("Latest sessions: \(sessions.prefix(5).count)")
                    .font(.system(size: 15, weight: .medium))
                    .foregroundStyle(.secondary)

                Spacer()
            }
            .padding(16)
            .navigationTitle("Review")
        }
    }
}