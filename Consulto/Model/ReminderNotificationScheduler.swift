import Foundation
import UserNotifications

final class ReminderNotificationScheduler {
    static let shared = ReminderNotificationScheduler()

    private enum Prefix {
        static let medicine = "medicine-reminder-"
        static let consultation = "consultation-reminder-"
    }

    private init() {}

    func requestAuthorizationIfNeeded() {
        UNUserNotificationCenter.current().requestAuthorization(options: [.alert, .sound, .badge]) { granted, _ in
            if granted {
                self.refreshAll()
            }
        }
    }

    func refreshAll() {
        let medicineRequests = buildMedicineRequests(from: MedicationReminderStore.shared.medications)
        let consultationRequests = buildConsultationRequests(from: ConsultationReminderStore.shared.reminders)
        replaceRequests(medicineRequests + consultationRequests)
    }

    func refreshMedicineReminders() {
        let requests = buildMedicineRequests(from: MedicationReminderStore.shared.medications)
        replaceRequests(requests, forPrefixes: [Prefix.medicine])
    }

    func refreshConsultationReminders() {
        let requests = buildConsultationRequests(from: ConsultationReminderStore.shared.reminders)
        replaceRequests(requests, forPrefixes: [Prefix.consultation])
    }

    private func replaceRequests(_ requests: [UNNotificationRequest], forPrefixes prefixes: [String]? = nil) {
        let center = UNUserNotificationCenter.current()
        center.getPendingNotificationRequests { existingRequests in
            let activePrefixes = prefixes ?? [Prefix.medicine, Prefix.consultation]
            let existingIDs = existingRequests
                .map(\.identifier)
                .filter { id in activePrefixes.contains(where: { id.hasPrefix($0) }) }

            center.removePendingNotificationRequests(withIdentifiers: existingIDs)
            center.removeDeliveredNotifications(withIdentifiers: existingIDs)

            for request in requests {
                center.add(request)
            }
        }
    }

    private func buildMedicineRequests(from medications: [Medication]) -> [UNNotificationRequest] {
        medications.flatMap { medication in
            let activeTimes = medication.times.filter { time in
                !medication.inactiveTimes.contains(where: {
                    Calendar.current.isDate($0, equalTo: time, toGranularity: .minute)
                })
            }

            return activeTimes.flatMap { time in
                requestsForMedication(medication, doseTime: time)
            }
        }
    }

    private func requestsForMedication(_ medication: Medication, doseTime: Date) -> [UNNotificationRequest] {
        let content = UNMutableNotificationContent()
        content.title = "Medicine Reminder"
        content.body = medicineBody(for: medication)
        content.sound = .default

        let repeatDays = normalizedWeekdayNumbers(from: medication.repeatDays)
        let calendar = Calendar.current
        let hour = calendar.component(.hour, from: doseTime)
        let minute = calendar.component(.minute, from: doseTime)

        if repeatDays.isEmpty {
            var components = DateComponents()
            components.hour = hour
            components.minute = minute

            let identifier = "\(Prefix.medicine)\(medication.id.uuidString)-daily-\(hour)-\(minute)"
            let trigger = UNCalendarNotificationTrigger(dateMatching: components, repeats: true)
            return [UNNotificationRequest(identifier: identifier, content: content, trigger: trigger)]
        }

        return repeatDays.map { weekday in
            var components = DateComponents()
            components.weekday = weekday
            components.hour = hour
            components.minute = minute

            let identifier = "\(Prefix.medicine)\(medication.id.uuidString)-\(weekday)-\(hour)-\(minute)"
            let trigger = UNCalendarNotificationTrigger(dateMatching: components, repeats: true)
            return UNNotificationRequest(identifier: identifier, content: content, trigger: trigger)
        }
    }

    private func buildConsultationRequests(from reminders: [ConsultationReminder]) -> [UNNotificationRequest] {
        reminders
            .filter { !$0.isPaused }
            .flatMap { reminder in
                requestsForConsultation(reminder)
            }
    }

    private func requestsForConsultation(_ reminder: ConsultationReminder) -> [UNNotificationRequest] {
        let content = UNMutableNotificationContent()
        content.title = "Consultation Reminder"
        content.body = "\(reminder.doctorName) • \(reminder.purpose)"
        content.sound = .default

        let calendar = Calendar.current
        let mergedDate = combine(date: reminder.date, time: reminder.time)
        let hour = calendar.component(.hour, from: mergedDate)
        let minute = calendar.component(.minute, from: mergedDate)
        let repeatDays = normalizedWeekdayNumbers(from: reminder.repeatDays)

        if repeatDays.isEmpty {
            guard mergedDate > Date() else { return [] }
            let components = calendar.dateComponents([.year, .month, .day, .hour, .minute], from: mergedDate)
            let identifier = "\(Prefix.consultation)\(reminder.id.uuidString)-once"
            let trigger = UNCalendarNotificationTrigger(dateMatching: components, repeats: false)
            return [UNNotificationRequest(identifier: identifier, content: content, trigger: trigger)]
        }

        return repeatDays.map { weekday in
            var components = DateComponents()
            components.weekday = weekday
            components.hour = hour
            components.minute = minute

            let identifier = "\(Prefix.consultation)\(reminder.id.uuidString)-\(weekday)-\(hour)-\(minute)"
            let trigger = UNCalendarNotificationTrigger(dateMatching: components, repeats: true)
            return UNNotificationRequest(identifier: identifier, content: content, trigger: trigger)
        }
    }

    private func medicineBody(for medication: Medication) -> String {
        let dosage = medication.dosage?.trimmingCharacters(in: .whitespacesAndNewlines)
        let dosageText = (dosage?.isEmpty == false) ? " (\(dosage!))" : ""
        let mealText: String
        switch medication.mealTiming ?? .afterMeal {
        case .beforeMeal:
            mealText = "Before Meal"
        case .afterMeal:
            mealText = "After Meal"
        case .emptyStomach:
            mealText = "Empty Stomach"
        }
        return "\(medication.name)\(dosageText) • \(mealText)"
    }

    private func normalizedWeekdayNumbers(from rawDays: Set<String>) -> [Int] {
        let mapping: [String: Int] = [
            "Sun": 1, "Sunday": 1,
            "Mon": 2, "Monday": 2,
            "Tue": 3, "Tuesday": 3,
            "Wed": 4, "Wednesday": 4,
            "Thu": 5, "Thursday": 5,
            "Fri": 6, "Friday": 6,
            "Sat": 7, "Saturday": 7
        ]

        if rawDays.contains("Daily") || rawDays.count == 7 {
            return Array(1...7)
        }

        return rawDays.compactMap { mapping[$0] }.sorted()
    }

    private func combine(date: Date, time: Date) -> Date {
        let calendar = Calendar.current
        var components = calendar.dateComponents([.year, .month, .day], from: date)
        let timeComponents = calendar.dateComponents([.hour, .minute], from: time)
        components.hour = timeComponents.hour
        components.minute = timeComponents.minute
        return calendar.date(from: components) ?? date
    }
}
