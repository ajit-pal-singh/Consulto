//
//  ProfileEditViewController.swift
//  Consulto
//

import UIKit
import PhotosUI

class ProfileEditViewController: UIViewController {

    @IBOutlet weak var profilePhotoView: UIView!
    @IBOutlet weak var profileImageView: UIImageView!
    @IBOutlet weak var cameraOverlayView: UIView!
    @IBOutlet weak var contentView: UIView!
    @IBOutlet weak var tableView: UITableView!
    
    var firstName: String = ""
    var lastName: String = ""
    var dateOfBirth: Date?
    var selectedGender: String = ""
    var selectedProfileImage: UIImage?
    
    var onSave: ((String, String, Date?, String) -> Void)?
    
    override func viewDidLoad() {
        super.viewDidLoad()
        view.backgroundColor = UIColor(hex: "F5F5F5")
        contentView.backgroundColor = UIColor(hex: "F5F5F5")
        
        setupTableView()
        
        if let customImage = ProfileImageManager.shared.fetchImage() {
            profileImageView.image = customImage
        } else {
            profileImageView.image = UIImage(named: "DefaultProfile") 
        }
        
        if let photoView = profilePhotoView {
            photoView.isUserInteractionEnabled = true
            let photoTap = UITapGestureRecognizer(target: self, action: #selector(photoViewTapped))
            photoView.addGestureRecognizer(photoTap)
            
            profileImageView.contentMode = .scaleAspectFill
            profileImageView.clipsToBounds = true
        }
        
        let tap = UITapGestureRecognizer(target: self.view, action: #selector(UIView.endEditing))
        tap.cancelsTouchesInView = false
        view.addGestureRecognizer(tap)
    }
    
    override func viewDidLayoutSubviews() {
        super.viewDidLayoutSubviews()
        
        if let photoView = profilePhotoView, let imgView = profileImageView {
            let radius = photoView.layer.cornerRadius > 0 ? photoView.layer.cornerRadius : photoView.bounds.height / 2
            imgView.layer.cornerRadius = radius
            photoView.layer.cornerRadius = radius
        }
        
        if let overlay = cameraOverlayView {
            overlay.layer.cornerRadius = overlay.layer.cornerRadius > 0 ? overlay.layer.cornerRadius : overlay.bounds.height / 2
            overlay.clipsToBounds = true
        }
    }
    
    @IBAction func saveChangesTapped(_ sender: Any) {
        if let image = selectedProfileImage {
            ProfileImageManager.shared.saveImage(image)
        }
        onSave?(firstName, lastName, dateOfBirth, selectedGender)
        navigationController?.popViewController(animated: true)
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
        tableView.register(UINib(nibName: "InputTextFieldTableViewCell", bundle: nil), forCellReuseIdentifier: "InputTextFieldCell")
        tableView.register(UINib(nibName: "DateInputTableViewCell", bundle: nil), forCellReuseIdentifier: "DateInputCell")
        tableView.register(UINib(nibName: "DropdownTableViewCell", bundle: nil), forCellReuseIdentifier: "DropdownCell")
    }
}

extension ProfileEditViewController: PHPickerViewControllerDelegate {
    func picker(_ picker: PHPickerViewController, didFinishPicking results: [PHPickerResult]) {
        picker.dismiss(animated: true)
        guard let provider = results.first?.itemProvider, provider.canLoadObject(ofClass: UIImage.self) else { return }
        provider.loadObject(ofClass: UIImage.self) { [weak self] image, error in
            guard let image = image as? UIImage else { return }
            DispatchQueue.main.async {
                self?.profileImageView.image = image
                self?.selectedProfileImage = image
            }
        }
    }
}

extension ProfileEditViewController: UITableViewDelegate, UITableViewDataSource {
    func numberOfSections(in tableView: UITableView) -> Int { return 4 }
    func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int { return 1 }
    
    func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let greyBg = UIColor(hex: "#F4F4F4") ?? UIColor(red: 0xF4/255.0, green: 0xF4/255.0, blue: 0xF4/255.0, alpha: 1.0)
        
        switch indexPath.section {
        case 0, 1:
            guard let cell = tableView.dequeueReusableCell(withIdentifier: "InputTextFieldCell", for: indexPath) as? InputTextFieldTableViewCell else { return UITableViewCell() }
            cell.selectionStyle = .none
            cell.backgroundColor = .clear
            cell.contentView.backgroundColor = .white
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
            
        case 2:
            guard let cell = tableView.dequeueReusableCell(withIdentifier: "DateInputCell", for: indexPath) as? DateInputTableViewCell else { return UITableViewCell() }
            cell.selectionStyle = .none
            cell.backgroundColor = .clear
            cell.contentView.backgroundColor = .white
            cell.layer.shadowOpacity = 0
            cell.contentView.layer.cornerRadius = 27.5
            cell.contentView.layer.masksToBounds = true
            cell.compactDatePicker.maximumDate = Date()
            cell.compactDatePicker.minimumDate = nil
            cell.dateTextField.placeholder = "Date of Birth"
            if let date = dateOfBirth { cell.setDate(date) }
            cell.didChangeDate = { [weak self] date in self?.dateOfBirth = date }
            return cell
            
        case 3:
            guard let cell = tableView.dequeueReusableCell(withIdentifier: "DropdownCell", for: indexPath) as? DropdownTableViewCell else { return UITableViewCell() }
            cell.selectionStyle = .none
            cell.backgroundColor = .clear
            cell.contentView.backgroundColor = .clear
            cell.containerView.backgroundColor = .white
            cell.layer.shadowOpacity = 0
            cell.containerView.layer.shadowOpacity = 0
            cell.containerView.layer.cornerRadius = 27.5
            cell.containerView.layer.masksToBounds = true
            cell.dropdownTextField.placeholder = "Gender"
            cell.options = ["Male", "Female", "Prefer Not To Say"]
            cell.setSelectedOption(selectedGender)
            cell.didChangeSelection = { [weak self] selection in self?.selectedGender = selection }
            return cell
            
        default: return UITableViewCell()
        }
    }
    
    func tableView(_ tableView: UITableView, heightForRowAt indexPath: IndexPath) -> CGFloat { return 55 }
    func tableView(_ tableView: UITableView, heightForHeaderInSection section: Int) -> CGFloat { return section > 0 ? 16 : 0.01 }
    func tableView(_ tableView: UITableView, viewForHeaderInSection section: Int) -> UIView? { 
        let view = UIView()
        view.backgroundColor = .clear
        return view 
    }
    func tableView(_ tableView: UITableView, heightForFooterInSection section: Int) -> CGFloat { return 0.01 }
    func tableView(_ tableView: UITableView, viewForFooterInSection section: Int) -> UIView? { return UIView() }
}
