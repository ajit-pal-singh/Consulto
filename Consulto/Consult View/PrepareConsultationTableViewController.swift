import UIKit

class PrepareConsultationTableViewController: UITableViewController {

    var sessionTitle: String = ""
    var doctorName: String = ""
    var sessionDate: Date = Date()
    var symptoms: [Symptom] = []
    var medications: [Medication] = []
    var records: [HealthRecord] = []
    var questions: [Question] = []
    var notes: String = ""

    override func viewDidLoad() {
        super.viewDidLoad()

        view.backgroundColor = UIColor(hex: "F5F5F5")

        tableView.register(
            UINib(nibName: "InputTextFieldTableViewCell", bundle: nil),
            forCellReuseIdentifier: "InputTextFieldCell")
        tableView.register(
            UINib(nibName: "DateInputTableViewCell", bundle: nil),
            forCellReuseIdentifier: "DateInputCell")
        tableView.register(
            UINib(nibName: "SymptomNameTableViewCell", bundle: nil),
            forCellReuseIdentifier: "SymptomNameCell")
        tableView.register(
            UINib(nibName: "SymptomDescriptionTableViewCell", bundle: nil),
            forCellReuseIdentifier: "SymptomDescriptionCell")
        tableView.register(UINib(nibName: "AddActionTableViewCell", bundle: nil), forCellReuseIdentifier: "AddActionCell")
        tableView.register(UINib(nibName: "QuestionTableViewCell", bundle: nil), forCellReuseIdentifier: "QuestionCell")
        tableView.register(UINib(nibName: "AddRecordTableViewCell", bundle: nil), forCellReuseIdentifier: "AddRecordCell")
    }

    @IBAction func cancelTapped(_ sender: Any) {
        dismiss(animated: true, completion: nil)
    }

    @IBAction func doneTapped(_ sender: Any) {
        // Validate mandatory fields
        var missing: [String] = []
        if doctorName.trimmingCharacters(in: .whitespaces).isEmpty { missing.append("Doctor's Name") }
        if sessionTitle.trimmingCharacters(in: .whitespaces).isEmpty { missing.append("Purpose") }
        if symptoms.isEmpty || symptoms.allSatisfy({ $0.name.trimmingCharacters(in: .whitespaces).isEmpty }) {
            missing.append("At least one Symptom")
        }
        
        if !missing.isEmpty {
            let alert = UIAlertController(
                title: "Required Fields Missing",
                message: missing.joined(separator: ", ") + " must be filled.",
                preferredStyle: .alert)
            alert.addAction(UIAlertAction(title: "OK", style: .default))
            present(alert, animated: true)
            return
        }
        
        // Filter out empty symptoms/questions
        let validSymptoms = symptoms.filter { !$0.name.trimmingCharacters(in: .whitespaces).isEmpty }
        let validQuestions = questions.filter { !$0.text.trimmingCharacters(in: .whitespaces).isEmpty }
        
        let newSession = ConsultSession(
            id: UUID(),
            userID: UUID(),
            doctorName: doctorName,
            title: sessionTitle,
            date: sessionDate,
            symptoms: validSymptoms,
            questions: validQuestions,
            medications: medications,
            records: records,
            notes: notes.isEmpty ? nil : notes,
            status: .pending,
            createdAt: Date()
        )
        
        NotificationCenter.default.post(
            name: NSNotification.Name("NewConsultSessionCreated"),
            object: nil,
            userInfo: ["session": newSession]
        )
        
        dismiss(animated: true, completion: nil)
    }

    enum FormSection {
        case inputs
        case date
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
        if section == current { return .date }
        current += 1

        let symptomsCount = symptoms.count
        if section >= current && section < current + symptomsCount {
            return .symptom(index: section - current)
        }
        current += symptomsCount
        if section == current { return .addSymptom }
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

        if section == current { return .questions }
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
        case .date: return 1
        case .symptom: return 2
        case .addSymptom: return 1
        case .medication: return 2
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
                cell.didChangeText = { [weak self] text in self?.doctorName = text }
            } else {
                cell.inputTextField.placeholder = "Purpose of Consultation"
                cell.inputTextField.text = self.sessionTitle
                cell.didChangeText = { [weak self] text in self?.sessionTitle = text }
            }
            return cell

        case .date:
            let cell =
                tableView.dequeueReusableCell(withIdentifier: "DateInputCell", for: indexPath)
                as! DateInputTableViewCell
            cell.selectionStyle = .none
            cell.dateTextField.placeholder = "Select Date"
            cell.setDate(self.sessionDate)
            cell.didChangeDate = { [weak self] selectedDate in self?.sessionDate = selectedDate }
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
                }

                cell.didTapDelete = { [weak self] in
                    self?.symptoms.remove(at: index)
                    self?.tableView.reloadData()
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
            return cell

        case .medication(let index):
            let cell = UITableViewCell(style: .default, reuseIdentifier: "Fallback")
            cell.textLabel?.text = medications[index].name
            return cell

        case .addMedication:
            let cell =
                tableView.dequeueReusableCell(withIdentifier: "AddActionCell", for: indexPath)
                as! AddActionTableViewCell
            cell.selectionStyle = .none
            cell.actionLabel?.text = "add medicine"
            return cell

        case .records:
            let cell = tableView.dequeueReusableCell(withIdentifier: "AddRecordCell", for: indexPath) as! AddRecordTableViewCell
            cell.selectionStyle = .none
            cell.records = self.records
            cell.reloadRecords()
            cell.didTapAddRecord = { [weak self] in
                guard let self = self else { return }
                let storyboard = UIStoryboard(name: "Main", bundle: nil)
                guard let recordsVC = storyboard.instantiateViewController(withIdentifier: "RecordsViewController") as? RecordsViewController else { return }
                
                recordsVC.selectionMode = true
                recordsVC.alreadySelectedRecordIDs = Set(self.records.map { $0.id })
                
                recordsVC.didSelectRecords = { [weak self] selectedRecords in
                    guard let self = self else { return }
                    for record in selectedRecords {
                        if !self.records.contains(where: { $0.id == record.id }) {
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
        return 7
    }

    override func tableView(_ tableView: UITableView, heightForHeaderInSection section: Int)
        -> CGFloat
    {
        return 7
    }

    override func tableView(_ tableView: UITableView, heightForRowAt indexPath: IndexPath) -> CGFloat {
        if case .records = getFormSection(for: indexPath.section) {
            let totalItems = records.count + 1
            let rows = ceil(Double(totalItems) / 2.0)
            let height = (rows * 140) + ((rows - 1) * 12) + 2
            return CGFloat(height)
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

        // Optionally, we could scroll to the newly inserted text field so the user can type immediately
        // let newSectionIndex = getSectionIndex(for: .symptom(index: symptoms.count - 1))
        // tableView.scrollToRow(at: IndexPath(row: 0, section: newSectionIndex), at: .bottom, animated: true)

        case .symptom(let index):
            if indexPath.row == 0 {
                symptoms.remove(at: index)
                tableView.reloadData()
            }

        case .addMedication:
            print("Add medicine tapped")

        case .questions:
            if indexPath.row == questions.count {
                let newQuestion = Question(text: "", isSelected: false)
                questions.append(newQuestion)
                tableView.reloadData()
            }

        default: break
        }
    }
    
    
    
    
    
    
    
    
    
    
    
    
    
    
    
    
    
    
    
    
    
    
    
    
    
    
    
    
    
    
    
    
    
    
    
    
    
    
    
    
    
    
    
    
    
    
    

    /*
    // Override to support conditional editing of the table view.
    override func tableView(_ tableView: UITableView, canEditRowAt indexPath: IndexPath) -> Bool {
        // Return false if you do not want the specified item to be editable.
        return true
    }
    */

    /*
    // Override to support editing the table view.
    override func tableView(_ tableView: UITableView, commit editingStyle: UITableViewCell.EditingStyle, forRowAt indexPath: IndexPath) {
        if editingStyle == .delete {
            // Delete the row from the data source
            tableView.deleteRows(at: [indexPath], with: .fade)
        } else if editingStyle == .insert {
            // Create a new instance of the appropriate class, insert it into the array, and add a new row to the table view
        }
    }
    */

    /*
    // Override to support rearranging the table view.
    override func tableView(_ tableView: UITableView, moveRowAt fromIndexPath: IndexPath, to: IndexPath) {
    
    }
    */

    /*
    // Override to support conditional rearranging of the table view.
    override func tableView(_ tableView: UITableView, canMoveRowAt indexPath: IndexPath) -> Bool {
        // Return false if you do not want the item to be re-orderable.
        return true
    }
    */

    /*
    // MARK: - Navigation
    
    // In a storyboard-based application, you will often want to do a little preparation before navigation
    override func prepare(for segue: UIStoryboardSegue, sender: Any?) {
        // Get the new view controller using segue.destination.
        // Pass the selected object to the new view controller.
    }
    */

}
