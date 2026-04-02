//
//  NameInputTableViewCell.swift
//  Consulto
//
//  Created by Tevika Kumbhawat on 29/03/26.
//

import UIKit

class NameInputTableViewCell: UITableViewCell {

    @IBOutlet weak var textField: UITextField!
    var didChangeText: ((String) -> Void)?

    override func awakeFromNib() {
        super.awakeFromNib()
//        backgroundColor = .clear
//        contentView.backgroundColor = .clear
//        
//        layer.shadowColor = UIColor.black.cgColor
//        layer.shadowOffset = CGSize(width: 0, height: 2)
//        layer.shadowOpacity = 0.06
//        layer.shadowRadius = 10
//        layer.masksToBounds = false

        textField.clearButtonMode = .whileEditing
        textField.autocorrectionType = .no
        textField.addTarget(self, action: #selector(textChanged), for: .editingChanged)
    }

    override func setSelected(_ selected: Bool, animated: Bool) {
        super.setSelected(selected, animated: animated)

        // Configure the view for the selected state
    }
    
    func configure(placeholder: String) {
        textField.placeholder = placeholder
    }

    func configure(placeholder: String, text: String?, keyboardType: UIKeyboardType = .default) {
        self.configure(placeholder: placeholder)
        textField.text = text
        textField.keyboardType = keyboardType
    }

    @objc private func textChanged(_ sender: UITextField) {
        didChangeText?(sender.text ?? "")
    }
}
