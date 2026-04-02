import UIKit

struct AddConsultationFormData {
    let doctorName: String
    let purpose: String
    let consultationDate: Date
    let time: Date
    let isPaused: Bool
    let repeatDays: Set<String>
    let isSnoozeOn: Bool
    let snoozeTime: String?
}

class AddConsultationTableViewController: UITableViewController {

    var onSave: ((AddConsultationFormData) -> Void)?
    var consultationToEdit: AddConsultationFormData?

    private var doctorName = ""
    private var purpose = ""
    private var consultationDate = Date()
    private var time: Date?
    private var isPaused = false
    private var repeatDays: Set<String> = []
    private var isSnoozeOn = false
    private var snoozeTime = "10 mins"

    override func viewDidLoad() {
        super.viewDidLoad()

        populateExistingValuesIfNeeded()
        setupUI()
        setupNavigationItems()
        registerCells()
    }

    private func populateExistingValuesIfNeeded() {
        guard let consultationToEdit else { return }

        doctorName = consultationToEdit.doctorName
        purpose = consultationToEdit.purpose
        consultationDate = consultationToEdit.consultationDate
        time = consultationToEdit.time
        isPaused = consultationToEdit.isPaused
        repeatDays = consultationToEdit.repeatDays
        isSnoozeOn = consultationToEdit.isSnoozeOn
        snoozeTime = consultationToEdit.snoozeTime ?? "10 mins"
    }

    private func setupUI() {
        tableView.delegate = self
        tableView.dataSource = self

        view.backgroundColor = UIColor(hex: "F5F5F5")
        tableView.backgroundColor = UIColor(hex: "F5F5F5")
        tableView.allowsSelection = false
        tableView.keyboardDismissMode = .interactive
        tableView.sectionHeaderTopPadding = 0
        tableView.contentInset = UIEdgeInsets(top: 12, left: 0, bottom: 24, right: 0)
    }

    private func setupNavigationItems() {
        navigationItem.leftBarButtonItem?.target = self
        navigationItem.leftBarButtonItem?.action = #selector(cancelTapped)

        navigationItem.rightBarButtonItem?.target = self
        navigationItem.rightBarButtonItem?.action = #selector(doneTapped)
        updateDoneButtonState()
    }

    private func registerCells() {
        tableView.register(
            UINib(nibName: "InputTextFieldTableViewCell", bundle: nil),
            forCellReuseIdentifier: "InputTextFieldCell"
        )
        tableView.register(
            UINib(nibName: "DateInputTableViewCell", bundle: nil),
            forCellReuseIdentifier: "DateInputCell"
        )
        tableView.register(
            UINib(nibName: "TimeInputTableViewCell", bundle: nil),
            forCellReuseIdentifier: "TimeCell"
        )
        tableView.register(
            UINib(nibName: "ScheduleOptionsTableViewCell", bundle: nil),
            forCellReuseIdentifier: "OptionsCell"
        )
        tableView.register(
            UINib(nibName: "SnoozeTableViewCell", bundle: nil),
            forCellReuseIdentifier: "SnoozeCell"
        )
    }

    @objc private func cancelTapped() {
        dismiss(animated: true)
    }

    @objc private func doneTapped() {
        view.endEditing(true)

        guard isFormValid else { return }

        let formData = AddConsultationFormData(
            doctorName: doctorName.trimmingCharacters(in: .whitespacesAndNewlines),
            purpose: purpose.trimmingCharacters(in: .whitespacesAndNewlines),
            consultationDate: consultationDate,
            time: time ?? consultationDate,
            isPaused: isPaused,
            repeatDays: repeatDays,
            isSnoozeOn: isSnoozeOn,
            snoozeTime: isSnoozeOn ? snoozeTime : nil
        )

        onSave?(formData)
        dismiss(animated: true)
    }

    private var isFormValid: Bool {
        !doctorName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
        && !purpose.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
        && time != nil
    }

    private func updateDoneButtonState() {
        navigationItem.rightBarButtonItem?.isEnabled = isFormValid
    }

    private func repeatText() -> String {
        if repeatDays.count == 7 { return "Daily" }
        if repeatDays.isEmpty { return "Select Days" }

        let orderedDays = ["Mon", "Tue", "Wed", "Thu", "Fri", "Sat", "Sun"]
        return orderedDays.filter { repeatDays.contains($0) }.joined(separator: ", ")
    }

    private func snoozeActions() -> [UIAction] {
        ["5 mins", "10 mins", "15 mins", "30 mins"].map { value in
            menuAction(title: value, isSelected: (snoozeTime.isEmpty ? "10 mins" : snoozeTime) == value) { [weak self] in
                self?.snoozeTime = value
            }
        }
    }

    private func menuAction(title: String, isSelected: Bool, onSelect: @escaping () -> Void) -> UIAction {
        UIAction(title: title, state: isSelected ? .on : .off) { [weak self] _ in
            onSelect()
            self?.tableView.reloadSections(IndexSet(integer: 3), with: .none)
        }
    }

    private func showRepeatDaysPicker() {
        let pickerVC = RepeatDaysSelectionViewController(selectedDays: repeatDays)
        pickerVC.onDone = { [weak self] selectedDays in
            self?.repeatDays = selectedDays
            self?.tableView.reloadRows(at: [IndexPath(row: 0, section: 3)], with: .none)
        }
        present(pickerVC, animated: true)
    }

    override func numberOfSections(in tableView: UITableView) -> Int {
        4
    }

    override func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        switch section {
        case 0:
            return 2
        case 1:
            return 1
        case 2:
            return 1
        case 3:
            return isSnoozeOn ? 3 : 2
        default:
            return 0
        }
    }

    override func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        switch indexPath.section {
        case 0:
            let cell = tableView.dequeueReusableCell(withIdentifier: "InputTextFieldCell", for: indexPath) as! InputTextFieldTableViewCell
            cell.selectionStyle = .none

            if indexPath.row == 0 {
                cell.inputTextField.placeholder = "Doctor's Name"
                cell.inputTextField.text = doctorName
                cell.didChangeText = { [weak self] text in
                    self?.doctorName = text
                    self?.updateDoneButtonState()
                }
            } else {
                cell.inputTextField.placeholder = "Purpose of Consultation"
                cell.inputTextField.text = purpose
                cell.didChangeText = { [weak self] text in
                    self?.purpose = text
                    self?.updateDoneButtonState()
                }
            }
            return cell

        case 1:
            let cell = tableView.dequeueReusableCell(withIdentifier: "DateInputCell", for: indexPath) as! DateInputTableViewCell
            cell.selectionStyle = .none
            cell.configure(
                placeholder: "Select Date",
                date: consultationToEdit != nil ? consultationDate : nil
            )
            cell.didChangeDate = { [weak self] selectedDate in
                self?.consultationDate = selectedDate
            }
            return cell

        case 2:
            let cell = tableView.dequeueReusableCell(withIdentifier: "TimeCell", for: indexPath) as! TimeInputTableViewCell
            cell.selectionStyle = .none
            cell.configure(
                placeholder: "Select Time",
                time: time
            )
            cell.didChangeTime = { [weak self] selectedTime in
                guard let self = self else { return }
                self.time = selectedTime
                self.updateDoneButtonState()
            }
            return cell

        case 3:
            switch indexPath.row {
            case 0:
                let cell = tableView.dequeueReusableCell(withIdentifier: "OptionsCell", for: indexPath) as! ScheduleOptionsTableViewCell
                cell.configureStatic(title: "Repeat", value: repeatText())
                cell.onTap = { [weak self] in
                    self?.showRepeatDaysPicker()
                }
                return cell

            case 1:
                let cell = tableView.dequeueReusableCell(withIdentifier: "SnoozeCell", for: indexPath) as! SnoozeTableViewCell
                cell.titleLabel.text = "Snooze"
                cell.switchControl.isOn = isSnoozeOn
                cell.onSwitchChanged = { [weak self] isOn in
                    self?.isSnoozeOn = isOn
                    self?.tableView.reloadSections(IndexSet(integer: 3), with: .automatic)
                }
                return cell

            case 2:
                let cell = tableView.dequeueReusableCell(withIdentifier: "OptionsCell", for: indexPath) as! ScheduleOptionsTableViewCell
                cell.configure(
                    title: "Snooze Time",
                    value: snoozeTime.isEmpty ? "10 mins" : snoozeTime,
                    actions: snoozeActions()
                )
                return cell

            default:
                return UITableViewCell()
            }

        default:
            return UITableViewCell()
        }
    }

    override func tableView(_ tableView: UITableView, heightForHeaderInSection section: Int) -> CGFloat {
        6
    }

    override func tableView(_ tableView: UITableView, viewForHeaderInSection section: Int) -> UIView? {
        let view = UIView()
        view.backgroundColor = .clear
        return view
    }

    override func tableView(_ tableView: UITableView, heightForFooterInSection section: Int) -> CGFloat {
        6
    }
}
