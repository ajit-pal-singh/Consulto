//
//  LoginViewController.swift
//  Consulto
//
//  Created by Ajitpal Singh on 30/03/26.
//

import UIKit
import GoogleSignIn

class LoginViewController: UIViewController {

    // MARK: - Outlets
    @IBOutlet weak var tableView: UITableView!
    @IBOutlet weak var loginButton: UIButton!
    @IBOutlet weak var createAccountButton: UIButton!

    // Form state
    private var emailText: String = ""
    private var passwordText: String = ""

    override func viewDidLoad() {
        super.viewDidLoad()

        setupTableView()

        // Hide keyboard when tapping outside
        let tap = UITapGestureRecognizer(target: self.view, action: #selector(UIView.endEditing))
        tap.cancelsTouchesInView = false
        view.addGestureRecognizer(tap)
    }

    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        navigationController?.setNavigationBarHidden(true, animated: animated)
    }

    // MARK: - Table View Setup

    private func setupTableView() {
        tableView.delegate = self
        tableView.dataSource = self
        tableView.separatorStyle = .none

        let nib = UINib(nibName: "InputTextFieldTableViewCell", bundle: nil)
        tableView.register(nib, forCellReuseIdentifier: "InputTextFieldCell")
    }

    // MARK: - Actions

    @IBAction func loginButtonTapped(_ sender: UIButton) {
        let email = emailText.trimmingCharacters(in: .whitespacesAndNewlines)
        let password = passwordText

        guard !email.isEmpty, !password.isEmpty else {
            showAlert(title: "Missing Fields", message: "Please enter your email and password.")
            return
        }

        setLoading(true)

        Task {
            do {
                try await AuthManager.shared.signIn(email: email, password: password)
                await MainActor.run { self.routeAfterSignIn() }
            } catch {
                await MainActor.run {
                    self.setLoading(false)
                    self.showAlert(title: "Login Failed", message: error.localizedDescription)
                }
            }
        }
    }

    /// Called from storyboard "Continue with Google" button
    @IBAction func googleSignInTapped(_ sender: UIButton) {
        setLoading(true)

        Task {
            do {
                try await AuthManager.shared.signInWithGoogle(presenting: self)
                await MainActor.run { self.routeAfterSignIn() }
            } catch {
                await MainActor.run {
                    self.setLoading(false)

                    // Silently ignore — user simply dismissed the Google sheet
                    if self.isGoogleCancelError(error) { return }

                    self.showAlert(title: "Google Sign-In Failed", message: error.localizedDescription)
                }
            }
        }
    }

    /// Returns true if the error is the user cancelling the Google sign-in sheet.
    private func isGoogleCancelError(_ error: Error) -> Bool {
        let nsError = error as NSError
        // GIDSignInError.canceled = -5  (com.google.GIDSignIn domain)
        return nsError.domain == "com.google.GIDSignIn" && nsError.code == -5
    }

    // MARK: - Helpers

    private func setLoading(_ loading: Bool) {
        loginButton.isEnabled = !loading
        if loading {
            loginButton.setTitle("Signing in…", for: .normal)
        } else {
            loginButton.setTitle("Login", for: .normal)
        }
    }

    // MARK: - Post-sign-in routing

    /// After any successful sign-in, check whether this user already has a profiles row.
    /// - New user (no row) → profile setup screen
    /// - Returning user (row exists with a name) → Main
    private func routeAfterSignIn() {
        Task {
            do {
                let profile = try await AuthManager.shared.fetchProfile()
                let hasProfile = !(profile.firstName ?? "").trimmingCharacters(in: .whitespaces).isEmpty

                if hasProfile {
                    // Pre-populate local store so home screen has data immediately
                    await AuthManager.shared.preloadProfileData()
                }

                await MainActor.run {
                    if hasProfile {
                        self.transitionToMain()
                    } else {
                        self.pushProfileSetup()
                    }
                }
            } catch {
                // No row at all → treat as new user, go to profile setup
                await MainActor.run { self.pushProfileSetup() }
            }
        }
    }

    private func transitionToMain() {
        let storyboard = UIStoryboard(name: "Main", bundle: nil)
        guard let mainTabBarController = storyboard.instantiateInitialViewController() else { return }

        if let windowScene = view.window?.windowScene,
           let window = windowScene.windows.first {
            // White background prevents black flash between VCs during the push animation
            window.backgroundColor = .white
            let transition = CATransition()
            transition.duration = 0.4
            transition.type = .push
            transition.subtype = .fromRight
            transition.timingFunction = CAMediaTimingFunction(name: .easeOut)
            window.layer.add(transition, forKey: kCATransition)
            window.rootViewController = mainTabBarController
        }
    }

    private func pushProfileSetup() {
        let storyboard = UIStoryboard(name: "Onboarding-Login", bundle: nil)
        guard let profileVC = storyboard.instantiateViewController(withIdentifier: "ProfileViewController") as? ProfileViewController else {
            // Storyboard ID not set yet — fallback to Main
            transitionToMain()
            return
        }
        navigationController?.pushViewController(profileVC, animated: true)
    }

    private func showAlert(title: String, message: String) {
        let alert = UIAlertController(title: title, message: message, preferredStyle: .alert)
        alert.addAction(UIAlertAction(title: "OK", style: .default))
        present(alert, animated: true)
    }
}

// MARK: - UITableViewDelegate, UITableViewDataSource
extension LoginViewController: UITableViewDelegate, UITableViewDataSource {

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

        if indexPath.section == 0 {
            cell.inputTextField.placeholder = "Enter your email"
            cell.inputTextField.isSecureTextEntry = false
            cell.inputTextField.keyboardType = .emailAddress
            cell.inputTextField.text = emailText
            cell.didChangeText = { [weak self] text in self?.emailText = text }
        } else {
            cell.inputTextField.placeholder = "Enter your password"
            cell.inputTextField.isSecureTextEntry = true
            cell.inputTextField.keyboardType = .default
            cell.inputTextField.text = passwordText
            cell.didChangeText = { [weak self] text in self?.passwordText = text }
        }

        return cell
    }

    func tableView(_ tableView: UITableView, heightForRowAt indexPath: IndexPath) -> CGFloat { 55 }

    func tableView(_ tableView: UITableView, heightForHeaderInSection section: Int) -> CGFloat {
        section == 1 ? 10 : 0.01
    }

    func tableView(_ tableView: UITableView, viewForHeaderInSection section: Int) -> UIView? {
        let view = UIView(); view.backgroundColor = .clear; return view
    }

    func tableView(_ tableView: UITableView, heightForFooterInSection section: Int) -> CGFloat { 0.01 }

    func tableView(_ tableView: UITableView, viewForFooterInSection section: Int) -> UIView? {
        let view = UIView(); view.backgroundColor = .clear; return view
    }
}
