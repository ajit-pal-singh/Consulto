import UIKit

class OTPViewController: UIViewController {

    // MARK: - Mode
    enum OTPMode {
        case signUp        // default: verify email after registration
        case passwordReset // verify OTP from forgot-password flow
    }

    // MARK: - Outlets
    // Sort by X position in IB connections!
    @IBOutlet var otpTextFields: [UITextField]!
    @IBOutlet weak var verifyButton: UIButton!
    @IBOutlet weak var buttonBottomConstraint: NSLayoutConstraint!

    /// Connect this to the label that shows "demomail***@gmail.com" in the storyboard
    @IBOutlet weak var emailLabel: UILabel!

    /// Set by the presenting VC before pushing.
    var email: String = ""
    /// Controls post-verification navigation destination.
    var mode: OTPMode = .signUp
    /// When true, ResetPasswordVC will pop back to ProfileSettings instead of root.
    var isInAppFlow: Bool = false

    private var initialBottomConstant: CGFloat = 0

    // MARK: - Lifecycle

    override func viewDidLoad() {
        super.viewDidLoad()
        setupTextFields()
        setupUI()

        // Show masked email in the label
        emailLabel?.text = maskedEmail(email)

        let tap = UITapGestureRecognizer(target: self.view, action: #selector(UIView.endEditing))
        tap.cancelsTouchesInView = false
        view.addGestureRecognizer(tap)
    }

    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
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
        otpTextFields.sort { $0.frame.origin.x < $1.frame.origin.x }
        for textField in otpTextFields {
            textField.delegate = self
            textField.keyboardType = .numberPad
            textField.textAlignment = .center
            textField.font = .systemFont(ofSize: 24, weight: .semibold)
            textField.layer.cornerRadius = 12
            textField.layer.borderWidth = 2
            textField.layer.borderColor = UIColor.darkGray.cgColor
            textField.layer.masksToBounds = true
            textField.backgroundColor = .clear
        }
        otpTextFields.first?.becomeFirstResponder()
    }

    // MARK: - Helpers

    /// Returns a masked version of the email, e.g. "ajit***@gmail.com"
    private func maskedEmail(_ email: String) -> String {
        guard let atIndex = email.firstIndex(of: "@") else { return email }
        let localPart = String(email[email.startIndex..<atIndex])
        let domain    = String(email[atIndex...])
        let visible   = localPart.prefix(min(4, localPart.count))
        return "\(visible)***\(domain)"
    }

    // MARK: - Actions

    @IBAction func verifyButtonTapped(_ sender: UIButton) {
        let token = otpTextFields.compactMap { $0.text }.joined()

        guard token.count == otpTextFields.count else {
            showAlert(title: "Incomplete Code", message: "Please enter all \(otpTextFields.count) digits.")
            return
        }

        setLoading(true)

        Task {
            do {
                switch mode {
                case .signUp:
                    try await AuthManager.shared.verifyOTP(email: email, token: token)
                    await MainActor.run { self.pushProfileSetup() }
                case .passwordReset:
                    try await AuthManager.shared.verifyPasswordResetOTP(email: email, token: token)
                    await MainActor.run { self.pushResetPassword() }
                }
            } catch {
                await MainActor.run {
                    self.setLoading(false)
                    self.showAlert(title: "Verification Failed", message: error.localizedDescription)
                }
            }
        }
    }

    /// Called from the "Didn't receive the code?" button in the storyboard
    @IBAction func resendCodeTapped(_ sender: UIButton) {
        sender.isEnabled = false
        sender.setTitle("Sending…", for: .normal)

        Task {
            do {
                try await AuthManager.shared.resendOTP(email: email)
                await MainActor.run {
                    sender.isEnabled = true
                    sender.setTitle("Didn't receive the code?", for: .normal)
                    self.showAlert(title: "Code Sent", message: "A new code has been sent to \(self.email).")
                }
            } catch {
                await MainActor.run {
                    sender.isEnabled = true
                    sender.setTitle("Didn't receive the code?", for: .normal)
                    self.showAlert(title: "Failed to Resend", message: error.localizedDescription)
                }
            }
        }
    }

    private func pushProfileSetup() {
        let storyboard = UIStoryboard(name: "Onboarding-Login", bundle: nil)
        guard let profileVC = storyboard.instantiateViewController(withIdentifier: "ProfileViewController") as? ProfileViewController else { return }
        navigationController?.pushViewController(profileVC, animated: true)
    }

    private func pushResetPassword() {
        let storyboard = UIStoryboard(name: "Onboarding-Login", bundle: nil)
        guard let resetVC = storyboard.instantiateViewController(withIdentifier: "ResetPasswordViewController") as? ResetPasswordViewController else { return }
        resetVC.isInAppFlow = isInAppFlow   // forward the context
        navigationController?.pushViewController(resetVC, animated: true)
    }

    private func setLoading(_ loading: Bool) {
        verifyButton.isEnabled = !loading
        verifyButton.setTitle(loading ? "Verifying…" : "Verify Code", for: .normal)
    }

    private func showAlert(title: String, message: String) {
        let alert = UIAlertController(title: title, message: message, preferredStyle: .alert)
        alert.addAction(UIAlertAction(title: "OK", style: .default))
        present(alert, animated: true)
    }

    // MARK: - Keyboard Handling

    @objc private func keyboardWillShow(notification: NSNotification) {
        if let keyboardFrame = notification.userInfo?[UIResponder.keyboardFrameEndUserInfoKey] as? NSValue {
            let keyboardHeight = keyboardFrame.cgRectValue.height
            buttonBottomConstraint?.constant = keyboardHeight + 20
            UIView.animate(withDuration: 0.3) { self.view.layoutIfNeeded() }
        }
    }

    @objc private func keyboardWillHide(notification: NSNotification) {
        buttonBottomConstraint?.constant = initialBottomConstant
        UIView.animate(withDuration: 0.3) { self.view.layoutIfNeeded() }
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

        if string.isEmpty {
            textField.text = ""
            if index > 0 { otpTextFields[index - 1].becomeFirstResponder() }
            return false
        }
        if string.count == 1 {
            textField.text = string
            if index < otpTextFields.count - 1 {
                otpTextFields[index + 1].becomeFirstResponder()
            } else {
                textField.resignFirstResponder()
            }
            return false
        }
        return false
    }
}
