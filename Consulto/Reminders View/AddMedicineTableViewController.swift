import UIKit

struct AddMedicineFormData {
    let medicineName: String
    let dosage: String?
    let times: [Date]
    let inactiveTimes: [Date]
    let mealTiming: MealTiming
    let repeatDays: Set<String>
    let isSnoozeOn: Bool
    let snoozeTime: String?
}

class AddMedicineTableViewController: UITableViewController {
    
    var medicationToEdit: Medication?
    var times: [Date] = []
    var inactiveTimes: [Date] = []
    var mealTiming: MealTiming? = .afterMeal
    var repeatDays: Set<String> = []
    var isSnoozeOn: Bool = false
    var snoozeTime: String = "10 mins"

    var onSave: ((AddMedicineFormData) -> Void)?
    private var medicineName = ""
    private var dosageValue = ""
    private var selectedUnit: String?

    override func viewDidLoad() {
        super.viewDidLoad()

        populateExistingValuesIfNeeded()
        setupUI()
        setupNavigationItems()

        tableView.register(UINib(nibName: "NameInputTableViewCell", bundle: nil), forCellReuseIdentifier: "NameInputCell")
        tableView.register(UINib(nibName: "DosageValueTableViewCell", bundle: nil), forCellReuseIdentifier: "DosageValueCell")
        tableView.register(UINib(nibName: "DosageUnitTableViewCell", bundle: nil), forCellReuseIdentifier: "DosageUnitCell")
        tableView.register(UINib(nibName: "AddActionTableViewCell", bundle: nil), forCellReuseIdentifier: "AddActionCell")
        tableView.register(UINib(nibName: "ReminderTimeTableViewCell", bundle: nil), forCellReuseIdentifier: "TimeCell")
        tableView.register(UINib(nibName: "ScheduleOptionsTableViewCell", bundle: nil), forCellReuseIdentifier: "OptionsCell")
        tableView.register(UINib(nibName: "SnoozeTableViewCell", bundle: nil), forCellReuseIdentifier: "SnoozeCell")
    }

    private func populateExistingValuesIfNeeded() {
        guard let medicationToEdit else { return }

        medicineName = medicationToEdit.name
        if let dosage = medicationToEdit.dosage {
            let components = dosage.split(separator: " ")
            if components.count >= 2 {
                dosageValue = String(components.dropLast().joined(separator: " "))
                selectedUnit = String(components.last ?? "")
            } else {
                dosageValue = dosage
            }
        }
        times = medicationToEdit.times.sorted()
        inactiveTimes = medicationToEdit.inactiveTimes
        mealTiming = medicationToEdit.mealTiming
        repeatDays = medicationToEdit.repeatDays
        isSnoozeOn = medicationToEdit.isSnoozeOn
        snoozeTime = medicationToEdit.snoozeTime ?? "10 mins"
    }

    private func setupUI() {
        tableView.delegate = self
        tableView.dataSource = self
        
        view.backgroundColor = UIColor(hex: "F5F5F5")
        tableView.backgroundColor = UIColor(hex: "F5F5F5")
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

    @objc private func cancelTapped() {
        dismiss(animated: true)
    }

    @objc private func doneTapped() {
        view.endEditing(true)

        let trimmedName = medicineName.trimmingCharacters(in: .whitespacesAndNewlines)
        guard isFormValid else {
            return
        }
        
        guard let mealTiming = mealTiming else {
            return
        }

        let formData = AddMedicineFormData(
            medicineName: trimmedName,
            dosage: dosageText(),
            times: times,
            inactiveTimes: normalizedInactiveTimes(),
            mealTiming: mealTiming,
            repeatDays: repeatDays,
            isSnoozeOn: isSnoozeOn,
            snoozeTime: isSnoozeOn ? snoozeTime : nil
        )
        onSave?(formData)
        dismiss(animated: true)
    }
    
    func showTimePicker() {
        let alert = UIAlertController(title: "Select Time", message: "\n\n\n\n\n", preferredStyle: .alert)

        let picker = UIDatePicker()
        picker.datePickerMode = .time
        if #available(iOS 13.4, *) {
            picker.preferredDatePickerStyle = .wheels
        }

        picker.frame = CGRect(x: 20, y: 45, width: 200, height: 140)
        alert.view.addSubview(picker)

        let cancel = UIAlertAction(title: "Cancel", style: .cancel)
        let add = UIAlertAction(title: "Add Time", style: .default) { [weak self] _ in
            guard let self = self else { return }
            self.times.append(picker.date)
            self.times.sort()
            self.updateDoneButtonState()
            self.tableView.reloadSections(IndexSet(integer: 2), with: .automatic)
        }

        alert.addAction(cancel)
        alert.addAction(add)

        present(alert, animated: true)
    }
    
    @objc private func dismissPickers() {
        view.endEditing(true)
    }
    
    func formatTime(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "h:mm a"
        return formatter.string(from: date)
    }

    override func numberOfSections(in tableView: UITableView) -> Int {
        return 4
    }

    override func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        if section == 0 {
            return 1
        } else if section == 1 {
            return 2
        } else if section == 2 {
            return times.count + 1
        } else {
            return isSnoozeOn ? 4 : 3
        }
    }

    override func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        if indexPath.section == 0 {
            let cell = tableView.dequeueReusableCell(withIdentifier: "NameInputCell", for: indexPath) as! NameInputTableViewCell
            cell.configure(placeholder: "Name of Medicine", text: medicineName)
            cell.didChangeText = { [weak self] text in
                self?.medicineName = text
                self?.updateDoneButtonState()
            }
            return cell
        }
        else if indexPath.section == 1 {
            if indexPath.row == 0 {
                let cell = tableView.dequeueReusableCell(withIdentifier: "DosageValueCell", for: indexPath) as! DosageValueTableViewCell
                cell.configure(text: dosageValue)
                cell.didChangeText = { [weak self] text in
                    self?.dosageValue = text
                }
                return cell
            }
            if indexPath.row == 1 {
                let cell = tableView.dequeueReusableCell(withIdentifier: "DosageUnitCell", for: indexPath) as! DosageUnitTableViewCell
                cell.configure(unit: selectedUnit) { [weak self] unit in
                    self?.selectedUnit = unit
                    self?.tableView.reloadRows(at: [IndexPath(row: 1, section: 1)], with: .none)
                }
                return cell
            }
        }
        else if indexPath.section == 2 {
            if indexPath.row < times.count {
                let cell = tableView.dequeueReusableCell(withIdentifier: "TimeCell", for: indexPath) as! ReminderTimeTableViewCell
                cell.selectionStyle = .none

                let time = times[indexPath.row]
                cell.timeLabel.text = formatTime(time)
                cell.toggleSwitch.isOn = !isTimeInactive(time)

                cell.didTapDelete = { [weak self] in
                    guard let self = self else { return }
                    let removedTime = self.times.remove(at: indexPath.row)
                    self.removeInactiveState(for: removedTime)
                    self.updateDoneButtonState()
                    self.tableView.reloadData()
                }
                cell.onToggleChanged = { [weak self] isOn in
                    guard let self = self else { return }
                    if isOn {
                        self.removeInactiveState(for: time)
                    } else {
                        self.markTimeInactive(time)
                    }
                }
                return cell

            } else {
                let cell = tableView.dequeueReusableCell(withIdentifier: "AddActionCell", for: indexPath) as! AddActionTableViewCell
                cell.selectionStyle = .none
                cell.actionLabel?.text = "add time"
                cell.didTapAction = { [weak self] in
                    self?.showTimePicker()
                }
                return cell
            }
        }
        else if indexPath.section == 3 {
            switch indexPath.row {
                case 0, 1:
                    let cell = tableView.dequeueReusableCell(withIdentifier: "OptionsCell", for: indexPath) as! ScheduleOptionsTableViewCell

                    if indexPath.row == 0 {
                        cell.configure(
                            title: "Meal Time",
                            value: mealText(mealTiming ?? .afterMeal),
                            actions: mealActions()
                        )
                    } else {
                        cell.configureStatic(title: "Repeat", value: repeatText())
                        cell.onTap = { [weak self] in
                            self?.showRepeatDaysPicker()
                        }
                    }
                    return cell
                
                case 2:
                    let cell = tableView.dequeueReusableCell(withIdentifier: "SnoozeCell", for: indexPath) as! SnoozeTableViewCell

                    cell.titleLabel.text = "Snooze"
                    cell.switchControl.isOn = isSnoozeOn

                    cell.onSwitchChanged = { [weak self] isOn in
                        self?.isSnoozeOn = isOn
                        self?.tableView.reloadSections(IndexSet(integer: 3), with: .automatic)
                    }
                    return cell

                case 3:
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
        }
        return UITableViewCell()
    }
    
    override func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        print("Tapped section: \(indexPath.section), row: \(indexPath.row)")
        if indexPath.section == 2 && indexPath.row == times.count {
            showTimePicker()
        }
        tableView.deselectRow(at: indexPath, animated: true)
    }

    override func tableView(_ tableView: UITableView, heightForHeaderInSection section: Int) -> CGFloat {
        return 6
    }

    override func tableView(_ tableView: UITableView, viewForHeaderInSection section: Int) -> UIView? {
        let view = UIView()
        view.backgroundColor = .clear
        return view
    }

    override func tableView(_ tableView: UITableView, heightForFooterInSection section: Int) -> CGFloat {
        return 6
    }

    private var isFormValid: Bool {
        let trimmedName = medicineName.trimmingCharacters(in: .whitespacesAndNewlines)
        return !trimmedName.isEmpty && !times.isEmpty && mealTiming != nil
    }

    private func updateDoneButtonState() {
        navigationItem.rightBarButtonItem?.isEnabled = isFormValid
    }

    private func dosageText() -> String? {
        let trimmedDosageValue = dosageValue.trimmingCharacters(in: .whitespacesAndNewlines)
        let trimmedUnit = (selectedUnit ?? "").trimmingCharacters(in: .whitespacesAndNewlines)

        guard !trimmedDosageValue.isEmpty || !trimmedUnit.isEmpty else {
            return nil
        }

        if trimmedDosageValue.isEmpty {
            return trimmedUnit
        }

        if trimmedUnit.isEmpty {
            return trimmedDosageValue
        }

        return "\(trimmedDosageValue) \(trimmedUnit)"
    }

    private func isTimeInactive(_ time: Date) -> Bool {
        inactiveTimes.contains(where: {
            Calendar.current.isDate($0, equalTo: time, toGranularity: .minute)
        })
    }

    private func markTimeInactive(_ time: Date) {
        guard !isTimeInactive(time) else { return }
        inactiveTimes.append(time)
    }

    private func removeInactiveState(for time: Date) {
        inactiveTimes.removeAll {
            Calendar.current.isDate($0, equalTo: time, toGranularity: .minute)
        }
    }

    private func normalizedInactiveTimes() -> [Date] {
        times.filter { isTimeInactive($0) }
    }

    private func mealActions() -> [UIAction] {
        [
            menuAction(title: "Before Meal", isSelected: mealTiming == .beforeMeal) { [weak self] in
                self?.mealTiming = .beforeMeal
            },
            menuAction(title: "After Meal", isSelected: mealTiming == .afterMeal) { [weak self] in
                self?.mealTiming = .afterMeal
            },
            menuAction(title: "Empty Stomach", isSelected: mealTiming == .emptyStomach) { [weak self] in
                self?.mealTiming = .emptyStomach
            }
        ]
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
            self?.updateDoneButtonState()
            self?.tableView.reloadSections(IndexSet(integer: 3), with: .none)
        }
    }

    private func mealText(_ timing: MealTiming) -> String {
        switch timing {
        case .beforeMeal:
            return "Before Meal"
        case .afterMeal:
            return "After Meal"
        case .emptyStomach:
            return "Empty Stomach"
        }
    }

    private func repeatText() -> String {
        if repeatDays.count == 7 { return "Every Day" }
        if repeatDays.isEmpty { return "Select Days" }

        let orderedDays = ["Monday", "Tuesday", "Wednesday", "Thursday", "Friday", "Saturday", "Sunday"]
        return orderedDays.filter { repeatDays.contains($0) }.joined(separator: ", ")
    }

    private func showRepeatDaysPicker() {
        let pickerVC = RepeatDaysSelectionViewController(selectedDays: repeatDays)
        pickerVC.onDone = { [weak self] selectedDays in
            self?.repeatDays = selectedDays
            self?.tableView.reloadRows(at: [IndexPath(row: 1, section: 3)], with: .none)
        }
        present(pickerVC, animated: true)
    }

}
