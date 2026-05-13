//
//  SignUpViewController.swift
//  Consulto
//
//  Created by Ajitpal Singh on 02/04/26.
//

import UIKit

class SignUpViewController: UIViewController {

    // MARK: - Outlets
    @IBOutlet weak var tableView: UITableView!
    @IBOutlet weak var signUpButton: UIButton!

    // Form state
    private var emailText: String = ""
    private var passwordText: String = ""
    private var confirmPasswordText: String = ""

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
    }

    private func setupTableView() {
        tableView.delegate = self
        tableView.dataSource = self
        tableView.separatorStyle = .none
        let nib = UINib(nibName: "InputTextFieldTableViewCell", bundle: nil)
        tableView.register(nib, forCellReuseIdentifier: "InputTextFieldCell")
    }

    // MARK: - Actions

    @IBAction func signUpButtonTapped(_ sender: UIButton) {
        let email    = emailText.trimmingCharacters(in: .whitespacesAndNewlines)
        let password = passwordText
        let confirm  = confirmPasswordText

        guard !email.isEmpty, !password.isEmpty else {
            showAlert(title: "Missing Fields", message: "Please enter your email and a password.")
            return
        }
        guard password == confirm else {
            showAlert(title: "Password Mismatch", message: "Passwords do not match. Please try again.")
            return
        }
        guard password.count >= 8 else {
            showAlert(title: "Weak Password", message: "Password must be at least 8 characters.")
            return
        }

        setLoading(true)

        Task {
            do {
                try await AuthManager.shared.signUp(email: email, password: password)
                await MainActor.run {
                    self.setLoading(false)
                    self.pushOTPScreen(email: email)
                }
            } catch {
                await MainActor.run {
                    self.setLoading(false)
                    self.showAlert(title: "Sign Up Failed", message: error.localizedDescription)
                }
            }
        }
    }

    private func pushOTPScreen(email: String) {
        let storyboard = UIStoryboard(name: "Onboarding-Login", bundle: nil)
        guard let otpVC = storyboard.instantiateViewController(withIdentifier: "OTPViewController") as? OTPViewController else { return }
        otpVC.email = email
        navigationController?.pushViewController(otpVC, animated: true)
    }

    private func setLoading(_ loading: Bool) {
        signUpButton.isEnabled = !loading
        signUpButton.setTitle(loading ? "Creating account…" : "Create Account", for: .normal)
    }

    private func showAlert(title: String, message: String) {
        let alert = UIAlertController(title: title, message: message, preferredStyle: .alert)
        alert.addAction(UIAlertAction(title: "OK", style: .default))
        present(alert, animated: true)
    }
}

// MARK: - UITableViewDelegate, UITableViewDataSource
extension SignUpViewController: UITableViewDelegate, UITableViewDataSource {

    func numberOfSections(in tableView: UITableView) -> Int { 3 }
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

        if indexPath.section == 0 {
            cell.inputTextField.placeholder = "Enter your email"
            cell.inputTextField.isSecureTextEntry = false
            cell.inputTextField.keyboardType = .emailAddress
            cell.inputTextField.text = emailText
            cell.didChangeText = { [weak self] text in self?.emailText = text }
        } else if indexPath.section == 1 {
            cell.setupPasswordToggle()
            cell.inputTextField.placeholder = "Create new password"
            cell.inputTextField.keyboardType = .default
            cell.inputTextField.text = passwordText
            cell.didChangeText = { [weak self] text in self?.passwordText = text }
        } else {
            cell.setupPasswordToggle()
            cell.inputTextField.placeholder = "Confirm new password"
            cell.inputTextField.keyboardType = .default
            cell.inputTextField.text = confirmPasswordText
            cell.didChangeText = { [weak self] text in self?.confirmPasswordText = text }
        }

        return cell
    }

    func tableView(_ tableView: UITableView, heightForRowAt indexPath: IndexPath) -> CGFloat { 55 }
    func tableView(_ tableView: UITableView, heightForHeaderInSection section: Int) -> CGFloat { section > 0 ? 10 : 0.01 }
    func tableView(_ tableView: UITableView, viewForHeaderInSection section: Int) -> UIView? {
        let v = UIView(); v.backgroundColor = .clear; return v
    }
    func tableView(_ tableView: UITableView, heightForFooterInSection section: Int) -> CGFloat { 0.01 }
    func tableView(_ tableView: UITableView, viewForFooterInSection section: Int) -> UIView? {
        let v = UIView(); v.backgroundColor = .clear; return v
    }
}
