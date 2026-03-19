import Foundation

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

struct HealthRecord {
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

struct RecordFile {
    let filePath: String
    let fileType: FileType
}

struct ExtractedMedicalData {
    let medications: [Medication]?
    let followUpDate: Date?
}

enum RecordType: String {
    case prescription
    case labReport
    case scan
    case dischargeSummary
    case other
}

enum FileType: String {
    case image
    case pdf
}

// MARK: - Medication

struct Medication {
    let id: UUID
    let recordID: UUID
    var name: String
    var dosage: String?
    var frequency: MedicationFrequency?
    var duration: String?
    var notes: String?
}

enum MedicationFrequency: String {
    case onceDaily
    case twiceDaily
    case thriceDaily
    case asNeeded
}

// MARK: - Consult

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

enum ConsultStatus: String {
    case pending
    case completed
}
