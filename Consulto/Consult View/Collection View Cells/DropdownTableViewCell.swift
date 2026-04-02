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
    private let menuButton = UIButton(type: .system)

    override func awakeFromNib() {
        super.awakeFromNib()
        selectionStyle = .none

        dropdownTextField.tintColor = .clear
        dropdownTextField.isUserInteractionEnabled = false
        setupMenuButton()
        reloadMenu()
    }

    func setSelectedOption(_ option: String) {
        dropdownTextField.text = option
        reloadMenu()
    }

    func clearSelection() {
        dropdownTextField.text = nil
        reloadMenu()
    }

    private func setupMenuButton() {
        menuButton.translatesAutoresizingMaskIntoConstraints = false
        menuButton.backgroundColor = .clear
        menuButton.showsMenuAsPrimaryAction = true

        contentView.addSubview(menuButton)

        NSLayoutConstraint.activate([
            menuButton.leadingAnchor.constraint(equalTo: contentView.leadingAnchor),
            menuButton.trailingAnchor.constraint(equalTo: contentView.trailingAnchor),
            menuButton.topAnchor.constraint(equalTo: contentView.topAnchor),
            menuButton.bottomAnchor.constraint(equalTo: contentView.bottomAnchor)
        ])
    }

    private func reloadMenu() {
        let actions = recordOptions.map { option in
            UIAction(
                title: option,
                state: dropdownTextField.text == option ? .on : .off
            ) { [weak self] _ in
                self?.dropdownTextField.text = option
                self?.didChangeSelection?(option)
                self?.reloadMenu()
            }
        }

        menuButton.menu = UIMenu(title: "", options: .displayInline, children: actions)
    }

    override func setSelected(_ selected: Bool, animated: Bool) {
        super.setSelected(selected, animated: animated)
    }
}
