import Foundation
import FoundationModels

// MARK: - User

struct UserProfile {
    let id: UUID
    var firstName: String
    var lastName: String
    var dateOfBirth: Date
    var gender: Gender
    var createdAt: Date
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
    var mealTiming: MealTiming?
    var repeatDays: Set<String> = []
    var isSnoozeOn: Bool = false
    var snoozeTime: String?
    var inactiveTimes: [Date] = []
    var reminderCreatedAt: Date? = nil
    var isDone: Bool = false

    private enum CodingKeys: String, CodingKey {
        case id, recordID, name, dosage, frequency, duration, notes
        case times, mealTiming, repeatDays, isSnoozeOn, snoozeTime, inactiveTimes
        case reminderCreatedAt, isDone
    }

    init(id: UUID, recordID: UUID?, name: String, dosage: String? = nil,
         frequency: MedicationFrequency? = nil, duration: String? = nil, notes: String? = nil,
         times: [Date] = [], mealTiming: MealTiming? = nil, repeatDays: Set<String> = [],
         isSnoozeOn: Bool = false, snoozeTime: String? = nil, inactiveTimes: [Date] = [],
         reminderCreatedAt: Date? = nil, isDone: Bool = false) {
        self.id = id
        self.recordID = recordID
        self.name = name
        self.dosage = dosage
        self.frequency = frequency
        self.duration = duration
        self.notes = notes
        self.times = times
        self.mealTiming = mealTiming
        self.repeatDays = repeatDays
        self.isSnoozeOn = isSnoozeOn
        self.snoozeTime = snoozeTime
        self.inactiveTimes = inactiveTimes
        self.reminderCreatedAt = reminderCreatedAt
        self.isDone = isDone
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = try container.decode(UUID.self, forKey: .id)
        recordID = try container.decodeIfPresent(UUID.self, forKey: .recordID)
        name = try container.decode(String.self, forKey: .name)
        dosage = try container.decodeIfPresent(String.self, forKey: .dosage)
        frequency = try container.decodeIfPresent(MedicationFrequency.self, forKey: .frequency)
        duration = try container.decodeIfPresent(String.self, forKey: .duration)
        notes = try container.decodeIfPresent(String.self, forKey: .notes)
        times = try container.decodeIfPresent([Date].self, forKey: .times) ?? []
        mealTiming = try container.decodeIfPresent(MealTiming.self, forKey: .mealTiming)
        repeatDays = try container.decodeIfPresent(Set<String>.self, forKey: .repeatDays) ?? []
        isSnoozeOn = try container.decodeIfPresent(Bool.self, forKey: .isSnoozeOn) ?? false
        snoozeTime = try container.decodeIfPresent(String.self, forKey: .snoozeTime)
        inactiveTimes = try container.decodeIfPresent([Date].self, forKey: .inactiveTimes) ?? []
        reminderCreatedAt = try container.decodeIfPresent(Date.self, forKey: .reminderCreatedAt)
        isDone = try container.decodeIfPresent(Bool.self, forKey: .isDone) ?? false
    }
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
}

enum SnoozeTime: String, CaseIterable, Codable {
    case five = "5 mins"
    case ten = "10 mins"
    case fifteen = "15 mins"
    case thirty = "30 mins"
}

// MARK: - Consult

struct ConsultSession: Codable {
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

struct Question: Codable {
    var text: String
    var isSelected: Bool

    private enum CodingKeys: String, CodingKey {
        case text
    }

    init(text: String, isSelected: Bool = false) {
        self.text = text
        self.isSelected = isSelected
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        text = try container.decode(String.self, forKey: .text)
        isSelected = false
    }
}

struct Symptom: Codable {
    var name: String
    var description: String
    var isExpanded: Bool

    private enum CodingKeys: String, CodingKey {
        case name, description
    }

    init(name: String, description: String, isExpanded: Bool = false) {
        self.name = name
        self.description = description
        self.isExpanded = isExpanded
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        name = try container.decode(String.self, forKey: .name)
        description = try container.decode(String.self, forKey: .description)
        isExpanded = false
    }
}

enum ConsultStatus: String, Codable {
    case pending
    case completed
}

struct ConsultationReminder {
    let id: UUID
    var consultSessionID: UUID?
    var doctorName: String
    var purpose: String
    var date: Date
    var time: Date
    var repeatDays: Set<String>
    var isSnoozeOn: Bool
    var snoozeTime: String?
    var isPaused: Bool
}


