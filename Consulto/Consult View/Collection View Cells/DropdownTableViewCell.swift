//
//  DropdownTableViewCell.swift
//  Consulto
//
//  Created by Ajitpal Singh on 22/03/26.
//

import UIKit

class DropdownTableViewCell: UITableViewCell {
    @IBOutlet weak var containerView: UIView!
    @IBOutlet weak var dropdownTextField: UITextField!
    var didChangeSelection: ((String) -> Void)?

    // Map of display names dynamically tied to your actual existing Model Enums!
    let recordOptions = [
        "Prescription", // mapped to RecordType.prescription
        "Lab Report",   // mapped to RecordType.labReport
        "Scan",         // mapped to RecordType.scan
        "Discharge Summary", // mapped to RecordType.dischargeSummary
        "Other"         // mapped to RecordType.other
    ]
    
    let pickerView = UIPickerView()

    override func awakeFromNib() {
        super.awakeFromNib()
        selectionStyle = .none
        
        setupPickerView()
    }
    
    private func setupPickerView() {
        pickerView.delegate = self
        pickerView.dataSource = self
        
        // Hide the blinking typing cursor! This makes it act purely like a dropdown
        dropdownTextField.tintColor = .clear
        
        // Connect the spinning picker to intercept the standard keyboard
        dropdownTextField.inputView = pickerView
    }
    
    @objc private func closePicker() {
        dropdownTextField.resignFirstResponder()
    }

    func setSelectedOption(_ option: String) {
        dropdownTextField.text = option
        if let idx = recordOptions.firstIndex(of: option) {
            pickerView.selectRow(idx, inComponent: 0, animated: false)
        }
    }

    override func setSelected(_ selected: Bool, animated: Bool) {
        super.setSelected(selected, animated: animated)
    }
}

// MARK: - Picker View Controls
extension DropdownTableViewCell: UIPickerViewDelegate, UIPickerViewDataSource {
    func numberOfComponents(in pickerView: UIPickerView) -> Int {
        return 1
    }
    
    func pickerView(_ pickerView: UIPickerView, numberOfRowsInComponent component: Int) -> Int {
        return recordOptions.count
    }
    
    func pickerView(_ pickerView: UIPickerView, titleForRow row: Int, forComponent component: Int) -> String? {
        return recordOptions[row]
    }
    
    func pickerView(_ pickerView: UIPickerView, didSelectRow row: Int, inComponent component: Int) {
        // Automatically place the selected name into the text box and notify
        dropdownTextField.text = recordOptions[row]
        didChangeSelection?(recordOptions[row])
    }
}
