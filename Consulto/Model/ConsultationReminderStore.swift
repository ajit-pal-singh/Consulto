import Foundation

final class ConsultationReminderStore {
    static let shared = ConsultationReminderStore()

    var reminders: [ConsultationReminder]

    private init() {
        reminders = SampleData.consultationReminders
    }

    @discardableResult
    func addReminder(
        doctorName: String,
        purpose: String,
        consultationDate: Date,
        time: Date,
        repeatDays: Set<String> = [],
        isSnoozeOn: Bool = false,
        snoozeTime: String? = nil,
        isPaused: Bool = false
    ) -> ConsultationReminder {
        let reminder = ConsultationReminder(
            id: UUID(),
            doctorName: doctorName,
            purpose: purpose,
            date: consultationDate,
            time: time,
            repeatDays: repeatDays,
            isSnoozeOn: isSnoozeOn,
            snoozeTime: snoozeTime,
            isPaused: isPaused
        )

        reminders.insert(reminder, at: 0)
        return reminder
    }
}
