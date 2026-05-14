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
            medications = Self.removingLegacySampleMedications(from: saved)
            if medications.count != saved.count {
                save()
            }
        } else {
            medications = []
            save()
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

    private static func removingLegacySampleMedications(from medications: [Medication]) -> [Medication] {
        let legacyNames = Set(["glimepiride", "paracetamol", "ibuprofen", "combiflam"])
        return medications.filter { medication in
            let name = medication.name.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
            guard legacyNames.contains(name) else { return true }

            return medication.dosage != nil
                || medication.frequency != nil
                || medication.duration != nil
                || medication.notes != nil
        }
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
