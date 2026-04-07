//
//  ProfileViewController.swift
//  Consulto
//
//  Created by Ajitpal Singh on 02/04/26.
//

import UIKit
import PhotosUI

class ProfileViewController: UIViewController {

    @IBOutlet weak var profilePhotoView: UIView!
    @IBOutlet weak var profileImageView: UIImageView!
    @IBOutlet weak var tableView: UITableView!
    @IBOutlet weak var doneButton: UIButton!
    
    // State
    private var firstName: String = ""
    private var lastName: String = ""
    private var dateOfBirth: Date?
    private var selectedGender: String = ""

    override func viewDidLoad() {
        super.viewDidLoad()

        setupTableView()
        setupProfilePhoto()
        
        let tap = UITapGestureRecognizer(target: self.view, action: #selector(UIView.endEditing))
        tap.cancelsTouchesInView = false
        view.addGestureRecognizer(tap)
    }
    
    private func setupProfilePhoto() {
        // Prepare the photo view tap action
        let tapGesture = UITapGestureRecognizer(target: self, action: #selector(photoViewTapped))
        profilePhotoView.addGestureRecognizer(tapGesture)
        profilePhotoView.isUserInteractionEnabled = true
        
        // Ensure image view perfectly fits inside the circular container!
        profileImageView.contentMode = .scaleAspectFill
        profileImageView.layer.cornerRadius = profilePhotoView.layer.cornerRadius > 0 ? profilePhotoView.layer.cornerRadius : profilePhotoView.bounds.height / 2
        profileImageView.clipsToBounds = true
    }
    
    @objc private func photoViewTapped() {
        var config = PHPickerConfiguration()
        config.selectionLimit = 1
        config.filter = .images
        
        let picker = PHPickerViewController(configuration: config)
        picker.delegate = self
        present(picker, animated: true)
    }
    
    private func setupTableView() {
        tableView.delegate = self
        tableView.dataSource = self
        tableView.separatorStyle = .none
        
        tableView.register(UINib(nibName: "InputTextFieldTableViewCell", bundle: nil), forCellReuseIdentifier: "InputTextFieldCell")
        tableView.register(UINib(nibName: "DateInputTableViewCell", bundle: nil), forCellReuseIdentifier: "DateInputCell")
        tableView.register(UINib(nibName: "DropdownTableViewCell", bundle: nil), forCellReuseIdentifier: "DropdownCell")
    }
    
    // MARK: - Actions
    @IBAction func doneButtonTapped(_ sender: UIButton) {
        // Find the LoginViewController in our stack and pop directly to it
        if let nav = navigationController {
            for controller in nav.viewControllers {
                if controller is LoginViewController {
                    nav.popToViewController(controller, animated: true)
                    return
                }
            }
        }
    }
}

// MARK: - Photo Picker
extension ProfileViewController: PHPickerViewControllerDelegate {
    func picker(_ picker: PHPickerViewController, didFinishPicking results: [PHPickerResult]) {
        picker.dismiss(animated: true)
        
        guard let provider = results.first?.itemProvider, provider.canLoadObject(ofClass: UIImage.self) else { return }
        
        provider.loadObject(ofClass: UIImage.self) { [weak self] image, error in
            guard let image = image as? UIImage else { return }
            DispatchQueue.main.async {
                self?.profileImageView.image = image
            }
        }
    }
}

// MARK: - Table View
extension ProfileViewController: UITableViewDelegate, UITableViewDataSource {
    
    func numberOfSections(in tableView: UITableView) -> Int {
        return 4
    }
    
    func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        return 1
    }
    
    func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        
        let greyBg = UIColor(hex: "#F4F4F4") ?? UIColor(red: 0xF4/255.0, green: 0xF4/255.0, blue: 0xF4/255.0, alpha: 1.0)
        
        switch indexPath.section {
        case 0, 1: // First Name, Last Name
            guard let cell = tableView.dequeueReusableCell(withIdentifier: "InputTextFieldCell", for: indexPath) as? InputTextFieldTableViewCell else { return UITableViewCell() }
            
            cell.selectionStyle = .none
            cell.backgroundColor = .clear
            cell.contentView.backgroundColor = greyBg
            cell.layer.shadowOpacity = 0
            cell.contentView.layer.cornerRadius = 27.5
            cell.contentView.layer.masksToBounds = true
            
            cell.inputTextField.isSecureTextEntry = false
            cell.inputTextField.keyboardType = .default
            
            if indexPath.section == 0 {
                cell.inputTextField.placeholder = "Enter First Name"
                cell.inputTextField.text = firstName
                cell.didChangeText = { [weak self] text in self?.firstName = text }
            } else {
                cell.inputTextField.placeholder = "Enter Last Name"
                cell.inputTextField.text = lastName
                cell.didChangeText = { [weak self] text in self?.lastName = text }
            }
            return cell
            
        case 2: // Date of Birth
            guard let cell = tableView.dequeueReusableCell(withIdentifier: "DateInputCell", for: indexPath) as? DateInputTableViewCell else { return UITableViewCell() }
            
            cell.selectionStyle = .none
            cell.backgroundColor = .clear
            cell.contentView.backgroundColor = greyBg
            cell.layer.shadowOpacity = 0
            cell.contentView.layer.cornerRadius = 27.5
            cell.contentView.layer.masksToBounds = true
            
            // Allow past dates, but prevent future dates for DOB
            cell.compactDatePicker.maximumDate = Date()
            cell.compactDatePicker.minimumDate = nil 
            
            cell.dateTextField.placeholder = "Date of Birth"
            
            if let date = dateOfBirth {
                cell.setDate(date)
            }
            cell.didChangeDate = { [weak self] date in self?.dateOfBirth = date }
            return cell
            
        case 3: // Gender
            guard let cell = tableView.dequeueReusableCell(withIdentifier: "DropdownCell", for: indexPath) as? DropdownTableViewCell else { return UITableViewCell() }
            
            cell.selectionStyle = .none
            cell.backgroundColor = .clear
            cell.contentView.backgroundColor = .clear
            
            // Dropdown cell famously has an inner containerView that blocks color! We color that instead.
            cell.containerView.backgroundColor = greyBg
            
            cell.layer.shadowOpacity = 0
            cell.containerView.layer.shadowOpacity = 0
            
            cell.containerView.layer.cornerRadius = 27.5
            cell.containerView.layer.masksToBounds = true
            
            cell.dropdownTextField.placeholder = "Gender"
            cell.options = ["Male", "Female", "Prefer Not To Say"]
            cell.setSelectedOption(selectedGender)
            
            cell.didChangeSelection = { [weak self] selection in
                self?.selectedGender = selection
            }
            return cell
            
        default:
            return UITableViewCell()
        }
    }
    
    // Explicitly set field heights
    func tableView(_ tableView: UITableView, heightForRowAt indexPath: IndexPath) -> CGFloat {
        return 55 
    }
    
    func tableView(_ tableView: UITableView, heightForHeaderInSection section: Int) -> CGFloat {
        return section > 0 ? 10 : 0.01 
    }
    
    func tableView(_ tableView: UITableView, viewForHeaderInSection section: Int) -> UIView? {
        let view = UIView()
        view.backgroundColor = .clear
        return view
    }
    
    func tableView(_ tableView: UITableView, heightForFooterInSection section: Int) -> CGFloat {
        return 0.01
    }
    
    func tableView(_ tableView: UITableView, viewForFooterInSection section: Int) -> UIView? {
        let view = UIView()
        view.backgroundColor = .clear
        return view
    }
}
