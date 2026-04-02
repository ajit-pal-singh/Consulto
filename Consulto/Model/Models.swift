import Foundation
import FoundationModels

// MARK: - User

struct UserProfile {
    let id: UUID

    var fullName: String
    var dateOfBirth: Date
    var gender: Gender

    var createdAt: Date
    var lastModifiedAt: Date
}

enum Gender: String {
    case male
    case female
    case preferNotToSay
}

// MARK: - Health Records

struct HealthRecord: Codable {
    let id: UUID
    var userID: UUID

    let title: String
    let recordType: RecordType
    let healthFacilityName: String?
    let summary: String?

    let dateAdded: Date
    let documentDate: Date?

    let files: [RecordFile]
    let extractedData: ExtractedMedicalData?
}

struct RecordFile: Codable {
    let filePath: String
    let fileType: FileType
}

struct ExtractedMedicalData: Codable {
    let medications: [Medication]?
    let followUpDate: Date?
}

@Generable
enum RecordType: String, Codable {
    case prescription
    case labReport
    case scan
    case dischargeSummary
    case other
}

enum FileType: String, Codable {
    case image
    case pdf
}

extension RecordType {
    var displayName: String {
        switch self {
        case .prescription: return "Prescription"
        case .labReport: return "Lab Report"
        case .scan: return "Scan"
        case .dischargeSummary: return "Discharge Summary"
        case .other: return "Other"
        }
    }

    static func fromDisplayName(_ value: String) -> RecordType? {
        switch value.trimmingCharacters(in: .whitespacesAndNewlines).lowercased() {
        case "prescription":
            return .prescription
        case "lab report":
            return .labReport
        case "scan":
            return .scan
        case "discharge summary", "discharge":
            return .dischargeSummary
        case "other":
            return .other
        default:
            return nil
        }
    }
}

// MARK: - Medication

struct Medication: Codable {
    let id: UUID
    let recordID: UUID?
    var name: String
    var dosage: String?
    var frequency: MedicationFrequency?
    var duration: String?
    var notes: String?
    
    //For reminders
    var times: [Date] = []
    var mealTiming: MealTiming = .none
    var repeatDays: Set<String> = []
    var isSnoozeOn: Bool = false
    var snoozeTime: String?
    var inactiveTimes: [Date] = []
}

enum MedicationFrequency: String, Codable {
    case onceDaily
    case twiceDaily
    case thriceDaily
    case asNeeded
}

enum MealTiming: String, Codable {
    case beforeMeal
    case afterMeal
    case emptyStomach
    case none
}

enum SnoozeTime: String, CaseIterable, Codable {
    case five = "5 mins"
    case ten = "10 mins"
    case fifteen = "15 mins"
    case thirty = "30 mins"
}

// MARK: - Consult

struct ConsultSession {
    let id: UUID
    let userID: UUID

    var doctorName: String
    var title: String
    var date: Date

    var symptoms: [Symptom]
    var questions: [Question]
    var medications: [Medication]
    var records: [HealthRecord]
    
    var symptomsCount: Int {
        return symptoms.count
    }
    var questionsCount: Int {
        return questions.count
    }

    var notes: String?
    var status: ConsultStatus
    var createdAt: Date
}

struct Question {
    var text: String
    var isSelected: Bool
}

struct Symptom {
    var name: String
    var description: String
    var isExpanded: Bool
}

enum ConsultStatus: String, Codable {
    case pending
    case completed
}

struct ConsultationReminder {
    let id: UUID
    var doctorName: String
    var purpose: String
    var date: Date
    var time: Date
    var repeatDays: Set<String>
    var isSnoozeOn: Bool
    var snoozeTime: String?
    var isPaused: Bool
}
