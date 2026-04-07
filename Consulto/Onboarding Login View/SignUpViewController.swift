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
        
        // Hide keyboard when tapping outside
        let tap = UITapGestureRecognizer(target: self.view, action: #selector(UIView.endEditing))
        tap.cancelsTouchesInView = false
        view.addGestureRecognizer(tap)
    }
    
    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        
        // Ensure the navigation bar is visible for the Sign Up screen
        navigationController?.setNavigationBarHidden(false, animated: animated)
    }
    
    private func setupTableView() {
        tableView.delegate = self
        tableView.dataSource = self
        tableView.separatorStyle = .none
        
        // Register the shared input cell
        let nib = UINib(nibName: "InputTextFieldTableViewCell", bundle: nil)
        tableView.register(nib, forCellReuseIdentifier: "InputTextFieldCell")
    }
}

// MARK: - UITableViewDelegate, UITableViewDataSource
extension SignUpViewController: UITableViewDelegate, UITableViewDataSource {
    
    // 3 sections for 3 fields to create natural gaps
    func numberOfSections(in tableView: UITableView) -> Int {
        return 3
    }
    
    func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        return 1
    }
    
    func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        guard let cell = tableView.dequeueReusableCell(withIdentifier: "InputTextFieldCell", for: indexPath) as? InputTextFieldTableViewCell else {
            return UITableViewCell()
        }
        
        cell.selectionStyle = .none
        
        // Match the Figma #F4F4F4 grey background
        let greyBg = UIColor(hex: "#F4F4F4") ?? UIColor(red: 0xF4/255.0, green: 0xF4/255.0, blue: 0xF4/255.0, alpha: 1.0)
        
        // The cell itself should be clear! Apply the color & shape to the contentView.
        cell.backgroundColor = .clear
        cell.contentView.backgroundColor = greyBg
        
        // Strip the shadow inherited from the shared cell
        cell.layer.shadowOpacity = 0
        
        // Control the corner radius on contentView (since height is 55, cornerRadius is 27.5)
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
        } else if indexPath.section == 1 {
            cell.inputTextField.placeholder = "Create new password"
            cell.inputTextField.isSecureTextEntry = true
            cell.inputTextField.keyboardType = .default
            cell.inputTextField.text = passwordText
            cell.didChangeText = { [weak self] text in
                self?.passwordText = text
            }
        } else {
            cell.inputTextField.placeholder = "Confirm new password"
            cell.inputTextField.isSecureTextEntry = true
            cell.inputTextField.keyboardType = .default
            cell.inputTextField.text = confirmPasswordText
            cell.didChangeText = { [weak self] text in
                self?.confirmPasswordText = text
            }
        }
        
        return cell
    }
    
    // Explicitly set field height back to 55 to match the Login screen
    func tableView(_ tableView: UITableView, heightForRowAt indexPath: IndexPath) -> CGFloat {
        return 55 
    }
    
    // Set 10pt gaps between the fields
    func tableView(_ tableView: UITableView, heightForHeaderInSection section: Int) -> CGFloat {
        return section > 0 ? 10 : 0.01 
    }
    
    func tableView(_ tableView: UITableView, viewForHeaderInSection section: Int) -> UIView? {
        let view = UIView()
        view.backgroundColor = .clear
        return view
    }
    
    // Force footer to be practically zero to prevent iOS from adding default extra space
    func tableView(_ tableView: UITableView, heightForFooterInSection section: Int) -> CGFloat {
        return 0.01
    }
    
    func tableView(_ tableView: UITableView, viewForFooterInSection section: Int) -> UIView? {
        let view = UIView()
        view.backgroundColor = .clear
        return view
    }
}
