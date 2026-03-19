import Foundation

// Consult View -  Sample Data
struct SampleData {
    static let user = UserProfile(
        id: UUID(),
        fullName: "Harsh Mittal",
        dateOfBirth: Calendar.current.date(from: DateComponents(year: 1998, month: 11, day: 3))!,
        gender: .male,
        createdAt: Date(),
        lastModifiedAt: Date()
    )

    static let medications: [Medication] = [
        Medication(
            id: UUID(),
            recordID: UUID(),
            name: "Amoxicillin",
            dosage: "250 mg",
            frequency: .thriceDaily,
            duration: "From last 7 days",
            notes: "Before meals"
        ),
        Medication(
            id: UUID(),
            recordID: UUID(),
            name: "Diclofenac",
            dosage: "50 mg",
            frequency: .twiceDaily,
            duration: "From last 5 days",
            notes: "With water"
        )
    ]

    static let symptoms: [Symptom] = [
        Symptom(name: "Headache", description: "Persistent pain in the head, especially in the morning. Continuous for at least one week. Not able to sleep properly at night.", isExpanded: false),
        Symptom(name: "Nausea", description: "Uneasy feeling with urge to vomit. Food seems tasteless.", isExpanded: false),
        Symptom(name: "Fatigue", description: "Persistent tiredness despite rest. Feeling light-headed or unsteady while standing.", isExpanded: false),
    ]

    static let questions: [Question] = [
        Question(text: "Is this related to dehydration?", isSelected: true),
        Question(text: "Should I adjust my sleep schedule?", isSelected: false),
        Question(text: "Do I need further blood tests?", isSelected: false)
    ]

    static let records: [HealthRecord] = [
        HealthRecord(
            id: UUID(),
            userID: user.id,
            title: "General Physician Note",
            recordType: .prescription,
            healthFacilityName: "Green Valley Clinic",
            summary: "Advice for headache and fatigue management",
            dateAdded: Date(),
            documentDate: Calendar.current.date(byAdding: .day, value: -5, to: Date()),
            files: [
                RecordFile(filePath: "gp_note_2026.pdf", fileType: .pdf)
            ],
            extractedData: ExtractedMedicalData(
                medications: medications,
                followUpDate: Calendar.current.date(byAdding: .day, value: 10, to: Date())
            )
        )
    ]

    static let consultSessions: [ConsultSession] = [
        ConsultSession(
            id: UUID(),
            userID: user.id,
            doctorName: "Dr. Sandeep Gupta",
            title: "Initial GP Visit",
            date: Calendar.current.date(byAdding: .day, value: -30, to: Date())!,
            symptoms: [
                Symptom(name: "Headache", description: "Persistent pain in the head, especially in the morning. Continuous for at least one week. Not able to sleep properly at night.", isExpanded: false),
                Symptom(name: "Nausea", description: "Uneasy feeling with urge to vomit. Food seems tasteless.", isExpanded: false),
                Symptom(name: "Photophobia", description: "Light sensitivity during episodes.", isExpanded: false),
            ],
            questions: [
                Question(text: "Is this related to dehydration?", isSelected: false),
                Question(text: "Should I reduce caffeine?", isSelected: false),
                Question(text: "Is this related to dehydration?", isSelected: false),
                Question(text: "Should I reduce caffeine?", isSelected: false)
            ],
            medications: [
                Medication(id: UUID(), recordID: UUID(), name: "Amoxicillin", dosage: "250 mg", frequency: .thriceDaily, duration: "From last 7 days", notes: "Before meals")
            ],
            records: records,
            notes: "Hydration plan and 20-20-20 rule advised.",
            status: .completed,
            createdAt: Calendar.current.date(byAdding: .day, value: -30, to: Date())!
        ),
        ConsultSession(
            id: UUID(),
            userID: user.id,
            doctorName: "Dr. Vijay Sinha",
            title: "Dietary Review",
            date: Calendar.current.date(byAdding: .day, value: -20, to: Date())!,
            symptoms: [
                Symptom(name: "Fatigue", description: "Low energy through the afternoon.", isExpanded: false),
                Symptom(name: "Craving", description: "Sugar cravings after lunch.", isExpanded: false),
                Symptom(name: "Bloating", description: "Fullness after heavy meals.", isExpanded: false),
                Symptom(name: "Irritability", description: "Short temper when hungry.", isExpanded: false)
            ],
            questions: [
                Question(text: "Should I adjust my sleep schedule?", isSelected: false)
            ],
            medications: [
                Medication(id: UUID(), recordID: UUID(), name: "Diclofenac", dosage: "50 mg", frequency: .twiceDaily, duration: "From last 5 days", notes: "With water")
            ],
            records: records,
            notes: "Recommended balanced macros and fiber.",
            status: .completed,
            createdAt: Calendar.current.date(byAdding: .day, value: -20, to: Date())!
        ),
        ConsultSession(
            id: UUID(),
            userID: user.id,
            doctorName: "Dr. Anupam Jain",
            title: "Sleep Hygiene Check",
            date: Calendar.current.date(byAdding: .day, value: -12, to: Date())!,
            symptoms: [
                Symptom(name: "Insomnia", description: "Difficulty falling asleep.", isExpanded: false),
                Symptom(name: "Restlessness", description: "Frequent nighttime awakenings.", isExpanded: false),
                Symptom(name: "Dreaminess", description: "Vivid dreams near morning.", isExpanded: false),
                Symptom(name: "DryMouth", description: "Wakes up with dry mouth.", isExpanded: false),
                Symptom(name: "Snoring", description: "Reported by partner.", isExpanded: false)
            ],
            questions: [
                Question(text: "Do I need further blood tests?", isSelected: false)
            ],
            medications: [],
            records: [],
            notes: "Set consistent bedtime and limit screens.",
            status: .completed,
            createdAt: Calendar.current.date(byAdding: .day, value: -12, to: Date())!
        ),
        ConsultSession(
            id: UUID(),
            userID: user.id,
            doctorName: "Dr. Sandeep Gupta",
            title: "Follow-up: Headache Control",
            date: Calendar.current.date(byAdding: .day, value: -5, to: Date())!,
            symptoms: [
                Symptom(name: "Headache", description: "Less frequent, intensity 3/10.", isExpanded: false),
                Symptom(name: "Photophobia", description: "Occurs only with bright sun.", isExpanded: false),
                Symptom(name: "Tension", description: "Neck tightness late evening.", isExpanded: false)
            ],
            questions: [
                Question(text: "Can I resume workouts?", isSelected: false)
            ],
            medications: [],
            records: records,
            notes: "Continue hydration and posture checks.",
            status: .completed,
            createdAt: Calendar.current.date(byAdding: .day, value: -5, to: Date())!
        ),
        ConsultSession(
            id: UUID(),
            userID: user.id,
            doctorName: "Dr. Rohan Verma",
            title: "Current Session: Wellness Review",
            date: Date(),
            symptoms: [
                Symptom(name: "Fatigue", description: "Mild slump after 3 PM.", isExpanded: false),
                Symptom(name: "Headache", description: "Brief ache after long calls.", isExpanded: false),
                Symptom(name: "DryMouth", description: "Forgets to sip water.", isExpanded: false),
                Symptom(name: "Anxiety", description: "Work deadlines causing stress.", isExpanded: false)
            ],
            questions: [
                Question(text: "Any red flags to watch?", isSelected: false),
                Question(text: "Should I try magnesium?", isSelected: false)
            ],
            medications: medications,
            records: records,
            notes: "Introduce micro-breaks and short walks.",
            status: .pending,
            createdAt: Date()
        )
    ]
    
    static func getSampleRecords() -> [HealthRecord] {
        var records: [HealthRecord] = []

        let titles = [
            "Dr. Sharma", "Full Body Test", "Gastroenteritis",
            "Dr. Kapoor", "Dr. Bansal", "Thyroid Test",
            "Minor Surgery", "Vaccination", "Eye Checkup",
            "Dental Clean", "MRI Scan", "Blood Test"
        ]

        let facilities = [
            "Apollo Clinic", "Tata 1mg", "Max Healthcare",
            "CityCare Clinic", "Medlife Hospital", "SRL Diagnostics",
            "City Hospital", "Fortis Health", "Vasan Eye Care",
            "Clove Dental", "Mahajan Imaging", "Dr. Lal PathLabs"
        ]

        let types: [RecordType] = [
            .prescription, .labReport, .dischargeSummary,
            .prescription, .prescription, .labReport,
            .dischargeSummary, .other, .prescription,
            .other, .scan, .labReport
        ]

        let summaries = [
            "Diagnosis: Gut infection confirmed after clinical evaluation. Prescription includes ORS solution and Pantoprazole for symptomatic relief. Patient advised hydration and bland diet.",
            "Tests performed: CBC, Blood Sugar, and Lipid profile. Results show high hemoglobin and low HDL requiring lifestyle changes. Follow-up testing recommended in four weeks.",
            "Summary: Patient received IV fluids with steady recovery status. Observation period completed without complications. Follow-up advised after ten days for reassessment.",
            "Diagnosis: Seasonal flu based on symptoms and exam. Prescription includes Vitamin C supplementation and steam inhalation. Rest and hydration strongly recommended.",
            "Diagnosis: Migraine with episodic headaches. Prescription includes Naproxen and trigger avoidance counseling. Stress management and sleep hygiene discussed.",
            "Tests ordered: T3, T4, and TSH for thyroid evaluation. Results indicate mild hypothyroidism consistent with symptoms. Endocrinology follow-up and medication titration planned.",
            "Surgery performed: Cyst removal with no intraoperative issues. Postoperative course was stable with clean wound margins. Patient discharged with recovery instructions.",
            "Vaccine administered: Hepatitis B third dose completed. Immunization schedule is now up to date. No adverse reactions observed post vaccination.",
            "Vision assessment: 6/6 in both eyes with normal ocular health. Prescription provided for lubricating eye drops as needed. Routine checkup advised annually.",
            "Dental procedure completed: Scaling and polishing performed. Oral hygiene instructions provided with flossing guidance. Follow-up cleaning recommended in six months.",
            "Imaging region: Lumbar spine MRI reviewed thoroughly. Findings suggest mild slip disc without nerve compression. Conservative management and physiotherapy advised.",
            "Tests performed: Vitamin D and B12 levels measured. Results indicate deficiencies requiring supplementation. Diet modifications and sunlight exposure recommended."
        ]

        let now = Date()
        let calendar = Calendar.current

        for i in 0..<titles.count {
            let record = HealthRecord(
                id: UUID(),
                userID: UUID(),
                title: titles[i],
                recordType: types[i],
                healthFacilityName: facilities[i],
                summary: summaries[i],
                dateAdded: calendar.date(byAdding: .day, value: -i*15, to: now)!,
                documentDate: calendar.date(byAdding: .day, value: -i*15, to: now)!,
                files: [],
                extractedData: nil
            )
            records.append(record)
        }

        return records
    }

}
