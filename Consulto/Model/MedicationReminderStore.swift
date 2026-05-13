import Foundation

/// Shared source of truth for medicine reminders (same data shown in Reminders → Current Medicines and Home).
final class MedicationReminderStore {
    static let shared = MedicationReminderStore()

    private let storageKey = "MedicationReminderStore.medications"

    /// Reading loads from disk; writing saves to disk automatically.
    var medications: [Medication] {
        didSet { save() }
    }

    private init() {
        if let saved = Self.load() {
            medications = saved
        } else {
            // First launch — bootstrap from sample data and persist it immediately
            medications = SampleData.reminders
            let encoder = JSONEncoder()
            encoder.dateEncodingStrategy = .iso8601
            if let data = try? encoder.encode(medications) {
                UserDefaults.standard.set(data, forKey: "MedicationReminderStore.medications")
            }
        }
    }

    // MARK: - Persistence

    private static func load() -> [Medication]? {
        guard let data = UserDefaults.standard.data(forKey: "MedicationReminderStore.medications") else {
            return nil
        }
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        return try? decoder.decode([Medication].self, from: data)
    }

    private func save() {
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        if let data = try? encoder.encode(medications) {
            UserDefaults.standard.set(data, forKey: storageKey)
        }
    }

    // MARK: - Notifications

    func notifyMedicinesChanged() {
        MedicineStore.shared.syncFromMedications(medications)
        ReminderNotificationScheduler.shared.refreshMedicineReminders()
        NotificationCenter.default.post(
            name: NSNotification.Name("MedicineUpdated"),
            object: nil
        )
    }
}
