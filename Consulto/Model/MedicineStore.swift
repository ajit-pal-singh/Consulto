import Foundation
import CryptoKit

struct Medicine: Equatable {
    let rowId: UUID
    let medicationId: UUID
    let completionId: String
    let doseTime: Date
    let name: String
    let dosage: String
    let time: String
    let mealTime: String
    var isSnoozeOn: Bool
    var isDone: Bool
}

class MedicineStore {
    static let shared = MedicineStore()
    private init() {}

    private(set) var medicines: [Medicine] = []

    private let completedDoseIdsStoreKey = "completedDoseIds"
    private let completedDoseDateStoreKey = "completedDoseDate"

    func syncFromMedications(_ medications: [Medication]) {
        resetCompletedDosesIfNeeded()
        let completedDoseIds = loadCompletedDoseIds()

        let timeFormatter = DateFormatter()
        timeFormatter.dateFormat = "h:mm a"

        var newRows: [Medicine] = []

        for med in medications {
            let activeTimes = activeTimes(for: med).sorted()
            for dose in activeTimes {
                let completionId = makeCompletionId(for: med, doseTime: dose)

                newRows.append(
                    Medicine(
                        rowId: stableRowId(from: completionId),
                        medicationId: med.id,
                        completionId: completionId,
                        doseTime: dose,
                        name: med.name,
                        dosage: med.dosage ?? "",
                        time: timeFormatter.string(from: dose),
                        mealTime: mealText(med.mealTiming ?? .afterMeal),
                        isSnoozeOn: med.isSnoozeOn,
                        isDone: completedDoseIds.contains(completionId)
                    )
                )
            }
        }

        medicines = newRows
        sortMedicinesForHomeDisplay()
    }

    func toggleDone(rowId: UUID) {
        guard let idx = medicines.firstIndex(where: { $0.rowId == rowId }) else { return }
        let completionId = medicines[idx].completionId
        var completedDoseIds = loadCompletedDoseIds()

        if medicines[idx].isDone {
            completedDoseIds.remove(completionId)
        } else {
            completedDoseIds.insert(completionId)
        }

        saveCompletedDoseIds(completedDoseIds)
        medicines[idx].isDone.toggle()
        sortMedicinesForHomeDisplay()
    }

    func refreshForCurrentDay() {
        resetCompletedDosesIfNeeded()
        let completedDoseIds = loadCompletedDoseIds()
        for index in medicines.indices {
            medicines[index].isDone = completedDoseIds.contains(medicines[index].completionId)
        }
        sortMedicinesForHomeDisplay()
    }

    private func sortMedicinesForHomeDisplay() {
        medicines.sort { a, b in
            if a.isDone != b.isDone {
                return !a.isDone && b.isDone
            }

            let calendar = Calendar.current
            let aComponents = calendar.dateComponents([.hour, .minute], from: a.doseTime)
            let bComponents = calendar.dateComponents([.hour, .minute], from: b.doseTime)
            let aMinuteOfDay = (aComponents.hour ?? 0) * 60 + (aComponents.minute ?? 0)
            let bMinuteOfDay = (bComponents.hour ?? 0) * 60 + (bComponents.minute ?? 0)

            if aMinuteOfDay != bMinuteOfDay {
                return aMinuteOfDay < bMinuteOfDay
            }
            return a.name.localizedCaseInsensitiveCompare(b.name) == .orderedAscending
        }
    }

    private func stableRowId(from value: String) -> UUID {
        let digest = Insecure.MD5.hash(data: Data(value.utf8))
        let b = Array(digest.prefix(16))
        return UUID(uuid: (b[0], b[1], b[2], b[3], b[4], b[5], b[6], b[7], b[8], b[9], b[10], b[11], b[12], b[13], b[14], b[15]))
    }

    private func activeTimes(for medication: Medication) -> [Date] {
        medication.times.filter { time in
            !medication.inactiveTimes.contains(where: {
                Calendar.current.isDate($0, equalTo: time, toGranularity: .minute)
            })
        }
    }

    private func mealText(_ timing: MealTiming) -> String {
        switch timing {
        case .beforeMeal: return "Before Meal"
        case .afterMeal: return "After Meal"
        case .emptyStomach: return "Empty Stomach"
        }
    }

    private func makeCompletionId(for medication: Medication, doseTime: Date) -> String {
        let calendar = Calendar.current
        let components = calendar.dateComponents([.hour, .minute], from: doseTime)
        let minuteOfDay = ((components.hour ?? 0) * 60) + (components.minute ?? 0)

        return [
            clean(medication.name),
            clean(medication.dosage ?? ""),
            medication.mealTiming?.rawValue ?? "afterMeal",
            "\(minuteOfDay)"
        ].joined(separator: "|")
    }

    private func clean(_ value: String) -> String {
        value
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .lowercased()
            .replacingOccurrences(of: "\\s+", with: " ", options: .regularExpression)
    }

    private func loadCompletedDoseIds() -> Set<String> {
        Set(UserDefaults.standard.stringArray(forKey: completedDoseIdsStoreKey) ?? [])
    }

    private func saveCompletedDoseIds(_ ids: Set<String>) {
        UserDefaults.standard.set(Array(ids), forKey: completedDoseIdsStoreKey)
        UserDefaults.standard.set(todayKey(), forKey: completedDoseDateStoreKey)
    }

    private func resetCompletedDosesIfNeeded() {
        guard UserDefaults.standard.string(forKey: completedDoseDateStoreKey) != todayKey() else {
            return
        }

        UserDefaults.standard.removeObject(forKey: completedDoseIdsStoreKey)
        UserDefaults.standard.set(todayKey(), forKey: completedDoseDateStoreKey)
    }

    private func todayKey() -> String {
        let components = Calendar.current.dateComponents([.year, .month, .day], from: Date())
        let year = components.year ?? 0
        let month = components.month ?? 0
        let day = components.day ?? 0
        return String(format: "%04d-%02d-%02d", year, month, day)
    }
}
