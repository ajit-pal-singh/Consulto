import Foundation
// Consult Detailed View - Sample Data
struct ConsultSessionDataModel {
    static func sampleSessionTitle() -> String {
        return "High BP & Dizziness"
    }

    static func sampleSymptoms() -> [Symptom] {
        return [
            Symptom(
                name: "Headache",
                description: "Persistent pain in the head, especially in the morning. Continuous for at least one week. Not able to sleep properly at night.",
                isExpanded: false
            ),
            Symptom(
                name: "Dizziness",
                description: "Feeling light-headed or unsteady while standing. Can't stand and work for more than half an hour.",
                isExpanded: false
            ),
            Symptom(
                name: "Shortness of Breath",
                description: "Breathlessness during physical activity or exercise.",
                isExpanded: false
            )
        ]
    }

    static func sampleMedications() -> [Medication] {
        return [
            Medication(id: UUID(), recordID: UUID(), name: "Amlodipine", dosage: "5 mg", frequency: .twiceDaily, duration: "From Last 3 Months", notes: nil),
            Medication(id: UUID(), recordID: UUID(), name: "Metformin", dosage: "500 mg", frequency: .twiceDaily, duration: "From Last 3 Months", notes: nil),
            Medication(id: UUID(), recordID: UUID(), name: "Rosuvastatin", dosage: "10 mg", frequency: .onceDaily, duration: "From Last 2 Weeks", notes: nil),
            Medication(id: UUID(), recordID: UUID(), name: "Pantoprazole", dosage: "40 mg", frequency: .onceDaily, duration: "From Last 3 Weeks", notes: nil)
        ]
    }

    static func sampleRecords() -> [HealthRecord] {

        var records: [HealthRecord] = []
        let titles = ["ECG Report", "Lipid Profile", "HbA1c Test"]
        let facilities = ["Tata 1mg", "BioLabs Centre", "Dr. Lal PathLabs"]
        let types: [RecordType] = [.labReport]
        let summaries = [
            "Referred By: Dr. Sharma, Sample Type: ECG/Non-Blood",
            "Referred By: Dr. Mehnat, Sample Type: Blood",
            "Referred By: Dr. Kapoor, Sample Type: HbA1c Blood Test"
        ]
        let dates: [Date] = [
            Date().addingTimeInterval(-86_400 * 3),
            Date().addingTimeInterval(-86_400 * 2),
            Date().addingTimeInterval(-86_400)
        ]
        for i in 0..<titles.count {
            let record = HealthRecord(
                id: UUID(),
                userID: UUID(),
                title: titles[i],
                recordType: types[i % types.count],
                healthFacilityName: facilities[i],
                summary: summaries[i],
                dateAdded: dates[i],
                documentDate: dates[i],
                files: [],
                extractedData: nil
            )
            records.append(record)
        }
        return records
    }
    
    static func sampleQuestions() -> [Question] {
        return [
            Question(text: "Are these symptoms related to my fluctuating blood pressure?", isSelected: true),
            Question(text: "Do I need to adjust my current BP medication?", isSelected: true),
            Question(text: "Are these palpitations something serious?", isSelected: false),
            Question(text: "Should I get tests done?", isSelected: false)
        ]
    }
}

