import Foundation

final class ConsultationReminderStore {
    static let shared = ConsultationReminderStore()

    private let storageKey = "ConsultationReminderStore.reminders"

    var reminders: [ConsultationReminder] {
        didSet {
            save()
            ReminderNotificationScheduler.shared.refreshConsultationReminders()
        }
    }

    private init() {
        reminders = Self.load() ?? []
        save()
    }

    func notifyRemindersChanged() {
        ReminderNotificationScheduler.shared.refreshConsultationReminders()
        NotificationCenter.default.post(
            name: NSNotification.Name("ConsultationReminderUpdated"),
            object: nil
        )
    }

    @discardableResult
    func addReminder(
        consultSessionID: UUID? = nil,
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
            consultSessionID: consultSessionID,
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

    func reminder(forSessionID sessionID: UUID) -> ConsultationReminder? {
        reminders.first(where: { $0.consultSessionID == sessionID })
    }

    func updateReminder(
        id: UUID,
        consultSessionID: UUID? = nil,
        doctorName: String,
        purpose: String,
        consultationDate: Date,
        time: Date,
        repeatDays: Set<String>,
        isSnoozeOn: Bool,
        snoozeTime: String?,
        isPaused: Bool
    ) -> ConsultationReminder? {
        guard let index = reminders.firstIndex(where: { $0.id == id }) else { return nil }

        reminders[index].doctorName = doctorName
        reminders[index].purpose = purpose
        reminders[index].consultSessionID = consultSessionID ?? reminders[index].consultSessionID
        reminders[index].date = consultationDate
        reminders[index].time = time
        reminders[index].repeatDays = repeatDays
        reminders[index].isSnoozeOn = isSnoozeOn
        reminders[index].snoozeTime = snoozeTime
        reminders[index].isPaused = isPaused

        return reminders[index]
    }

    func removeReminder(id: UUID) {
        reminders.removeAll { $0.id == id }
    }

    private static func load() -> [ConsultationReminder]? {
        guard let data = UserDefaults.standard.data(forKey: "ConsultationReminderStore.reminders") else {
            return nil
        }

        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        return try? decoder.decode([ConsultationReminder].self, from: data)
    }

    private func save() {
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        if let data = try? encoder.encode(reminders) {
            UserDefaults.standard.set(data, forKey: storageKey)
        }
    }
}
