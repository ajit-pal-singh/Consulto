import UIKit
import Supabase
import Auth

class ChangePasswordViewController: UIViewController {
    
    @IBOutlet weak var tableView: UITableView!
    @IBOutlet weak var containerView: UIView!
    
    var currentPassword = ""
    var newPassword = ""
    var confirmPassword = ""

    override func viewDidLoad() {
        super.viewDidLoad()
        containerView.backgroundColor = UIColor(hex: "F5F5F5")
        
        setupTableView()
        
        let tap = UITapGestureRecognizer(target: self.view, action: #selector(UIView.endEditing))
        tap.cancelsTouchesInView = false
        view.addGestureRecognizer(tap)
    }
    
    private func setupTableView() {
        tableView.delegate = self
        tableView.dataSource = self
        tableView.backgroundColor = .clear
        tableView.separatorStyle = .none
        tableView.showsVerticalScrollIndicator = false
        tableView.register(UINib(nibName: "InputTextFieldTableViewCell", bundle: nil), forCellReuseIdentifier: "InputTextFieldCell")
    }
    
    @IBAction func changePasswordTapped(_ sender: UIButton) {
        // MARK: Empty field checks
        guard !currentPassword.isEmpty else {
            showAlert(title: "Missing Field", message: "Please enter your current password.")
            return
        }
        guard !newPassword.isEmpty else {
            showAlert(title: "Missing Field", message: "Please enter a new password.")
            return
        }
        guard !confirmPassword.isEmpty else {
            showAlert(title: "Missing Field", message: "Please confirm your new password.")
            return
        }

        // MARK: New password rules
        guard newPassword == confirmPassword else {
            showAlert(title: "Password Mismatch", message: "New password and confirm password do not match.")
            return
        }
        guard newPassword.count >= 8 else {
            showAlert(title: "Weak Password", message: "New password must be at least 8 characters.")
            return
        }
        guard newPassword != currentPassword else {
            showAlert(title: "Same Password", message: "New password must be different from your current password.")
            return
        }

        sender.isEnabled = false
        sender.setTitle("Verifying…", for: .normal)

        Task {
            do {
                // Verify current password, then update — throws if current is wrong
                try await AuthManager.shared.verifyAndUpdatePassword(
                    current: currentPassword,
                    new: newPassword
                )
                await MainActor.run {
                    self.showAlert(title: "Success", message: "Password updated successfully!") {
                        self.navigationController?.popViewController(animated: true)
                    }
                }
            } catch {
                await MainActor.run {
                    sender.isEnabled = true
                    sender.setTitle("Change Password", for: .normal)

                    // Provide a friendly message for wrong current password
                    let message = self.isInvalidCredentialsError(error)
                        ? "Current password is incorrect. Please try again."
                        : error.localizedDescription
                    self.showAlert(title: "Error", message: message)
                }
            }
        }
    }

    /// Returns true if the Supabase error indicates wrong credentials.
    private func isInvalidCredentialsError(_ error: Error) -> Bool {
        let desc = error.localizedDescription.lowercased()
        return desc.contains("invalid login") ||
               desc.contains("invalid credentials") ||
               desc.contains("email not confirmed") ||
               desc.contains("wrong password")
    }
    
    private func showAlert(title: String, message: String, completion: (() -> Void)? = nil) {
        let alert = UIAlertController(title: title, message: message, preferredStyle: .alert)
        alert.addAction(UIAlertAction(title: "OK", style: .default) { _ in
            completion?()
        })
        present(alert, animated: true)
    }
    @IBAction func forgotPasswordTapped(_ sender: Any) {
        let button = sender as? UIButton
        button?.isEnabled = false

        Task {
            do {
                // Get the current signed-in user's email — no need to ask them to type it
                guard let email = try? await supabase.auth.session.user.email,
                      !email.isEmpty else {
                    await MainActor.run {
                        button?.isEnabled = true
                        self.showAlert(title: "Error", message: "Unable to retrieve your account email. Please try again.")
                    }
                    return
                }

                // Send OTP to that email
                try await AuthManager.shared.sendPasswordResetOTP(to: email)

                await MainActor.run {
                    button?.isEnabled = true
                    self.pushOTPForPasswordReset(email: email)
                }
            } catch {
                await MainActor.run {
                    button?.isEnabled = true
                    self.showAlert(title: "Error", message: error.localizedDescription)
                }
            }
        }
    }

    private func pushOTPForPasswordReset(email: String) {
        let storyboard = UIStoryboard(name: "Onboarding-Login", bundle: nil)
        guard let otpVC = storyboard.instantiateViewController(withIdentifier: "OTPViewController") as? OTPViewController else { return }
        otpVC.email = email
        otpVC.mode = .passwordReset
        otpVC.isInAppFlow = true   // tells ResetPasswordVC to pop back to ProfileSettings
        navigationController?.pushViewController(otpVC, animated: true)
    }
}

extension ChangePasswordViewController: UITableViewDelegate, UITableViewDataSource {
    func numberOfSections(in tableView: UITableView) -> Int {
        return 3
    }
    
    func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        return 1
    }
    
    func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        guard let cell = tableView.dequeueReusableCell(withIdentifier: "InputTextFieldCell", for: indexPath) as? InputTextFieldTableViewCell else { return UITableViewCell() }
        cell.selectionStyle = .none
        cell.backgroundColor = .clear
        cell.contentView.backgroundColor = .white
        cell.layer.shadowOpacity = 0
        cell.contentView.layer.cornerRadius = 27.5
        cell.contentView.layer.masksToBounds = true
        
        cell.setupPasswordToggle()
        
        if indexPath.section == 0 {
            cell.inputTextField.placeholder = "Current Password"
            cell.inputTextField.text = currentPassword
            cell.didChangeText = { [weak self] text in self?.currentPassword = text }
        } else if indexPath.section == 1 {
            cell.inputTextField.placeholder = "New Password"
            cell.inputTextField.text = newPassword
            cell.didChangeText = { [weak self] text in self?.newPassword = text }
        } else {
            cell.inputTextField.placeholder = "Re-type New Password"
            cell.inputTextField.text = confirmPassword
            cell.didChangeText = { [weak self] text in self?.confirmPassword = text }
        }
        
        return cell
    }
    
    func tableView(_ tableView: UITableView, heightForRowAt indexPath: IndexPath) -> CGFloat {
        return 55
    }
    
    func tableView(_ tableView: UITableView, heightForHeaderInSection section: Int) -> CGFloat {
        return section == 0 ? 30 : 10
    }
    func tableView(_ tableView: UITableView, viewForHeaderInSection section: Int) -> UIView? {
        return UIView()
    }
    func tableView(_ tableView: UITableView, heightForFooterInSection section: Int) -> CGFloat {
        return 0.01
    }
    func tableView(_ tableView: UITableView, viewForFooterInSection section: Int) -> UIView? {
        return UIView()
    }
}
