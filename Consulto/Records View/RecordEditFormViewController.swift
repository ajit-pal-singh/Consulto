//
//  RecordEditFormViewController.swift
//  Consulto
//
//  Created by Ajitpal Singh on 09/04/26.
//

import UIKit

class RecordEditFormViewController: UIViewController, UITableViewDelegate, UITableViewDataSource {

    // MARK: - Outlets
    @IBOutlet weak var tableView: UITableView! // Make sure to connect this in Storyboard!
    
    // MARK: - Properties
    var record: HealthRecord?
    var onRecordUpdated: ((HealthRecord) -> Void)?
    
    // Form State Tracking
    private var summaryText: String = ""
    private var titleText: String = ""
    private var facilityNameText: String = ""
    private var dateString: String = ""
    private var recordTypeString: String = ""
    
    override func viewDidLoad() {
        super.viewDidLoad()
        title = "Edit Record"
        
        // Style View
        tableView.backgroundColor = UIColor(hex: "F5F5F5")
        view.backgroundColor = UIColor(hex: "F5F5F5")
        
        setupTableView()
        populateInitialData()
        
        // Dismiss keyboard naturally
        let tap = UITapGestureRecognizer(target: self.view, action: #selector(UIView.endEditing))
        tap.cancelsTouchesInView = false
        view.addGestureRecognizer(tap)
    }
    
    private func setupTableView() {
        tableView.delegate = self
        tableView.dataSource = self
        tableView.separatorStyle = .none
        
        // Register the exact form cells from our Preview view!
        tableView.register(UINib(nibName: "InputTextFieldTableViewCell", bundle: nil), forCellReuseIdentifier: "InputTextFieldCell")
        tableView.register(UINib(nibName: "DateInputTableViewCell", bundle: nil), forCellReuseIdentifier: "DateInputCell")
        tableView.register(UINib(nibName: "DropdownTableViewCell", bundle: nil), forCellReuseIdentifier: "DropdownCell")
        tableView.register(UINib(nibName: "SymptomDescriptionTableViewCell", bundle: nil), forCellReuseIdentifier: "SymptomDescriptionCell")
    }
    
    private func populateInitialData() {
        guard let record = record else { return }
        
        titleText = record.title ?? ""
        facilityNameText = record.healthFacilityName ?? ""
        summaryText = record.summary ?? ""
        recordTypeString = record.recordType.displayName
        
        if let docDate = record.documentDate {
            let formatter = DateFormatter()
            formatter.dateFormat = "dd-MM-yyyy"
            dateString = formatter.string(from: docDate)
        }
    }
    
    // MARK: - IBActions
    @IBAction func cancelTapped(_ sender: Any) {
        dismiss(animated: true)
    }
    
    @IBAction func saveTapped(_ sender: Any) {
        view.endEditing(true)
        syncFormValuesFromVisibleCells()
        
        // Ensure we actually came from a valid record
        guard let currentRecord = self.record else { return }
        
        let trimmedTitle = titleText.trimmingCharacters(in: .whitespacesAndNewlines)
        let finalTitle = trimmedTitle.isEmpty ? "Untitled Record" : trimmedTitle
        
        let trimmedFacility = facilityNameText.trimmingCharacters(in: .whitespacesAndNewlines)
        let finalFacility = trimmedFacility.isEmpty ? nil : trimmedFacility
        
        let trimmedSummary = summaryText.trimmingCharacters(in: .whitespacesAndNewlines)
        let finalSummary = trimmedSummary.isEmpty ? nil : trimmedSummary
        
        let finalRecordType = RecordType.fromDisplayName(recordTypeString) ?? .other
        
        let trimmedDate = dateString.trimmingCharacters(in: .whitespacesAndNewlines)
        var parsedDocumentDate: Date? = nil
        if !trimmedDate.isEmpty {
            let formatter = DateFormatter()
            formatter.calendar = Calendar(identifier: .gregorian)
            formatter.locale = Locale(identifier: "en_US_POSIX")
            formatter.dateFormat = "dd-MM-yyyy"
            parsedDocumentDate = formatter.date(from: trimmedDate)
        }
        
        // Re-construct the struct because HealthRecord properties are `let` constants!
        let updatedRecord = HealthRecord(
            id: currentRecord.id,
            userID: currentRecord.userID,
            title: finalTitle,
            recordType: finalRecordType,
            healthFacilityName: finalFacility,
            summary: finalSummary,
            dateAdded: currentRecord.dateAdded,
            documentDate: parsedDocumentDate,
            files: currentRecord.files,
            extractedData: currentRecord.extractedData
        )
        
        // Save back to JSON store!
        do {
            try HealthRecordStore.shared.updateRecord(updatedRecord)
            dismiss(animated: true) { [weak self] in
                self?.onRecordUpdated?(updatedRecord)
            }
        } catch {
            print("Failed to save edited record: \(error)")
        }
    }
    
    // Sync active fields if save is pressed while a user is typing
    private func syncFormValuesFromVisibleCells() {
        if let titleCell = tableView.cellForRow(at: IndexPath(row: 0, section: 0)) as? InputTextFieldTableViewCell {
            titleText = titleCell.inputTextField.text ?? titleText
        }
        if let facilityCell = tableView.cellForRow(at: IndexPath(row: 0, section: 1)) as? InputTextFieldTableViewCell {
            facilityNameText = facilityCell.inputTextField.text ?? facilityNameText
        }
        if let dateCell = tableView.cellForRow(at: IndexPath(row: 0, section: 2)) as? DateInputTableViewCell {
            dateString = dateCell.dateTextField.text ?? dateString
        }
        if let dropdownCell = tableView.cellForRow(at: IndexPath(row: 0, section: 3)) as? DropdownTableViewCell {
            recordTypeString = dropdownCell.dropdownTextField.text ?? recordTypeString
        }
        if let summaryCell = tableView.cellForRow(at: IndexPath(row: 0, section: 4)) as? SymptomDescriptionTableViewCell {
            let text = summaryCell.descriptionTextView.text ?? ""
            summaryText = text == summaryCell.placeholderText ? "" : text
        }
    }
    
    // MARK: - UITableView DataSource & Delegate
    func numberOfSections(in tableView: UITableView) -> Int {
        return 5 // We have exactly 5 form fields
    }

    func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        return 1
    }
    
    // Vertical spacing
    func tableView(_ tableView: UITableView, heightForHeaderInSection section: Int) -> CGFloat {
        if section == 0 { return 20 } // Give the top of the table view some breathing room
        return 7
    }

    func tableView(_ tableView: UITableView, heightForFooterInSection section: Int) -> CGFloat {
        return .leastNormalMagnitude
    }
    
    func tableView(_ tableView: UITableView, viewForHeaderInSection section: Int) -> UIView? {
        return nil
    }
    
    func tableView(_ tableView: UITableView, viewForFooterInSection section: Int) -> UIView? {
        return nil
    }

    func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        if indexPath.section == 0 {
            let cell = tableView.dequeueReusableCell(withIdentifier: "InputTextFieldCell", for: indexPath) as! InputTextFieldTableViewCell
            cell.selectionStyle = .none
            cell.inputTextField.placeholder = "Title"
            cell.inputTextField.text = self.titleText
            cell.didChangeText = { [weak self] text in
                self?.titleText = text
            }
            return cell
        }
        else if indexPath.section == 1 {
            let cell = tableView.dequeueReusableCell(withIdentifier: "InputTextFieldCell", for: indexPath) as! InputTextFieldTableViewCell
            cell.selectionStyle = .none
            cell.inputTextField.placeholder = "Facility Name"
            cell.inputTextField.text = self.facilityNameText
            cell.didChangeText = { [weak self] text in
                self?.facilityNameText = text
            }
            return cell
        }
        else if indexPath.section == 2 {
            let cell = tableView.dequeueReusableCell(withIdentifier: "DateInputCell", for: indexPath) as! DateInputTableViewCell
            cell.selectionStyle = .none
            
            let formatter = DateFormatter()
            formatter.calendar = Calendar(identifier: .gregorian)
            formatter.locale = Locale(identifier: "en_US_POSIX")
            formatter.dateFormat = "dd-MM-yyyy"
            let parsedDate = formatter.date(from: self.dateString)
            
            cell.configure(
                placeholder: "Document Date",
                date: parsedDate
            )
            cell.didChangeDate = { [weak self] date in
                self?.dateString = formatter.string(from: date)
            }
            return cell
        }
        else if indexPath.section == 3 {
            let cell = tableView.dequeueReusableCell(withIdentifier: "DropdownCell", for: indexPath) as! DropdownTableViewCell
            cell.selectionStyle = .none
            cell.dropdownTextField?.placeholder = "Select Record Type"
            
            if !self.recordTypeString.isEmpty {
                cell.setSelectedOption(self.recordTypeString)
            } else {
                cell.clearSelection()
            }
            cell.didChangeSelection = { [weak self] value in
                self?.recordTypeString = value
            }
            return cell
        }
        else if indexPath.section == 4 {
            let cell = tableView.dequeueReusableCell(withIdentifier: "SymptomDescriptionCell", for: indexPath) as! SymptomDescriptionTableViewCell
            cell.selectionStyle = .none
            cell.placeholderText = "Notes / Summary"
            
            cell.descriptionTextView.text = summaryText.isEmpty ? "Notes / Summary" : summaryText
            cell.descriptionTextView.textColor = summaryText.isEmpty ? .systemGray3 : .label
            
            if cell.notesHeightConstraint == nil {
                let constraint = cell.descriptionTextView.heightAnchor.constraint(greaterThanOrEqualToConstant: 100)
                constraint.isActive = true
                cell.notesHeightConstraint = constraint
            }
            
            cell.didChangeDescription = { [weak self] text in
                self?.summaryText = text
                self?.tableView.beginUpdates()
                self?.tableView.endUpdates()
            }
            return cell
        }
        
        return UITableViewCell()
    }
}
