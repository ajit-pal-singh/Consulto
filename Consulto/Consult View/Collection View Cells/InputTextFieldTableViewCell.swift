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
    }
    
    func setupPasswordToggle() {
        let button = UIButton(type: .custom)
        button.setImage(UIImage(systemName: "eye.slash.fill"), for: .normal)
        button.tintColor = .lightGray
        button.frame = CGRect(x: 0, y: 0, width: 30, height: 30)
        button.addTarget(self, action: #selector(togglePasswordView(_:)), for: .touchUpInside)
        
        let rightView = UIView(frame: CGRect(x: 0, y: 0, width: 40, height: 30))
        button.center = CGPoint(x: 20, y: 15)
        rightView.addSubview(button)
        
        inputTextField.rightView = rightView
        inputTextField.rightViewMode = .always
        inputTextField.isSecureTextEntry = true
    }

    @objc func togglePasswordView(_ sender: UIButton) {
        inputTextField.isSecureTextEntry.toggle()
        let icon = inputTextField.isSecureTextEntry ? "eye.slash.fill" : "eye.fill"
        sender.setImage(UIImage(systemName: icon), for: .normal)
    }

}
