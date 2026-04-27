import UIKit

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
        // Simple client-side validation logic
        if currentPassword.isEmpty || newPassword.isEmpty || confirmPassword.isEmpty {
            showAlert(title: "Error", message: "Please fill all fields.")
            return
        }
        if newPassword != confirmPassword {
            showAlert(title: "Error", message: "New passwords do not match.")
            return
        }
        
        showAlert(title: "Success", message: "Password changed successfully!") {
            self.navigationController?.popViewController(animated: true)
        }
    }
    
    private func showAlert(title: String, message: String, completion: (() -> Void)? = nil) {
        let alert = UIAlertController(title: title, message: message, preferredStyle: .alert)
        alert.addAction(UIAlertAction(title: "OK", style: .default) { _ in
            completion?()
        })
        present(alert, animated: true)
    }
    @IBAction func forgotPasswordTapped(_ sender: Any) {
        showEmailPromptAlert()
    }
    
    private func showEmailPromptAlert() {
        let alert = UIAlertController(title: "Reset Password", message: "Enter your registered email address to receive a verification code.", preferredStyle: .alert)
        alert.addTextField { textField in
            textField.placeholder = "Email Address"
            textField.keyboardType = .emailAddress
        }
        alert.addAction(UIAlertAction(title: "Cancel", style: .cancel))
        alert.addAction(UIAlertAction(title: "Send Code", style: .default) { [weak self] _ in
            guard let email = alert.textFields?.first?.text, !email.isEmpty else {
                self?.showAlert(title: "Error", message: "Please enter a valid email address.")
                return
            }
            // Simulate sending code
            self?.showVerifyCodeAlert()
        })
        present(alert, animated: true)
    }
    
    private func showVerifyCodeAlert() {
        let alert = UIAlertController(title: "Enter Code", message: "Enter the verification code sent to your email.", preferredStyle: .alert)
        alert.addTextField { textField in
            textField.placeholder = "Verification Code"
            textField.keyboardType = .numberPad
        }
        alert.addAction(UIAlertAction(title: "Cancel", style: .cancel))
        alert.addAction(UIAlertAction(title: "Verify", style: .default) { [weak self] _ in
            guard let code = alert.textFields?.first?.text, !code.isEmpty else {
                self?.showAlert(title: "Error", message: "Please enter the verification code.")
                return
            }
            // Simulate verifying code
            self?.showResetPasswordAlert()
        })
        present(alert, animated: true)
    }
    
    private func showResetPasswordAlert() {
        let alert = UIAlertController(title: "Create New Password", message: "Enter and confirm your new password.", preferredStyle: .alert)
        alert.addTextField { textField in
            textField.placeholder = "New Password"
            textField.isSecureTextEntry = true
        }
        alert.addTextField { textField in
            textField.placeholder = "Confirm Password"
            textField.isSecureTextEntry = true
        }
        alert.addAction(UIAlertAction(title: "Cancel", style: .cancel))
        alert.addAction(UIAlertAction(title: "Save", style: .default) { [weak self] _ in
            guard let textFields = alert.textFields, textFields.count == 2,
                  let newPass = textFields[0].text, !newPass.isEmpty,
                  let confirmPass = textFields[1].text, !confirmPass.isEmpty else {
                self?.showAlert(title: "Error", message: "Please fill both fields.")
                return
            }
            
            if newPass != confirmPass {
                self?.showAlert(title: "Error", message: "Passwords do not match.")
                return
            }
            
            // Password successfully reset
            self?.showAlert(title: "Success", message: "Your password has been successfully reset!") {
                self?.navigationController?.popViewController(animated: true)
            }
        })
        present(alert, animated: true)
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
