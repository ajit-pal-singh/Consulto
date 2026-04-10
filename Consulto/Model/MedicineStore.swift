import Foundation
import CryptoKit

struct Medicine: Equatable {
    let rowId: UUID
    let medicationId: UUID
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

    func syncFromMedications(_ medications: [Medication]) {
        let timeFormatter = DateFormatter()
        timeFormatter.dateFormat = "h:mm a"

        let oldKeysToDone: [String: Bool] = Dictionary(uniqueKeysWithValues: medicines.map {
            (doseKey(medicationId: $0.medicationId, doseTime: $0.doseTime), $0.isDone)
        })

        var newRows: [Medicine] = []

        for med in medications {
            let activeTimes = activeTimes(for: med).sorted()
            for dose in activeTimes {
                let key = doseKey(medicationId: med.id, doseTime: dose)
                let isDone = oldKeysToDone[key] ?? false

                newRows.append(
                    Medicine(
                        rowId: stableRowId(medicationId: med.id, doseTime: dose),
                        medicationId: med.id,
                        doseTime: dose,
                        name: med.name,
                        dosage: med.dosage ?? "",
                        time: timeFormatter.string(from: dose),
                        mealTime: mealText(med.mealTiming ?? .afterMeal),
                        isSnoozeOn: med.isSnoozeOn,
                        isDone: isDone
                    )
                )
            }
        }

        medicines = newRows
        sortMedicinesForHomeDisplay()
    }

    func toggleDone(rowId: UUID) {
        guard let idx = medicines.firstIndex(where: { $0.rowId == rowId }) else { return }
        medicines[idx].isDone.toggle()
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

    private func doseKey(medicationId: UUID, doseTime: Date) -> String {
        "\(medicationId.uuidString)|\(Int(doseTime.timeIntervalSinceReferenceDate / 60))"
    }

    private func stableRowId(medicationId: UUID, doseTime: Date) -> UUID {
        let key = "\(medicationId.uuidString)|\(Int(doseTime.timeIntervalSinceReferenceDate / 60))"
        let digest = Insecure.MD5.hash(data: Data(key.utf8))
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
}
