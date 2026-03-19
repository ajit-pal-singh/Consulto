//
//  InputTextFieldTableViewCell.swift
//  Consulto
//
//  Created by Tevika Kumbhawat on 18/03/26.
//

import UIKit

class InputTextFieldTableViewCell: UITableViewCell {

    @IBOutlet weak var inputTextField: UITextField!

    var didChangeText: ((String) -> Void)?

    override func awakeFromNib() {
        super.awakeFromNib()
        
        self.layer.shadowColor = UIColor.black.cgColor
        self.layer.shadowOffset = CGSize(width: 0, height: 2)
        self.layer.shadowOpacity = 0.08
        self.layer.shadowRadius = 10
        self.layer.masksToBounds = false
        
        inputTextField.addTarget(self, action: #selector(textChanged), for: .editingChanged)
    }

    @objc func textChanged(_ textField: UITextField) {
        didChangeText?(textField.text ?? "")
    }

    override func setSelected(_ selected: Bool, animated: Bool) {
        super.setSelected(selected, animated: animated)

        // Configure the view for the selected state
    }

}
