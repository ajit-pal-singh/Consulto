import UIKit

class OTPViewController: UIViewController {

    // MARK: - Outlets
    @IBOutlet var otpTextFields: [UITextField]! // Sort these by X position in storyboard connections!
    @IBOutlet weak var verifyButton: UIButton!
    @IBOutlet weak var buttonBottomConstraint: NSLayoutConstraint! // Connect this to the button's bottom constraint to safe area
    
    private var initialBottomConstant: CGFloat = 0

    override func viewDidLoad() {
        super.viewDidLoad()

        setupTextFields()
        setupUI()
        
        // Hide keyboard when tapping outside
        let tap = UITapGestureRecognizer(target: self.view, action: #selector(UIView.endEditing))
        tap.cancelsTouchesInView = false
        view.addGestureRecognizer(tap)
    }
    
    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        
        // Store the original distance so we can revert to it
        if let constraint = buttonBottomConstraint {
            initialBottomConstant = constraint.constant
        }
        
        NotificationCenter.default.addObserver(self, selector: #selector(keyboardWillShow), name: UIResponder.keyboardWillShowNotification, object: nil)
        NotificationCenter.default.addObserver(self, selector: #selector(keyboardWillHide), name: UIResponder.keyboardWillHideNotification, object: nil)
    }
    
    override func viewWillDisappear(_ animated: Bool) {
        super.viewWillDisappear(animated)
        NotificationCenter.default.removeObserver(self)
    }
    
    // MARK: - UI Setup
    private func setupUI() {
        verifyButton.layer.cornerRadius = 27.5
        verifyButton.layer.masksToBounds = true
    }
    
    private func setupTextFields() {
        // Sort safely based on X position to make sure outlet ordering doesn't break logic
        otpTextFields.sort { $0.frame.origin.x < $1.frame.origin.x }
        
        for textField in otpTextFields {
            textField.delegate = self
            textField.keyboardType = .numberPad
            textField.textAlignment = .center
            textField.font = .systemFont(ofSize: 24, weight: .semibold)
            
            // UI Border and radius
            textField.layer.cornerRadius = 12
            textField.layer.borderWidth = 2
            textField.layer.borderColor = UIColor.darkGray.cgColor
            textField.layer.masksToBounds = true
            
            // Empty placeholder or clear backgrounds can be set here
            textField.backgroundColor = .clear
        }
        
        // Auto focus the first one
        otpTextFields.first?.becomeFirstResponder()
    }
    
    // MARK: - Keyboard Handling
    @objc private func keyboardWillShow(notification: NSNotification) {
        if let keyboardFrame = notification.userInfo?[UIResponder.keyboardFrameEndUserInfoKey] as? NSValue {
            let keyboardHeight = keyboardFrame.cgRectValue.height
            
            // Move it up above keyboard. The constant is usually inverted if it's pinned to bottom safe area
            buttonBottomConstraint?.constant = keyboardHeight + 20 
            
            UIView.animate(withDuration: 0.3) {
                self.view.layoutIfNeeded()
            }
        }
    }
    
    @objc private func keyboardWillHide(notification: NSNotification) {
        buttonBottomConstraint?.constant = initialBottomConstant
        UIView.animate(withDuration: 0.3) {
            self.view.layoutIfNeeded()
        }
    }
}

// MARK: - UITextFieldDelegate
extension OTPViewController: UITextFieldDelegate {
    
    func textFieldDidBeginEditing(_ textField: UITextField) {
        let consultoBlue = UIColor(hex: "#1A90FF") ?? UIColor(red: 0x1A/255.0, green: 0x90/255.0, blue: 0xFF/255.0, alpha: 1.0)
        textField.layer.borderColor = consultoBlue.cgColor
    }
    
    func textFieldDidEndEditing(_ textField: UITextField) {
        textField.layer.borderColor = UIColor.darkGray.cgColor
    }
    
    func textField(_ textField: UITextField, shouldChangeCharactersIn range: NSRange, replacementString string: String) -> Bool {
        
        guard let index = otpTextFields.firstIndex(of: textField) else { return true }
        
        // Hitting backspace
        if string.isEmpty {
            textField.text = ""
            // Go back
            if index > 0 {
                otpTextFields[index - 1].becomeFirstResponder()
            }
            return false
        }
        
        // Typing a character
        if string.count == 1 {
            textField.text = string
            // Go next
            if index < otpTextFields.count - 1 {
                otpTextFields[index + 1].becomeFirstResponder()
            } else {
                // Last one filled
                textField.resignFirstResponder()
            }
            return false
        }
        
        // Handle full paste
        return false
    }
}
