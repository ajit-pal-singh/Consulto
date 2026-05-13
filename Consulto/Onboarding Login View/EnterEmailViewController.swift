//
//  EnterEmailViewController.swift
//  Consulto
//
//  Forgot Password — Step 1
//  User enters their registered email; tapping "Send Code" triggers a
//  Supabase password-reset OTP and navigates to OTPViewController.
//

import UIKit

class EnterEmailViewController: UIViewController {

    // MARK: - Outlets
    // ┌─────────────────────────────────────────────────────────────┐
    // │  Connect in storyboard:                                     │
    // │  • tableView        → UITableView                           │
    // │  • sendCodeButton   → UIButton ("Send Code")                │
    // │  • buttonBottomConstraint → bottom constraint of the button │
    // └─────────────────────────────────────────────────────────────┘
    @IBOutlet weak var tableView: UITableView!
    @IBOutlet weak var sendCodeButton: UIButton!
    @IBOutlet weak var buttonBottomConstraint: NSLayoutConstraint!

    // MARK: - State
    private var emailText: String = ""
    private var initialBottomConstant: CGFloat = 0

    // MARK: - Lifecycle

    override func viewDidLoad() {
        super.viewDidLoad()
        setupTableView()

        // Dismiss keyboard on tap outside
        let tap = UITapGestureRecognizer(target: self.view, action: #selector(UIView.endEditing))
        tap.cancelsTouchesInView = false
        view.addGestureRecognizer(tap)
    }

    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        // LoginVC hides the nav bar — reveal it for the forgot-password flow
        navigationController?.setNavigationBarHidden(false, animated: animated)
        initialBottomConstant = buttonBottomConstraint.constant
        NotificationCenter.default.addObserver(self, selector: #selector(keyboardWillShow), name: UIResponder.keyboardWillShowNotification, object: nil)
        NotificationCenter.default.addObserver(self, selector: #selector(keyboardWillHide), name: UIResponder.keyboardWillHideNotification, object: nil)
    }

    override func viewWillDisappear(_ animated: Bool) {
        super.viewWillDisappear(animated)
        NotificationCenter.default.removeObserver(self)
    }

    // MARK: - Table View Setup

    private func setupTableView() {
        tableView.delegate = self
        tableView.dataSource = self
        tableView.separatorStyle = .none
        tableView.backgroundColor = .clear
        tableView.isScrollEnabled = false
        let nib = UINib(nibName: "InputTextFieldTableViewCell", bundle: nil)
        tableView.register(nib, forCellReuseIdentifier: "InputTextFieldCell")
    }

    // MARK: - Actions

    @IBAction func sendCodeButtonTapped(_ sender: UIButton) {
        let email = emailText.trimmingCharacters(in: .whitespacesAndNewlines)

        guard !email.isEmpty else {
            showAlert(title: "Missing Field", message: "Please enter your email address.")
            return
        }
        guard isValidEmail(email) else {
            showAlert(title: "Invalid Email", message: "Please enter a valid email address.")
            return
        }

        sender.isEnabled = false
        sender.setTitle("Sending…", for: .normal)

        Task {
            do {
                try await AuthManager.shared.sendPasswordResetOTP(to: email)
                await MainActor.run {
                    sender.isEnabled = true
                    sender.setTitle("Send Code", for: .normal)
                    self.pushOTPScreen(email: email)
                }
            } catch {
                await MainActor.run {
                    sender.isEnabled = true
                    sender.setTitle("Send Code", for: .normal)
                    self.showAlert(title: "Error", message: error.localizedDescription)
                }
            }
        }
    }

    // MARK: - Navigation

    private func pushOTPScreen(email: String) {
        let storyboard = UIStoryboard(name: "Onboarding-Login", bundle: nil)
        guard let otpVC = storyboard.instantiateViewController(withIdentifier: "OTPViewController") as? OTPViewController else { return }
        otpVC.email = email
        otpVC.mode  = .passwordReset           // tells OTP VC to navigate to ResetPassword after verify
        navigationController?.pushViewController(otpVC, animated: true)
    }

    // MARK: - Helpers

    private func isValidEmail(_ email: String) -> Bool {
        let regex = #"^[A-Za-z0-9._%+\-]+@[A-Za-z0-9.\-]+\.[A-Za-z]{2,}$"#
        return email.range(of: regex, options: .regularExpression) != nil
    }

    private func showAlert(title: String, message: String) {
        let alert = UIAlertController(title: title, message: message, preferredStyle: .alert)
        alert.addAction(UIAlertAction(title: "OK", style: .default))
        present(alert, animated: true)
    }

    // MARK: - Keyboard Handling

    @objc private func keyboardWillShow(notification: NSNotification) {
        guard let keyboardFrame = notification.userInfo?[UIResponder.keyboardFrameEndUserInfoKey] as? NSValue else { return }
        let keyboardHeight = keyboardFrame.cgRectValue.height
        buttonBottomConstraint.constant = keyboardHeight + 20
        UIView.animate(withDuration: 0.3) { self.view.layoutIfNeeded() }
    }

    @objc private func keyboardWillHide(notification: NSNotification) {
        buttonBottomConstraint.constant = initialBottomConstant
        UIView.animate(withDuration: 0.3) { self.view.layoutIfNeeded() }
    }
}

// MARK: - UITableViewDelegate, UITableViewDataSource

extension EnterEmailViewController: UITableViewDelegate, UITableViewDataSource {

    func numberOfSections(in tableView: UITableView) -> Int { 1 }
    func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int { 1 }

    func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        guard let cell = tableView.dequeueReusableCell(withIdentifier: "InputTextFieldCell", for: indexPath) as? InputTextFieldTableViewCell else {
            return UITableViewCell()
        }

        cell.selectionStyle = .none
        let greyBg = UIColor(hex: "#F4F4F4") ?? UIColor(red: 0xF4/255.0, green: 0xF4/255.0, blue: 0xF4/255.0, alpha: 1.0)
        cell.backgroundColor = .clear
        cell.contentView.backgroundColor = greyBg
        cell.layer.shadowOpacity = 0
        cell.contentView.layer.cornerRadius = 27.5
        cell.contentView.layer.masksToBounds = true

        cell.inputTextField.placeholder = "Enter your email"
        cell.inputTextField.isSecureTextEntry = false
        cell.inputTextField.keyboardType = .emailAddress
        cell.inputTextField.autocapitalizationType = .none
        cell.inputTextField.text = emailText
        cell.didChangeText = { [weak self] text in self?.emailText = text }

        return cell
    }

    func tableView(_ tableView: UITableView, heightForRowAt indexPath: IndexPath) -> CGFloat { 55 }
    func tableView(_ tableView: UITableView, heightForHeaderInSection section: Int) -> CGFloat { 0.01 }
    func tableView(_ tableView: UITableView, heightForFooterInSection section: Int) -> CGFloat { 0.01 }
}
