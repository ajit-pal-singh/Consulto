//
//  ProfileViewController.swift  (Onboarding)
//  Consulto
//
//  Created by Ajitpal Singh on 02/04/26.
//

import PhotosUI
import UIKit
import Supabase
import Auth

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
    private var selectedProfileImage: UIImage?

    override func viewDidLoad() {
        super.viewDidLoad()
        setupTableView()
        setupProfilePhoto()

        let tap = UITapGestureRecognizer(target: self.view, action: #selector(UIView.endEditing))
        tap.cancelsTouchesInView = false
        view.addGestureRecognizer(tap)
    }

    private func setupProfilePhoto() {
        let tapGesture = UITapGestureRecognizer(target: self, action: #selector(photoViewTapped))
        profilePhotoView.addGestureRecognizer(tapGesture)
        profilePhotoView.isUserInteractionEnabled = true

        profileImageView.contentMode = .scaleAspectFill
        profileImageView.layer.cornerRadius =
            profilePhotoView.layer.cornerRadius > 0
            ? profilePhotoView.layer.cornerRadius : profilePhotoView.bounds.height / 2
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

    // MARK: - Done / Save

    @IBAction func doneButtonTapped(_ sender: UIButton) {
        setLoading(true)

        Task {
            do {
                // Build a SupabaseProfile to upsert
                guard let user = try? await supabase.auth.session.user else {
                    await MainActor.run {
                        self.setLoading(false)
                        self.showAlert(title: "Error", message: "Session expired. Please log in again.")
                    }
                    return
                }

                let dobString: String? = {
                    guard let dob = self.dateOfBirth else { return nil }
                    let fmt = DateFormatter()
                    fmt.dateFormat = "yyyy-MM-dd"
                    return fmt.string(from: dob)
                }()

                let profile = SupabaseProfile(
                    id: user.id,
                    firstName: self.firstName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? nil : self.firstName,
                    lastName:  self.lastName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty  ? nil : self.lastName,
                    gender:    self.selectedGender.isEmpty ? nil : self.selectedGender,
                    dateOfBirth: dobString,
                    avatarUrl: nil,
                    createdAt: nil
                )

                try await AuthManager.shared.saveProfile(profile, avatarImage: self.selectedProfileImage)

                // Also update on-device UserProfileStore so rest of app has data immediately
                UserProfileStore.shared.update { local in
                    if !self.firstName.isEmpty { local.firstName = self.firstName }
                    if !self.lastName.isEmpty  { local.lastName  = self.lastName }
                    if let dob = self.dateOfBirth { local.dateOfBirth = dob }
                    local.gender = Gender(displayName: self.selectedGender)
                    local.email  = user.email ?? local.email
                }

                await MainActor.run { self.transitionToMain() }
            } catch {
                await MainActor.run {
                    self.setLoading(false)
                    self.showAlert(title: "Save Failed", message: error.localizedDescription)
                }
            }
        }
    }

    private func transitionToMain() {
        let storyboard = UIStoryboard(name: "Main", bundle: nil)
        guard let mainVC = storyboard.instantiateInitialViewController() else { return }
        if let windowScene = view.window?.windowScene,
           let window = windowScene.windows.first {
            let transition = CATransition()
            transition.duration = 0.4
            transition.type = .push
            transition.subtype = .fromRight
            transition.timingFunction = CAMediaTimingFunction(name: .easeOut)
            window.layer.add(transition, forKey: kCATransition)
            window.rootViewController = mainVC
        }
    }

    private func setLoading(_ loading: Bool) {
        doneButton.isEnabled = !loading
        doneButton.setTitle(loading ? "Saving…" : "Done", for: .normal)
    }

    private func showAlert(title: String, message: String) {
        let alert = UIAlertController(title: title, message: message, preferredStyle: .alert)
        alert.addAction(UIAlertAction(title: "OK", style: .default))
        present(alert, animated: true)
    }
}

// MARK: - Photo Picker
extension ProfileViewController: PHPickerViewControllerDelegate {
    func picker(_ picker: PHPickerViewController, didFinishPicking results: [PHPickerResult]) {
        picker.dismiss(animated: true)
        guard let provider = results.first?.itemProvider,
              provider.canLoadObject(ofClass: UIImage.self)
        else { return }
        provider.loadObject(ofClass: UIImage.self) { [weak self] image, _ in
            guard let image = image as? UIImage else { return }
            DispatchQueue.main.async {
                self?.profileImageView.image = image
                self?.selectedProfileImage = image
            }
        }
    }
}

// MARK: - Table View
extension ProfileViewController: UITableViewDelegate, UITableViewDataSource {

    func numberOfSections(in tableView: UITableView) -> Int { 4 }
    func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int { 1 }

    func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let greyBg = UIColor(hex: "#F4F4F4") ?? UIColor(red: 0xF4/255.0, green: 0xF4/255.0, blue: 0xF4/255.0, alpha: 1.0)

        switch indexPath.section {
        case 0, 1:
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

        case 2:
            guard let cell = tableView.dequeueReusableCell(withIdentifier: "DateInputCell", for: indexPath) as? DateInputTableViewCell else { return UITableViewCell() }
            cell.selectionStyle = .none
            cell.backgroundColor = .clear
            cell.contentView.backgroundColor = greyBg
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
            cell.containerView.backgroundColor = greyBg
            cell.layer.shadowOpacity = 0
            cell.containerView.layer.shadowOpacity = 0
            cell.containerView.layer.cornerRadius = 27.5
            cell.containerView.layer.masksToBounds = true
            cell.dropdownTextField.placeholder = "Gender"
            cell.options = ["Male", "Female", "Prefer Not To Say"]
            cell.setSelectedOption(selectedGender)
            cell.didChangeSelection = { [weak self] selection in self?.selectedGender = selection }
            return cell

        default:
            return UITableViewCell()
        }
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
