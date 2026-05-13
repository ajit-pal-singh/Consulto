//
//  ResetPasswordViewController.swift
//  Consulto
//
//  Forgot Password — Step 3
//  User sets a new password after OTP verification.
//  On success → alert → pop all the way back to LoginViewController.
//

import UIKit

class ResetPasswordViewController: UIViewController {

    // MARK: - Outlets
    // ┌──────────────────────────────────────────────────────────────────┐
    // │  Connect in storyboard:                                          │
    // │  • tableView              → UITableView                          │
    // │  • resetPasswordButton    → UIButton ("Reset Password")          │
    // │  • buttonBottomConstraint → bottom constraint of the button      │
    // └──────────────────────────────────────────────────────────────────┘
    @IBOutlet weak var tableView: UITableView!
    @IBOutlet weak var resetPasswordButton: UIButton!
    @IBOutlet weak var buttonBottomConstraint: NSLayoutConstraint!

    // MARK: - State
    private var newPassword: String = ""
    private var confirmPassword: String = ""
    private var initialBottomConstant: CGFloat = 0
    /// When true (in-app forgot password), pops back to ProfileSettingsViewController.
    /// When false (onboarding flow), pops to root (LoginViewController).
    var isInAppFlow: Bool = false

    // MARK: - Lifecycle

    override func viewDidLoad() {
        super.viewDidLoad()
        setupTableView()

        let tap = UITapGestureRecognizer(target: self.view, action: #selector(UIView.endEditing))
        tap.cancelsTouchesInView = false
        view.addGestureRecognizer(tap)
    }

    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
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

    @IBAction func resetPasswordButtonTapped(_ sender: UIButton) {
        guard !newPassword.isEmpty else {
            showAlert(title: "Missing Field", message: "Please enter your new password.")
            return
        }
        guard !confirmPassword.isEmpty else {
            showAlert(title: "Missing Field", message: "Please confirm your new password.")
            return
        }
        guard newPassword == confirmPassword else {
            showAlert(title: "Password Mismatch", message: "Passwords do not match. Please try again.")
            return
        }
        guard newPassword.count >= 8 else {
            showAlert(title: "Weak Password", message: "Password must be at least 8 characters.")
            return
        }

        sender.isEnabled = false
        sender.setTitle("Updating…", for: .normal)

        Task {
            do {
                try await AuthManager.shared.updatePasswordForReset(to: newPassword)
                await MainActor.run {
                    self.showAlert(
                        title: "Password Updated",
                        message: "Your password has been reset successfully. Please log in with your new password."
                    ) {
                        self.navigateAfterReset()
                    }
                }
            } catch {
                await MainActor.run {
                    sender.isEnabled = true
                    sender.setTitle("Reset Password", for: .normal)
                    self.showAlert(title: "Error", message: error.localizedDescription)
                }
            }
        }
    }

    // MARK: - Helpers

    private func navigateAfterReset() {
        if isInAppFlow {
            // In-app flow: pop back to ProfileSettingsViewController
            if let target = navigationController?.viewControllers.first(where: { $0 is ProfileSettingsViewController }) {
                navigationController?.popToViewController(target, animated: true)
            } else {
                navigationController?.popViewController(animated: true)
            }
        } else {
            // Onboarding flow: pop all the way back to LoginViewController
            navigationController?.popToRootViewController(animated: true)
        }
    }

    private func showAlert(title: String, message: String, completion: (() -> Void)? = nil) {
        let alert = UIAlertController(title: title, message: message, preferredStyle: .alert)
        alert.addAction(UIAlertAction(title: "OK", style: .default) { _ in completion?() })
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

extension ResetPasswordViewController: UITableViewDelegate, UITableViewDataSource {

    func numberOfSections(in tableView: UITableView) -> Int { 2 }
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

        cell.setupPasswordToggle()

        if indexPath.section == 0 {
            cell.inputTextField.placeholder = "Enter new password"
            cell.inputTextField.keyboardType = .default
            cell.inputTextField.text = newPassword
            cell.didChangeText = { [weak self] text in self?.newPassword = text }
        } else {
            cell.inputTextField.placeholder = "Confirm new password"
            cell.inputTextField.keyboardType = .default
            cell.inputTextField.text = confirmPassword
            cell.didChangeText = { [weak self] text in self?.confirmPassword = text }
        }

        return cell
    }

    func tableView(_ tableView: UITableView, heightForRowAt indexPath: IndexPath) -> CGFloat { 55 }

    func tableView(_ tableView: UITableView, heightForHeaderInSection section: Int) -> CGFloat {
        section == 1 ? 12 : 0.01
    }
    func tableView(_ tableView: UITableView, viewForHeaderInSection section: Int) -> UIView? {
        let v = UIView(); v.backgroundColor = .clear; return v
    }
    func tableView(_ tableView: UITableView, heightForFooterInSection section: Int) -> CGFloat { 0.01 }
    func tableView(_ tableView: UITableView, viewForFooterInSection section: Int) -> UIView? {
        let v = UIView(); v.backgroundColor = .clear; return v
    }
}
