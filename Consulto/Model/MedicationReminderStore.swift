import Foundation

/// Shared source of truth for medicine reminders (same data shown in Reminders → Current Medicines and Home).
final class MedicationReminderStore {
    static let shared = MedicationReminderStore()

    var medications: [Medication]

    private init() {
        medications = SampleData.reminders
    }

    func notifyMedicinesChanged() {
        MedicineStore.shared.syncFromMedications(medications)
        ReminderNotificationScheduler.shared.refreshMedicineReminders()
        NotificationCenter.default.post(
            name: NSNotification.Name("MedicineUpdated"),
            object: nil
        )
    }
}
