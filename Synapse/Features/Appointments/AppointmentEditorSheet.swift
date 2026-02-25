import SwiftData
import SwiftUI

struct AppointmentEditorSheet: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext

    let appointment: Appointment?
    let defaultStartDate: Date
    let onSaved: ((Appointment) -> Void)?

    @State private var title: String
    @State private var startDate: Date
    @State private var includeEndDate: Bool
    @State private var endDate: Date
    @State private var isAllDay: Bool
    @State private var location: String
    @State private var notes: String
    @State private var showDeleteConfirmation = false

    private var calendar: Calendar { .current }

    init(
        appointment: Appointment? = nil,
        defaultStartDate: Date = .now,
        onSaved: ((Appointment) -> Void)? = nil
    ) {
        self.appointment = appointment
        self.defaultStartDate = defaultStartDate
        self.onSaved = onSaved

        let initialStart = appointment?.startDate ?? defaultStartDate
        let initialEnd = appointment?.endDate

        _title = State(initialValue: appointment?.title ?? "")
        _startDate = State(initialValue: initialStart)
        _includeEndDate = State(initialValue: initialEnd != nil)
        _endDate = State(initialValue: initialEnd ?? initialStart.addingTimeInterval(Appointment.defaultTimedDuration))
        _isAllDay = State(initialValue: appointment?.isAllDay ?? false)
        _location = State(initialValue: appointment?.location ?? "")
        _notes = State(initialValue: appointment?.notes ?? "")
    }

    var body: some View {
        NavigationStack {
            ScreenCanvas(daySeed: startDate) {
                ScrollView {
                    VStack(alignment: .leading, spacing: Theme.Spacing.sm) {
                        titleCard
                        timingCard
                        locationCard
                        notesCard

                        if isSyncedReadOnly {
                            syncedInfoCard
                        }

                        if canDelete {
                            deleteButton
                        }
                    }
                    .padding(Theme.Spacing.md)
                    .padding(.top, Theme.Spacing.lg)
                }
                .scrollIndicators(.hidden)
                .scrollDismissesKeyboard(.interactively)
            }
            .navigationTitle(navigationTitle)
            .navigationBarTitleDisplayMode(.inline)
            .toolbarColorScheme(.light, for: .navigationBar)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") {
                        dismiss()
                    }
                    .tint(Theme.accent)
                }

                ToolbarItem(placement: .confirmationAction) {
                    Button(isSyncedReadOnly ? "Done" : "Save") {
                        isSyncedReadOnly ? dismiss() : save()
                    }
                    .tint(Theme.accent)
                    .disabled(!isSyncedReadOnly && saveDisabled)
                }
            }
            .alert("Delete appointment?", isPresented: $showDeleteConfirmation) {
                Button("Cancel", role: .cancel) {}
                Button("Delete", role: .destructive) {
                    deleteAppointment()
                }
            } message: {
                Text("This only removes it from Synapse.")
            }
            .onChange(of: isAllDay) { _, newValue in
                guard newValue else { return }
                startDate = calendar.startOfDay(for: startDate)
                if includeEndDate {
                    let candidate = calendar.startOfDay(for: endDate)
                    if candidate <= startDate {
                        endDate = calendar.date(byAdding: .day, value: 1, to: startDate) ?? startDate.addingTimeInterval(86_400)
                    } else {
                        endDate = candidate
                    }
                }
            }
            .onChange(of: includeEndDate) { _, include in
                guard include else { return }
                if endDate <= startDate {
                    endDate = defaultEndDate(basedOn: startDate, allDay: isAllDay)
                }
            }
            .onChange(of: startDate) { _, newStart in
                guard includeEndDate, endDate <= newStart else { return }
                endDate = defaultEndDate(basedOn: newStart, allDay: isAllDay)
            }
        }
        .ignoresSafeArea(.keyboard, edges: .bottom)
    }

    private var navigationTitle: String {
        appointment == nil ? "New Appointment" : "Appointment"
    }

    private var isSyncedReadOnly: Bool {
        guard let appointment else { return false }
        return appointment.source != .manual
    }

    private var canDelete: Bool {
        guard let appointment else { return false }
        return appointment.source == .manual
    }

    private var saveDisabled: Bool {
        let trimmedTitle = title.trimmingCharacters(in: .whitespacesAndNewlines)
        if trimmedTitle.isEmpty { return true }
        if includeEndDate && endDate <= startDate { return true }
        return false
    }

    private var titleCard: some View {
        VStack(alignment: .leading, spacing: Theme.Spacing.xs) {
            Text("Title")
                .font(Theme.Typography.bodySmall)
                .foregroundStyle(Theme.textSecondary)

            TextField("Appointment title", text: $title)
                .font(Theme.Typography.bodyMedium)
                .foregroundStyle(Theme.text)
                .textInputAutocapitalization(.sentences)
                .disabled(isSyncedReadOnly)
        }
        .padding(Theme.Spacing.cardInset)
        .surfaceCard(cornerRadius: Theme.radiusSmall)
    }

    private var timingCard: some View {
        VStack(alignment: .leading, spacing: Theme.Spacing.xs) {
            Text("When")
                .font(Theme.Typography.bodySmall)
                .foregroundStyle(Theme.textSecondary)

            Toggle("All day", isOn: $isAllDay)
                .font(Theme.Typography.bodySmallStrong)
                .foregroundStyle(Theme.text)
                .tint(Theme.accent)
                .disabled(isSyncedReadOnly)

            DatePicker(
                "Start",
                selection: $startDate,
                displayedComponents: isAllDay ? [.date] : [.date, .hourAndMinute]
            )
            .datePickerStyle(.compact)
            .disabled(isSyncedReadOnly)

            Toggle("Set end", isOn: $includeEndDate)
                .font(Theme.Typography.bodySmallStrong)
                .foregroundStyle(Theme.text)
                .tint(Theme.accent)
                .disabled(isSyncedReadOnly)

            if includeEndDate {
                DatePicker(
                    "End",
                    selection: $endDate,
                    in: startDate...,
                    displayedComponents: isAllDay ? [.date] : [.date, .hourAndMinute]
                )
                .datePickerStyle(.compact)
                .disabled(isSyncedReadOnly)
            }
        }
        .padding(Theme.Spacing.cardInset)
        .surfaceCard(cornerRadius: Theme.radiusSmall)
    }

    private var locationCard: some View {
        VStack(alignment: .leading, spacing: Theme.Spacing.xs) {
            Text("Location")
                .font(Theme.Typography.bodySmall)
                .foregroundStyle(Theme.textSecondary)

            TextField("Optional", text: $location)
                .font(Theme.Typography.bodyMedium)
                .foregroundStyle(Theme.text)
                .disabled(isSyncedReadOnly)
        }
        .padding(Theme.Spacing.cardInset)
        .surfaceCard(cornerRadius: Theme.radiusSmall)
    }

    private var notesCard: some View {
        VStack(alignment: .leading, spacing: Theme.Spacing.xs) {
            Text("Notes")
                .font(Theme.Typography.bodySmall)
                .foregroundStyle(Theme.textSecondary)

            TextField("Optional", text: $notes, axis: .vertical)
                .font(Theme.Typography.bodySmall)
                .foregroundStyle(Theme.text)
                .lineLimit(4, reservesSpace: true)
                .disabled(isSyncedReadOnly)
        }
        .padding(Theme.Spacing.cardInset)
        .surfaceCard(cornerRadius: Theme.radiusSmall)
    }

    private var syncedInfoCard: some View {
        VStack(alignment: .leading, spacing: Theme.Spacing.xs) {
            Text("Synced event")
                .font(Theme.Typography.bodySmallStrong)
                .foregroundStyle(Theme.text)

            Text("Edit synced appointments from their source calendar.")
                .font(Theme.Typography.caption)
                .foregroundStyle(Theme.textSecondary)
        }
        .padding(Theme.Spacing.cardInset)
        .surfaceCard(style: .secondary, cornerRadius: Theme.radiusSmall)
    }

    private var deleteButton: some View {
        Button {
            showDeleteConfirmation = true
        } label: {
            Text("Delete appointment")
                .font(Theme.Typography.bodySmallStrong)
                .foregroundStyle(.red)
                .frame(maxWidth: .infinity)
                .padding(.vertical, Theme.Spacing.xs)
        }
        .buttonStyle(.plain)
        .padding(Theme.Spacing.cardInset)
        .surfaceCard(style: .secondary, cornerRadius: Theme.radiusSmall)
    }

    private func defaultEndDate(basedOn start: Date, allDay: Bool) -> Date {
        if allDay {
            return calendar.date(byAdding: .day, value: 1, to: calendar.startOfDay(for: start)) ?? start.addingTimeInterval(86_400)
        }
        return start.addingTimeInterval(Appointment.defaultTimedDuration)
    }

    private func save() {
        let trimmedTitle = title.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmedTitle.isEmpty else { return }

        let trimmedLocation = location.trimmingCharacters(in: .whitespacesAndNewlines)
        let trimmedNotes = notes.trimmingCharacters(in: .whitespacesAndNewlines)

        let normalizedStart = isAllDay ? calendar.startOfDay(for: startDate) : startDate
        let normalizedEnd: Date? = {
            guard includeEndDate else { return nil }
            let end = isAllDay ? calendar.startOfDay(for: endDate) : endDate
            return end > normalizedStart ? end : nil
        }()

        if let appointment {
            appointment.title = trimmedTitle
            appointment.startDate = normalizedStart
            appointment.endDate = normalizedEnd
            appointment.isAllDay = isAllDay
            appointment.location = trimmedLocation.isEmpty ? nil : trimmedLocation
            appointment.notes = trimmedNotes.isEmpty ? nil : trimmedNotes
        } else {
            let created = Appointment(
                title: trimmedTitle,
                startDate: normalizedStart,
                endDate: normalizedEnd,
                isAllDay: isAllDay,
                location: trimmedLocation.isEmpty ? nil : trimmedLocation,
                notes: trimmedNotes.isEmpty ? nil : trimmedNotes,
                source: .manual
            )
            modelContext.insert(created)
            onSaved?(created)
        }

        if let appointment {
            onSaved?(appointment)
        }

        try? modelContext.save()
        dismiss()
    }

    private func deleteAppointment() {
        guard let appointment, appointment.source == .manual else { return }
        modelContext.delete(appointment)
        try? modelContext.save()
        dismiss()
    }
}
