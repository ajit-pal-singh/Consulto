
import UIKit

var user = UserProfile(
    id: UUID(),
    firstName: "Demo",
    lastName: "User",
    dateOfBirth: Date(),
    gender: .preferNotToSay,
    createdAt: Date()
)

class ProfileSettingsViewController: UIViewController {

    @IBOutlet weak var tableView: UITableView!

    var sections: [[(title: String, value: String, icon: String?)]] {
        return [
            [
                ("Name", "\(user.firstName) \(user.lastName)", nil),
                ("Gender", genderText(user.gender), nil),
                ("Date of Birth", formatDate(user.dateOfBirth), nil),
            ],
            [
                ("Email", "demouser@gmail.com", nil),
                ("Change Password", "", nil),
            ],
            [
                ("Terms & Conditions", "", "doc.text"),
                ("Privacy Policy", "", "shield"),
            ],
            [
                ("Sign Out", "", nil)
            ],
        ]
    }

    func genderText(_ gender: Gender) -> String {
        switch gender {
        case .male: return "Male"
        case .female: return "Female"
        case .preferNotToSay: return "Prefer not to say"
        }
    }

    func formatDate(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "dd-MMM-yyyy"
        return formatter.string(from: date)
    }

    override func viewDidLoad() {
        super.viewDidLoad()

        navigationItem.rightBarButtonItem?.target = self
        navigationItem.rightBarButtonItem?.action = #selector(editProfileTapped)

        tableView.register(
            UINib(nibName: "ProfileDetailsTableViewCell", bundle: nil),
            forCellReuseIdentifier: "ProfileDetailsCell")
        tableView.register(
            UINib(nibName: "PasswordTableViewCell", bundle: nil),
            forCellReuseIdentifier: "PasswordCell")
        tableView.register(
            UINib(nibName: "IconDetailsTableViewCell", bundle: nil),
            forCellReuseIdentifier: "IconDetailsCell")
        tableView.delegate = self
        tableView.dataSource = self

        tableView.backgroundColor = UIColor(hex: "F5F5F5")
        self.view.backgroundColor = UIColor(hex: "F5F5F5")

        setupHeaderView()
        setupFooterView()
    }

    @objc func editProfileTapped() {
        let storyboard = UIStoryboard(name: "Home_Screen", bundle: nil)
        if let editVC = storyboard.instantiateViewController(
            withIdentifier: "ProfileEditViewController") as? ProfileEditViewController
        {
            editVC.firstName = user.firstName
            editVC.lastName = user.lastName
            editVC.dateOfBirth = user.dateOfBirth

            if user.gender == .preferNotToSay {
                editVC.selectedGender = "Prefer Not To Say"
            } else {
                editVC.selectedGender = self.genderText(user.gender)
            }

            editVC.onSave = { [weak self] newFirstName, newLastName, newDOB, newGenderText in
                user.firstName = newFirstName
                user.lastName = newLastName
                if let dob = newDOB {
                    user.dateOfBirth = dob
                }

                if newGenderText == "Male" {
                    user.gender = .male
                } else if newGenderText == "Female" {
                    user.gender = .female
                } else {
                    user.gender = .preferNotToSay
                }

                self?.setupHeaderView()
                self?.tableView.reloadData()
            }

            navigationController?.pushViewController(editVC, animated: true)
        }
    }

    @objc func logoutTapped() {
        let alert = UIAlertController(
            title: "Log out", message: "Are you sure you want to log out of your account?",
            preferredStyle: .alert)
        alert.addAction(UIAlertAction(title: "Cancel", style: .cancel, handler: nil))
        alert.addAction(
            UIAlertAction(
                title: "Sign Out", style: .destructive,
                handler: { _ in
                    let storyboard = UIStoryboard(name: "Onboarding-Login", bundle: nil)
                    if let initialVC = storyboard.instantiateInitialViewController() {
                        if let windowScene = UIApplication.shared.connectedScenes.first
                            as? UIWindowScene,
                            let window = windowScene.windows.first
                        {
                            window.rootViewController = initialVC
                            UIView.transition(
                                with: window, duration: 0.3, options: .transitionCrossDissolve,
                                animations: nil, completion: nil)
                        }
                    }
                }))
        present(alert, animated: true, completion: nil)
    }

    @IBAction func cancelButtonTapped(_ sender: Any) {
        dismiss(animated: true, completion: nil)
    }

    func setupHeaderView() {
        let headerView = UIView(frame: CGRect(x: 0, y: 0, width: view.frame.width, height: 190))

        let imgView = UIImageView()
        if let savedImage = ProfileImageManager.shared.fetchImage() {
            imgView.image = savedImage
        } else {
            imgView.image = UIImage(named: "DefaultProfile")
        }
        imgView.contentMode = .scaleAspectFill
        imgView.clipsToBounds = true
        imgView.layer.cornerRadius = 65
        imgView.translatesAutoresizingMaskIntoConstraints = false

        let nLabel = UILabel()
        nLabel.text = "\(user.firstName) \(user.lastName)"
        nLabel.font = .systemFont(ofSize: 24, weight: .bold).rounded
        nLabel.textAlignment = .center
        nLabel.translatesAutoresizingMaskIntoConstraints = false

        headerView.addSubview(imgView)
        headerView.addSubview(nLabel)

        NSLayoutConstraint.activate([
            imgView.centerXAnchor.constraint(equalTo: headerView.centerXAnchor),
            imgView.topAnchor.constraint(equalTo: headerView.topAnchor, constant: 10),
            imgView.widthAnchor.constraint(equalToConstant: 130),
            imgView.heightAnchor.constraint(equalToConstant: 130),

            nLabel.centerXAnchor.constraint(equalTo: headerView.centerXAnchor),
            nLabel.topAnchor.constraint(equalTo: imgView.bottomAnchor, constant: 14),
        ])

        tableView.tableHeaderView = headerView
    }

    func setupFooterView() {
        let footerView = UIView(frame: CGRect(x: 0, y: 0, width: view.frame.width, height: 60))

        let logoContainer = UIStackView()
        logoContainer.axis = .vertical
        logoContainer.alignment = .center
        logoContainer.spacing = 4
        logoContainer.translatesAutoresizingMaskIntoConstraints = false

        let logoLabel = UILabel()
        logoLabel.text = "CONSULTO®"
        logoLabel.font = .systemFont(ofSize: 16, weight: .bold).rounded
        logoLabel.textColor = UIColor(red: 0.1, green: 0.5, blue: 1.0, alpha: 1)

        let versionLabel = UILabel()
        versionLabel.text = "v1.0.0\n© 2026 Consulto. All Rights Reservered."
        versionLabel.font = .systemFont(ofSize: 9, weight: .medium).rounded
        versionLabel.textColor = .darkGray
        versionLabel.numberOfLines = 2
        versionLabel.textAlignment = .center

        logoContainer.addArrangedSubview(logoLabel)
        logoContainer.addArrangedSubview(versionLabel)

        footerView.addSubview(logoContainer)

        NSLayoutConstraint.activate([
            logoContainer.topAnchor.constraint(equalTo: footerView.topAnchor, constant: 16),
            logoContainer.centerXAnchor.constraint(equalTo: footerView.centerXAnchor),
        ])
        tableView.tableFooterView = footerView
    }
}

extension ProfileSettingsViewController: UITableViewDelegate, UITableViewDataSource {

    func numberOfSections(in tableView: UITableView) -> Int {
        return sections.count
    }

    func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        return sections[section].count
    }

    func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let item = sections[indexPath.section][indexPath.row]

        if indexPath.section == 0 || (indexPath.section == 1 && indexPath.row == 0) {
            // Name, Gender, DOB and Email use ProfileDetailsTableViewCell
            let cell =
                tableView.dequeueReusableCell(withIdentifier: "ProfileDetailsCell", for: indexPath)
                as! ProfileDetailsTableViewCell
            cell.configure(title: item.title, value: item.value)
            cell.selectionStyle = .none
            return cell
        } else if indexPath.section == 1 && indexPath.row == 1 {
            // Change Password uses PasswordCell
            let cell =
                tableView.dequeueReusableCell(withIdentifier: "PasswordCell", for: indexPath)
                as! PasswordTableViewCell
            cell.configure(title: item.title)
            cell.chevronImageView.isHidden = false
            cell.selectionStyle = .none
            return cell
        } else if indexPath.section == 2 {
            // Privacy Policy and Terms use IconDetailsTableViewCell
            let cell =
                tableView.dequeueReusableCell(withIdentifier: "IconDetailsCell", for: indexPath)
                as! IconDetailsTableViewCell
            cell.configure(
                title: item.title, icon: UIImage(systemName: item.icon ?? ""), tintColor: .black)
            cell.chevronImageView.isHidden = false
            cell.selectionStyle = .none
            return cell
        } else {
            // Sign Out using IconDetailsTableViewCell
            let cell =
                tableView.dequeueReusableCell(withIdentifier: "IconDetailsCell", for: indexPath)
                as! IconDetailsTableViewCell
            cell.configure(
                title: item.title, icon: UIImage(systemName: "rectangle.portrait.and.arrow.right"),
                tintColor: .systemRed)
            cell.titleLabel.textColor = .systemRed
            cell.chevronImageView.isHidden = true
            cell.selectionStyle = .none
            return cell
        }
        return UITableViewCell()
    }

    func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        let item = sections[indexPath.section][indexPath.row]

        if indexPath.section == 1 && indexPath.row == 1 {
            let storyboard = UIStoryboard(name: "Home_Screen", bundle: nil)
            if let vc = storyboard.instantiateViewController(
                withIdentifier: "ChangePasswordViewController") as? ChangePasswordViewController
            {
                navigationController?.pushViewController(vc, animated: true)
            }
        } else if indexPath.section == 3 {
            if item.title == "Sign Out" {
                logoutTapped()
            }
        }
    }

    func tableView(_ tableView: UITableView, heightForHeaderInSection section: Int) -> CGFloat {
        return section == 0 ? 10 : 6
    }

    func tableView(_ tableView: UITableView, heightForFooterInSection section: Int) -> CGFloat {
        return section == 3 ? 40 : 6
    }

    func tableView(_ tableView: UITableView, viewForHeaderInSection section: Int) -> UIView? {
        let view = UIView()
        view.backgroundColor = .clear
        return view
    }

    func tableView(_ tableView: UITableView, viewForFooterInSection section: Int) -> UIView? {
        let view = UIView()
        view.backgroundColor = .clear
        return view
    }

}
