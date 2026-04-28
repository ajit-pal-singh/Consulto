//
//  LoginViewController.swift
//  Consulto
//
//  Created by Ajitpal Singh on 30/03/26.
//

import UIKit

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
//        setupCreateAccountButton()
        
        // Hide keyboard when tapping outside
        let tap = UITapGestureRecognizer(target: self.view, action: #selector(UIView.endEditing))
        tap.cancelsTouchesInView = false
        view.addGestureRecognizer(tap)
    }
    
    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        
        // Hide the navigation bar for the Login screen
        navigationController?.setNavigationBarHidden(true, animated: animated)
    }
    
    private func setupTableView() {
        tableView.delegate = self
        tableView.dataSource = self
        tableView.separatorStyle = .none
        
        let nib = UINib(nibName: "InputTextFieldTableViewCell", bundle: nil)
        tableView.register(nib, forCellReuseIdentifier: "InputTextFieldCell")
    }
    
//    private func setupCreateAccountButton() {
//        // Use the existing hex extension, fallback if it fails
//        
//        var config = createAccountButton.configuration ?? UIButton.Configuration.plain()
//        config.baseForegroundColor = UIColor(hex: "#1A90FF") 
//        config.background.strokeColor = UIColor(hex: "#1A90FF") 
//        config.background.strokeWidth = 2
//        config.cornerStyle = .capsule
//        
//        createAccountButton.configuration = config
//    }
    
    @IBAction func loginButtonTapped(_ sender: UIButton) {
        // 1. Check Dummy Credentials
        if emailText.trimmingCharacters(in: .whitespacesAndNewlines).lowercased() == "demouser@gmail.com" && passwordText == "1234" {
            
            // 2. Persist the login state
            UserDefaults.standard.set(true, forKey: "isLoggedIn")
            
            // 3. Transition to the Main Storyboard beautifully
            let storyboard = UIStoryboard(name: "Main", bundle: nil)
            guard let mainTabBarController = storyboard.instantiateInitialViewController() else { return }
            
            // Swap out the root view controller with a pure core animation fade
            if let windowScene = view.window?.windowScene,
               let window = windowScene.windows.first {
               
                let transition = CATransition()
                transition.duration = 0.4
                transition.type = .push // Change from .fade to .push
                transition.subtype = .fromRight // Slide in from the right
                transition.timingFunction = CAMediaTimingFunction(name: .easeOut)
                
                window.layer.add(transition, forKey: kCATransition)
                window.rootViewController = mainTabBarController
            }
            
        } else {
            // Show an error alert if credentials don't match
            let alert = UIAlertController(title: "Login Failed", message: "Incorrect email or password.", preferredStyle: .alert)
            alert.addAction(UIAlertAction(title: "OK", style: .default))
            present(alert, animated: true)
        }
    }
}

// MARK: - UITableViewDelegate, UITableViewDataSource
extension LoginViewController: UITableViewDelegate, UITableViewDataSource {
    
    // We can use 2 sections with 1 row each to naturally create spacing,
    // exactly how PreviewViewController does it.
    func numberOfSections(in tableView: UITableView) -> Int {
        return 2
    }
    
    func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        return 1
    }
    
    func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        guard let cell = tableView.dequeueReusableCell(withIdentifier: "InputTextFieldCell", for: indexPath) as? InputTextFieldTableViewCell else {
            return UITableViewCell()
        }
        
        cell.selectionStyle = .none
        
        let greyBg = UIColor(hex: "#F4F4F4") ?? UIColor(red: 0xF4/255.0, green: 0xF4/255.0, blue: 0xF4/255.0, alpha: 1.0)
        
        // The cell itself should be clear! we apply the color & shape to the contentView.
        cell.backgroundColor = .clear
        cell.contentView.backgroundColor = greyBg
        
        // Strip the shadow inherited from the shared InputTextFieldCell for the login screen
        cell.layer.shadowOpacity = 0
        
        // Control the corner radius on contentView (since height is 60, cornerRadius of 30 makes a perfect pill)
        cell.contentView.layer.cornerRadius = 27.5
        cell.contentView.layer.masksToBounds = true
        
        if indexPath.section == 0 {
            cell.inputTextField.placeholder = "Enter your email"
            cell.inputTextField.isSecureTextEntry = false
            cell.inputTextField.keyboardType = .emailAddress
            cell.inputTextField.text = emailText
            cell.didChangeText = { [weak self] text in
                self?.emailText = text
            }
        } else {
            cell.inputTextField.placeholder = "Enter your password"
            cell.inputTextField.isSecureTextEntry = true
            cell.inputTextField.keyboardType = .default
            cell.inputTextField.text = passwordText
            cell.didChangeText = { [weak self] text in
                self?.passwordText = text
            }
        }
        
        return cell
    }
    
    func tableView(_ tableView: UITableView, heightForRowAt indexPath: IndexPath) -> CGFloat {
        // Intrinsic height is around 54. Increasing it to 64 makes the fields taller (+10) 
        return 55 
    }
    
    func tableView(_ tableView: UITableView, heightForHeaderInSection section: Int) -> CGFloat {
        return section == 1 ? 10 : 0.01 // Adjust this to make the gap bigger/smaller!
    }
    
    func tableView(_ tableView: UITableView, viewForHeaderInSection section: Int) -> UIView? {
        let view = UIView()
        view.backgroundColor = .clear
        return view
    }
    
    //  We MUST override the footer height to 0.01, otherwise iOS adds a hidden 20pt gap here automatically!
    func tableView(_ tableView: UITableView, heightForFooterInSection section: Int) -> CGFloat {
        return 0.01
    }
    
    func tableView(_ tableView: UITableView, viewForFooterInSection section: Int) -> UIView? {
        let view = UIView()
        view.backgroundColor = .clear
        return view
    }
}
