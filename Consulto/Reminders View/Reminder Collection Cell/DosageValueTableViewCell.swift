//
//  DosageValueTableViewCell.swift
//  Consulto
//
//  Created by Tevika Kumbhawat on 29/03/26.
//

import UIKit

class DosageValueTableViewCell: UITableViewCell {
    
    @IBOutlet weak var dosageTextField: UITextField!
    
    var didChangeText: ((String) -> Void)?

    override func awakeFromNib() {
        super.awakeFromNib()
        dosageTextField.addTarget(self, action: #selector(textChanged), for: .editingChanged)
    }

    func configure(text: String?) {
        dosageTextField.text = text
    }

    @objc private func textChanged() {
        didChangeText?(dosageTextField.text ?? "")
    }

    override func setSelected(_ selected: Bool, animated: Bool) {
        super.setSelected(selected, animated: animated)

        // Configure the view for the selected state
    }
    
}
