import UIKit

class PrepareConsultationTableViewController: UITableViewController {
    
    var sessionTitle: String = ""
    var doctorName: String = "Dr. "
    var pastDoctorNames: [String] = []
    var sessionDate: Date = Date()
    var reminderTime: Date?
    var isConsultationReminderOn = false
    var symptoms: [Symptom] = []
    var medications: [Medication] = []
    var records: [HealthRecord] = []
    var questions: [Question] = []
    var notes: String = ""
    var hasSelectedDate: Bool = false
    var existingSessionID: UUID?
    var existingUserID: UUID?
    var existingCreatedAt: Date?
    private var linkedConsultationReminderID: UUID?
    private var hasReviewedMedicationSelection = false

    override func viewDidLoad() {
        super.viewDidLoad()
        
        pastDoctorNames = Array(Set(ConsultSessionStore.shared.loadSessions().map { $0.doctorName })).filter { !$0.trimmingCharacters(in: .whitespaces).isEmpty }
        
        view.backgroundColor = UIColor(hex: "F5F5F5")
        tableView.showsVerticalScrollIndicator = false

        if let existingSessionID {
            if let linkedReminder = ConsultationReminderStore.shared.reminder(forSessionID: existingSessionID) {
                linkedConsultationReminderID = linkedReminder.id
                isConsultationReminderOn = true
                reminderTime = linkedReminder.time
            } else if reminderTime == nil {
                reminderTime = sessionDate
            }
        }

        hasReviewedMedicationSelection = !medications.isEmpty

        tableView.register(
            UINib(nibName: "InputTextFieldTableViewCell", bundle: nil),
            forCellReuseIdentifier: "InputTextFieldCell")
        tableView.register(
            UINib(nibName: "DateInputTableViewCell", bundle: nil),
            forCellReuseIdentifier: "DateInputCell")
        tableView.register(
            UINib(nibName: "TimeInputTableViewCell", bundle: nil),
            forCellReuseIdentifier: "TimeCell")
        tableView.register(
            UINib(nibName: "SnoozeTableViewCell", bundle: nil),
            forCellReuseIdentifier: "SnoozeCell")
        tableView.register(
            UINib(nibName: "SymptomNameTableViewCell", bundle: nil),
            forCellReuseIdentifier: "SymptomNameCell")
        tableView.register(
            UINib(nibName: "SymptomDescriptionTableViewCell", bundle: nil),
            forCellReuseIdentifier: "SymptomDescriptionCell")
        tableView.register(UINib(nibName: "AddActionTableViewCell", bundle: nil), forCellReuseIdentifier: "AddActionCell")
        tableView.register(UINib(nibName: "QuestionTableViewCell", bundle: nil), forCellReuseIdentifier: "QuestionCell")
        tableView.register(UINib(nibName: "AddRecordTableViewCell", bundle: nil), forCellReuseIdentifier: "AddRecordCell")
        tableView.register(MedicationCardTableViewCell.self, forCellReuseIdentifier: "MedicationCardTableViewCell")
        
        validateForm()
    }
    
    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
        
        // Auto-focus Doctor's Name text field if it's a new session
        if existingSessionID == nil {
            if let cell = tableView.cellForRow(at: IndexPath(row: 0, section: 0)) as? InputTextFieldTableViewCell {
                cell.inputTextField.becomeFirstResponder()
            }
        }
    }
    
    // This is for done button in prepare sheet to be active only when the user enters the doctor name, purpose , date, atleast 1 symptom.
    private func validateForm() {
        let isDoctorNameValid = !doctorName.trimmingCharacters(in: .whitespaces).isEmpty
        let isTitleValid = !sessionTitle.trimmingCharacters(in: .whitespaces).isEmpty
        let hasValidSymptom = !symptoms.isEmpty && symptoms.contains { !$0.name.trimmingCharacters(in: .whitespaces).isEmpty }
        
        let isValid = isDoctorNameValid && isTitleValid && hasValidSymptom
        self.navigationItem.rightBarButtonItem?.isEnabled = isValid
    }
    
    @IBAction func cancelTapped(_ sender: Any) {
        dismiss(animated: true, completion: nil)
    }
    
    @IBAction func doneTapped(_ sender: Any) {
        if isConsultationReminderOn && reminderTime == nil {
            let alert = UIAlertController(
                title: "Select Reminder Time",
                message: "Choose a time before enabling this consultation as a reminder.",
                preferredStyle: .alert
            )
            alert.addAction(UIAlertAction(title: "OK", style: .default))
            present(alert, animated: true)
            return
        }
        
        // Filter out empty symptoms/questions
        let validSymptoms = symptoms.filter { !$0.name.trimmingCharacters(in: .whitespaces).isEmpty }
        let validQuestions = questions.filter { !$0.text.trimmingCharacters(in: .whitespaces).isEmpty }
        
        let isEditing = existingSessionID != nil
        
        let baseDate = sessionDate
        let consultationDateTime = reminderTime.map { combine(date: baseDate, withTime: $0) } ?? baseDate

        let newSession = ConsultSession(
            id: existingSessionID ?? UUID(),
            userID: existingUserID ?? UUID(),
            doctorName: doctorName,
            title: sessionTitle,
            date: consultationDateTime,
            symptoms: validSymptoms,
            questions: validQuestions,
            medications: medications,
            records: records,
            notes: notes.isEmpty ? nil : notes,
            status: .pending,
            createdAt: existingCreatedAt ?? Date()
        )
        
        let notificationName = isEditing ? "ConsultSessionUpdated" : "NewConsultSessionCreated"
        
        NotificationCenter.default.post(
            name: NSNotification.Name(notificationName),
            object: nil,
            userInfo: ["session": newSession]
        )

        if isConsultationReminderOn, let reminderTime {
            let reminderDateTime = combine(date: baseDate, withTime: reminderTime)
            let reminderData = AddConsultationFormData(
                doctorName: doctorName,
                purpose: sessionTitle,
                consultationDate: consultationDateTime,
                time: reminderDateTime,
                isPaused: false,
                repeatDays: [],
                isSnoozeOn: false,
                snoozeTime: nil
            )

            if let linkedConsultationReminderID {
                _ = ConsultationReminderStore.shared.updateReminder(
                    id: linkedConsultationReminderID,
                    consultSessionID: newSession.id,
                    doctorName: reminderData.doctorName,
                    purpose: reminderData.purpose,
                    consultationDate: reminderData.consultationDate,
                    time: reminderData.time,
                    repeatDays: reminderData.repeatDays,
                    isSnoozeOn: reminderData.isSnoozeOn,
                    snoozeTime: reminderData.snoozeTime,
                    isPaused: reminderData.isPaused
                )

                NotificationCenter.default.post(
                    name: NSNotification.Name("ConsultationReminderUpdated"),
                    object: nil,
                    userInfo: ["reminderID": linkedConsultationReminderID]
                )
            } else {
                let reminder = ConsultationReminderStore.shared.addReminder(
                    consultSessionID: newSession.id,
                    doctorName: reminderData.doctorName,
                    purpose: reminderData.purpose,
                    consultationDate: reminderData.consultationDate,
                    time: reminderData.time,
                    repeatDays: reminderData.repeatDays,
                    isSnoozeOn: reminderData.isSnoozeOn,
                    snoozeTime: reminderData.snoozeTime,
                    isPaused: reminderData.isPaused
                )

                linkedConsultationReminderID = reminder.id

                NotificationCenter.default.post(
                    name: NSNotification.Name("NewConsultationReminderCreated"),
                    object: nil,
                    userInfo: ["reminder": reminderData]
                )
            }
        } else if let linkedConsultationReminderID {
            ConsultationReminderStore.shared.removeReminder(id: linkedConsultationReminderID)
            NotificationCenter.default.post(
                name: NSNotification.Name("ConsultationReminderUpdated"),
                object: nil,
                userInfo: ["reminderID": linkedConsultationReminderID]
            )
            self.linkedConsultationReminderID = nil
        }
        
        dismiss(animated: true, completion: nil)
    }

    private func combine(date: Date, withTime time: Date) -> Date {
        let calendar = Calendar.current
        let dateComponents = calendar.dateComponents([.year, .month, .day], from: date)
        let timeComponents = calendar.dateComponents([.hour, .minute], from: time)

        var merged = DateComponents()
        merged.year = dateComponents.year
        merged.month = dateComponents.month
        merged.day = dateComponents.day
        merged.hour = timeComponents.hour
        merged.minute = timeComponents.minute

        return calendar.date(from: merged) ?? date
    }

    enum FormSection {
        case inputs
        case reminder
        case symptom(index: Int)
        case addSymptom
        case medication(index: Int)
        case addMedication
        case records
        case questions
        case notes
    }
    
    private func getFormSection(for section: Int) -> FormSection {
        var current = 0
        if section == current { return .inputs }
        current += 1
        if section == current { return .reminder }
        current += 1
        
        let symptomsCount = symptoms.count
        if section >= current && section < current + symptomsCount {
            return .symptom(index: section - current)
        }
        current += symptomsCount
        if section == current { return .addSymptom }
        current += 1
        
        if section == current { return .questions }
        current += 1
        
        let medicationsCount = medications.count
        if section >= current && section < current + medicationsCount {
            return .medication(index: section - current)
        }
        current += medicationsCount
        if section == current { return .addMedication }
        current += 1
        
        if section == current { return .records }
        current += 1
        
        
        if section == current { return .notes }
        fatalError("Unknown section mapping")
    }
    
    override func numberOfSections(in tableView: UITableView) -> Int {
        return 1 + 1 + symptoms.count + 1 + medications.count + 1 + 1 + 1 + 1
    }
    
    override func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        switch getFormSection(for: section) {
        case .inputs: return 2
        case .reminder: return 3
        case .symptom: return 2
        case .addSymptom: return 1
        case .medication: return 1
        case .addMedication: return 1
        case .records: return 1
        case .questions: return questions.count + 1
        case .notes: return 1
        }
    }
    
    override func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath)
    -> UITableViewCell
    {
        switch getFormSection(for: indexPath.section) {
        case .inputs:
            let cell =
            tableView.dequeueReusableCell(withIdentifier: "InputTextFieldCell", for: indexPath)
            as! InputTextFieldTableViewCell
            cell.selectionStyle = .none
            if indexPath.row == 0 {
                cell.inputTextField.placeholder = "Doctor's Name"
                cell.inputTextField.text = self.doctorName
                cell.inputTextField.delegate = self
                cell.didChangeText = { [weak self] text in
                    self?.doctorName = text
                    self?.validateForm()
                }
            } else {
                cell.inputTextField.placeholder = "Purpose of Consultation"
                cell.inputTextField.text = self.sessionTitle
                cell.inputTextField.delegate = nil
                cell.didChangeText = { [weak self] text in
                    self?.sessionTitle = text
                    self?.validateForm()
                }
            }
            return cell

        case .reminder:
            if indexPath.row == 0 {
                let cell =
                    tableView.dequeueReusableCell(withIdentifier: "DateInputCell", for: indexPath)
                    as! DateInputTableViewCell
                cell.selectionStyle = .none
                cell.showsShadow = false
                cell.configure(
                    placeholder: "Select Date",
                    date: (existingSessionID != nil || hasSelectedDate) ? sessionDate : nil
                )
                cell.didChangeDate = { [weak self] selectedDate in
                    guard let self = self else { return }
                    self.hasSelectedDate = true
                    if let selectedTime = self.reminderTime {
                        self.sessionDate = self.combine(date: selectedDate, withTime: selectedTime)
                    } else {
                        self.sessionDate = selectedDate
                    }
                }
                return cell
            }

            if indexPath.row == 1 {
                let cell = tableView.dequeueReusableCell(withIdentifier: "TimeCell", for: indexPath) as! TimeInputTableViewCell
                cell.selectionStyle = .none
                cell.showsShadow = false
                cell.configure(
                    placeholder: "Select Time",
                    time: reminderTime ?? sessionDate
                )
                cell.didChangeTime = { [weak self] selectedTime in
                    guard let self = self else { return }
                    self.reminderTime = selectedTime
                    self.sessionDate = self.combine(date: self.sessionDate, withTime: selectedTime)
                }
                return cell
            }

            let cell = tableView.dequeueReusableCell(withIdentifier: "SnoozeCell", for: indexPath) as! SnoozeTableViewCell
            cell.selectionStyle = .none
            cell.separatorInset = UIEdgeInsets(top: 0, left: 16, bottom: 0, right: 16)
            cell.titleLabel.text = "Set the time as reminder"
            cell.titleLabel.font = .systemFont(ofSize: 16, weight: .regular)
            cell.switchControl.isOn = isConsultationReminderOn
            cell.onSwitchChanged = { [weak self] isOn in
                self?.isConsultationReminderOn = isOn
            }
            return cell
            
        case .symptom(let index):
            if indexPath.row == 0 {
                let cell =
                tableView.dequeueReusableCell(withIdentifier: "SymptomNameCell", for: indexPath)
                as! SymptomNameTableViewCell
                cell.selectionStyle = .none
                cell.nameTextField?.text = symptoms[index].name
                
                cell.didChangeName = { [weak self] text in
                    self?.symptoms[index].name = text
                    self?.validateForm()
                }
                
                cell.didTapDelete = { [weak self] in
                    self?.symptoms.remove(at: index)
                    self?.tableView.reloadData()
                    self?.validateForm()
                }
                return cell
                
            } else {
                let cell =
                tableView.dequeueReusableCell(
                    withIdentifier: "SymptomDescriptionCell", for: indexPath)
                as! SymptomDescriptionTableViewCell
                cell.selectionStyle = .none
                cell.placeholderText = "Description"
                
                let currentDesc = symptoms[index].description
                cell.descriptionTextView?.text = currentDesc.isEmpty ? "Description" : currentDesc
                cell.descriptionTextView?.textColor = currentDesc.isEmpty ? .systemGray3 : .label
                
                cell.didChangeDescription = { [weak self] text in
                    self?.symptoms[index].description = text
                    self?.tableView.beginUpdates()
                    self?.tableView.endUpdates()
                }
                return cell
            }
            
        case .addSymptom:
            let cell =
            tableView.dequeueReusableCell(withIdentifier: "AddActionCell", for: indexPath)
            as! AddActionTableViewCell
            cell.selectionStyle = .none
            cell.actionLabel?.text = "add symptoms"
            cell.didTapAction = { [weak self] in
                guard let self = self else { return }
                let newSymptom = Symptom(name: "", description: "", isExpanded: false)
                self.symptoms.append(newSymptom)
                self.tableView.reloadData()
                self.validateForm()
            }
            return cell
            
        case .medication(let index):
            let medication = medications[index]
            let cell = tableView.dequeueReusableCell(withIdentifier: "MedicationCardTableViewCell", for: indexPath) as! MedicationCardTableViewCell
            cell.selectionStyle = .none
            cell.configure(
                name: medication.name,
                dosage: dosageText(for: medication.dosage),
                frequency: frequencyText(for: medication),
                duration: derivedDurationText(for: medication)
            )
            return cell
            
        case .addMedication:
            let cell =
            tableView.dequeueReusableCell(withIdentifier: "AddActionCell", for: indexPath)
            as! AddActionTableViewCell
            cell.selectionStyle = .none
            cell.actionLabel?.text = "add medicine"
            cell.didTapAction = { [weak self] in
                self?.presentMedicationSelection()
            }
            return cell
            
        case .records:
            let cell = tableView.dequeueReusableCell(withIdentifier: "AddRecordCell", for: indexPath) as! AddRecordTableViewCell
            cell.selectionStyle = .none
            cell.records = self.records
            cell.reloadRecords()
            
            cell.didDeleteRecord = { [weak self] index in
                guard let self = self else { return }
                self.records.remove(at: index)
                self.tableView.reloadData()
                self.validateForm()
            }
            
            cell.didTapAddRecord = { [weak self] in
                guard let self = self else { return }
                let storyboard = UIStoryboard(name: "Main", bundle: nil)
                guard let recordsVC = storyboard.instantiateViewController(withIdentifier: "RecordsViewController") as? RecordsViewController else { return }
                
                recordsVC.selectionMode = true
                recordsVC.alreadySelectedRecordIDs = Set(self.records.map { $0.id })
                
                recordsVC.didSelectRecords = { [weak self] selectedRecords in
                    guard let self = self else { return }
                    for record in selectedRecords {
                        if !self.records.contains(where: { $0.id == record.id || $0.title == record.title }) {
                            self.records.append(record)
                        }
                    }
                    self.tableView.reloadData()
                }
                
                let navVC = UINavigationController(rootViewController: recordsVC)
                navVC.modalPresentationStyle = .fullScreen
                self.present(navVC, animated: true)
            }
            return cell
            
        case .questions:
            if indexPath.row < questions.count {
                let cell =
                tableView.dequeueReusableCell(withIdentifier: "QuestionCell", for: indexPath)
                as! QuestionTableViewCell
                cell.selectionStyle = .none
                
                let currentText = questions[indexPath.row].text
                cell.questionTextView?.text = currentText.isEmpty ? "Question" : currentText
                cell.questionTextView?.textColor = currentText.isEmpty ? .systemGray3 : .label
                
                cell.didChangeText = { [weak self] text in
                    self?.questions[indexPath.row].text = text
                    self?.tableView.beginUpdates()
                    self?.tableView.endUpdates()
                }
                
                cell.didTapDelete = { [weak self] in
                    self?.questions.remove(at: indexPath.row)
                    self?.tableView.reloadData()
                }
                return cell
            } else {
                let cell =
                tableView.dequeueReusableCell(withIdentifier: "AddActionCell", for: indexPath)
                as! AddActionTableViewCell
                cell.selectionStyle = .none
                cell.actionLabel?.text = "add questions"
                cell.didTapAction = { [weak self] in
                    guard let self = self else { return }
                    let newQuestion = Question(text: "", isSelected: false)
                    self.questions.append(newQuestion)
                    self.tableView.reloadData()
                }
                return cell
            }
            
        case .notes:
            let cell = tableView.dequeueReusableCell(withIdentifier: "SymptomDescriptionCell", for: indexPath) as! SymptomDescriptionTableViewCell
            cell.selectionStyle = .none
            cell.placeholderText = "Additional Notes"
            
            let currentNotes = self.notes
            cell.descriptionTextView?.text = currentNotes.isEmpty ? "Additional Notes" : currentNotes
            cell.descriptionTextView?.textColor = currentNotes.isEmpty ? .systemGray3 : .label
            
            if cell.notesHeightConstraint == nil {
                let constraint = cell.descriptionTextView.heightAnchor.constraint(greaterThanOrEqualToConstant: 100)
                constraint.isActive = true
                cell.notesHeightConstraint = constraint
            }
            
            cell.didChangeDescription = { [weak self] text in
                self?.notes = text
                self?.tableView.beginUpdates()
                self?.tableView.endUpdates()
            }
            return cell
        }
    }
    
    override func tableView(_ tableView: UITableView, heightForFooterInSection section: Int)
    -> CGFloat
    {
        switch getFormSection(for: section) {
        case .medication, .addMedication:
            return 6
        default:
            break
        }
        return 7
    }
    
    override func tableView(_ tableView: UITableView, heightForHeaderInSection section: Int)
    -> CGFloat
    {
        switch getFormSection(for: section) {
        case .medication, .addMedication:
            return 6
        default:
            break
        }
        return 7
    }
    
    override func tableView(_ tableView: UITableView, heightForRowAt indexPath: IndexPath) -> CGFloat {
        if case .records = getFormSection(for: indexPath.section) {
            let totalItems = records.count + 1
            let rows = ceil(Double(totalItems) / 2.0)
            let height = (rows * 140) + ((rows - 1) * 12) + 2
            return CGFloat(height)
        }
        if case .medication = getFormSection(for: indexPath.section) {
            return MedicationCardTableViewCell.preferredHeight
        }
        return UITableView.automaticDimension
    }
    
    
    override func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        tableView.deselectRow(at: indexPath, animated: true)
        
        switch getFormSection(for: indexPath.section) {
        case .addSymptom:
            let newSymptom = Symptom(name: "", description: "", isExpanded: false)
            symptoms.append(newSymptom)
            tableView.reloadData()
            validateForm()
            
            
        case .symptom(let index):
            if indexPath.row == 0 {
                symptoms.remove(at: index)
                tableView.reloadData()
                validateForm()
            }
            
        case .addMedication:
            presentMedicationSelection()

        case .questions:
            if indexPath.row == questions.count {
                let newQuestion = Question(text: "", isSelected: false)
                questions.append(newQuestion)
                tableView.reloadData()
            }
            
        default: break
        }
    }

    private func presentMedicationSelection() {
        let selectionVC = MedicationSelectionViewController()
        selectionVC.initiallySelectedMedicationIDs = Set(medications.map(\.id))
        selectionVC.preselectAllIfSelectionEmpty = !hasReviewedMedicationSelection && medications.isEmpty
        selectionVC.onDone = { [weak self] selectedMedications in
            guard let self = self else { return }
            self.medications = selectedMedications
            self.hasReviewedMedicationSelection = true
            self.tableView.reloadData()
        }
        let navVC = UINavigationController(rootViewController: selectionVC)
        navVC.modalPresentationStyle = .fullScreen
        present(navVC, animated: true)
    }

    private func dosageText(for dosage: String?) -> String {
        guard let dosage,
              !dosage.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            return ""
        }
        return dosage
    }

    private func derivedFrequency(for medication: Medication) -> MedicationFrequency {
        let hasCustomRepeatDays = !medication.repeatDays.isEmpty && medication.repeatDays.count != 7
        guard !hasCustomRepeatDays else {
            return .asNeeded
        }

        switch medication.times.count {
        case 1:
            return .onceDaily
        case 2:
            return .twiceDaily
        case 3:
            return .thriceDaily
        default:
            return medication.frequency ?? .asNeeded
        }
    }

    private func frequencyText(for medication: Medication) -> String {
        switch derivedFrequency(for: medication) {
        case .onceDaily:
            return "Once Daily"
        case .twiceDaily:
            return "Twice Daily"
        case .thriceDaily:
            return "Thrice Daily"
        case .asNeeded:
            return "As Needed"
        }
    }

    private func derivedDurationText(for medication: Medication, relativeTo now: Date = Date()) -> String {
        if let reminderCreatedAt = medication.reminderCreatedAt {
            let calendar = Calendar.current
            let start = calendar.startOfDay(for: reminderCreatedAt)
            let end = calendar.startOfDay(for: now)
            let components = calendar.dateComponents([.year, .month, .weekOfYear, .day], from: start, to: end)

            if let years = components.year, years > 0 {
                return "From last \(years) year" + (years == 1 ? "" : "s")
            }
            if let months = components.month, months > 0 {
                return "From last \(months) month" + (months == 1 ? "" : "s")
            }
            if let weeks = components.weekOfYear, weeks > 0 {
                return "From last \(weeks) week" + (weeks == 1 ? "" : "s")
            }
            if let days = components.day, days > 0 {
                return "From last \(days) day" + (days == 1 ? "" : "s")
            }
            return "From today"
        }

        return medication.duration ?? ""
    }
}

extension PrepareConsultationTableViewController: UITextFieldDelegate {
    func textField(_ textField: UITextField, shouldChangeCharactersIn range: NSRange, replacementString string: String) -> Bool {
        guard textField.placeholder == "Doctor's Name" else { return true }
        
        if string.isEmpty {
            return true
        }
        
        let currentText = textField.text ?? ""
        guard let stringRange = Range(range, in: currentText) else { return true }
        let updatedText = currentText.replacingCharacters(in: stringRange, with: string)
        
        if updatedText == "Dr. " || updatedText == "Dr." || updatedText == "Dr" || updatedText == "D" {
            return true
        }

        if let match = pastDoctorNames.first(where: { $0.lowercased().hasPrefix(updatedText.lowercased()) }) {
            textField.text = match
            self.doctorName = match
            self.validateForm() 
            
            if let startPosition = textField.position(from: textField.beginningOfDocument, offset: updatedText.count) {
                let endPosition = textField.endOfDocument
                textField.selectedTextRange = textField.textRange(from: startPosition, to: endPosition)
            }
            
            return false
        }
        
        return true
    }
}
