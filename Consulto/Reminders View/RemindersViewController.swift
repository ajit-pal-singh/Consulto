import UIKit

class RemindersViewController: UIViewController, UITableViewDelegate, UITableViewDataSource {
    private enum SegueIdentifier {
        static let addMedicine = "showAddMedicineReminder"
        static let addConsultation = "AddConsultationTableViewController"
    }

    private enum ReminderSegment: Int {
        case medicine = 0
        case consultation = 1
    }

    private struct ConsultationReminderCard {
        let consultationID: UUID
        let time: Date
        let isActiveCard: Bool
    }

    @IBOutlet weak var tableView: UITableView!

    var reminders = SampleData.reminders
    private var consultationReminders: [ConsultationReminder] = []
    private var selectedSegment: ReminderSegment = .medicine
    private var pendingSegmentReload: DispatchWorkItem?

    struct ReminderCard {
        let medicationID: UUID
        let times: [Date]
        let mealTiming: MealTiming
        let isActiveCard: Bool
    }

    var currentRows: [ReminderCard] {
        reminders.compactMap { medication in
            let activeTimes = activeTimes(for: medication)
            guard !activeTimes.isEmpty else { return nil }

            return ReminderCard(
                medicationID: medication.id,
                times: activeTimes.sorted(),
                mealTiming: medication.mealTiming,
                isActiveCard: true
            )
        }
    }

    var pausedRows: [ReminderCard] {
        reminders.compactMap { medication in
            let pausedTimes = pausedTimes(for: medication)
            guard !pausedTimes.isEmpty else { return nil }

            return ReminderCard(
                medicationID: medication.id,
                times: pausedTimes.sorted(),
                mealTiming: medication.mealTiming,
                isActiveCard: false
            )
        }
    }

    private var currentConsultationRows: [ConsultationReminderCard] {
        consultationReminders.compactMap { consultation in
            guard !consultation.isPaused else { return nil }

            return ConsultationReminderCard(
                consultationID: consultation.id,
                time: consultation.time,
                isActiveCard: true
            )
        }
    }

    private var pausedConsultationRows: [ConsultationReminderCard] {
        consultationReminders.compactMap { consultation in
            guard consultation.isPaused else { return nil }

            return ConsultationReminderCard(
                consultationID: consultation.id,
                time: consultation.time,
                isActiveCard: false
            )
        }
    }

    required init?(coder: NSCoder) {
        super.init(coder: coder)

        tabBarItem = UITabBarItem(
            title: "Reminders",
            image: UIImage(systemName: "bell"),
            selectedImage: UIImage(systemName: "bell")
        )
    }

    override func viewDidLoad() {
        super.viewDidLoad()

        consultationReminders = ConsultationReminderStore.shared.reminders

        tableView.delegate = self
        tableView.dataSource = self
        tableView.backgroundColor = UIColor(hex: "F5F5F5")

        tableView.register(UINib(nibName: "SegmentTableViewCell", bundle: nil), forCellReuseIdentifier: "SegmentCell")
        tableView.register(UINib(nibName: "HeaderTableViewCell", bundle: nil), forCellReuseIdentifier: "HeaderCell")
        tableView.register(UINib(nibName: "MedicineTableViewCell", bundle: nil), forCellReuseIdentifier: "MedicineCell")
        tableView.register(UINib(nibName: "ConsultationTableViewCell", bundle: nil), forCellReuseIdentifier: "ConsultationCell")

        navigationItem.rightBarButtonItem?.target = self
        navigationItem.rightBarButtonItem?.action = #selector(didTapAddButton)

        NotificationCenter.default.addObserver(
            self,
            selector: #selector(handleNewConsultationReminder(_:)),
            name: NSNotification.Name("NewConsultationReminderCreated"),
            object: nil
        )
    }

    @objc private func handleNewConsultationReminder(_ notification: Notification) {
        consultationReminders = ConsultationReminderStore.shared.reminders
        selectedSegment = .consultation
        reloadReminderTable()
    }

    @objc private func didTapAddButton() {
        let actionSheet = UIAlertController(title: nil, message: nil, preferredStyle: .actionSheet)

        actionSheet.addAction(UIAlertAction(title: "Add Medicine", style: .default) { [weak self] _ in
            self?.performSegue(withIdentifier: SegueIdentifier.addMedicine, sender: nil)
        })

        actionSheet.addAction(UIAlertAction(title: "Add Consultation", style: .default) { [weak self] _ in
            self?.presentConsultationEditor()
        })

        actionSheet.addAction(UIAlertAction(title: "Cancel", style: .cancel))

        if let popover = actionSheet.popoverPresentationController {
            popover.barButtonItem = navigationItem.rightBarButtonItem
        }

        present(actionSheet, animated: true)
    }

    private func appendReminder(from formData: AddMedicineFormData) {
        let medication = Medication(
            id: UUID(),
            recordID: UUID(),
            name: formData.medicineName,
            dosage: formData.dosage,
            frequency: nil,
            duration: nil,
            notes: nil,
            times: formData.times.isEmpty ? [defaultReminderTime()] : formData.times,
            mealTiming: formData.mealTiming,
            repeatDays: formData.repeatDays,
            isSnoozeOn: formData.isSnoozeOn,
            snoozeTime: formData.snoozeTime,
            inactiveTimes: formData.inactiveTimes
        )

        reminders.insert(medication, at: 0)
        reloadReminderTable()
    }

    private func appendConsultationReminder(from formData: AddConsultationFormData) {
        let reminder = ConsultationReminderStore.shared.addReminder(
            doctorName: formData.doctorName,
            purpose: formData.purpose,
            consultationDate: formData.consultationDate,
            time: formData.time,
            repeatDays: formData.repeatDays,
            isSnoozeOn: formData.isSnoozeOn,
            snoozeTime: formData.snoozeTime,
            isPaused: formData.isPaused
        )

        consultationReminders.insert(reminder, at: 0)
        selectedSegment = .consultation
        reloadReminderTable()
    }

    private func updateConsultationReminder(_ reminder: ConsultationReminder, from formData: AddConsultationFormData) {
        guard let index = consultationReminders.firstIndex(where: { $0.id == reminder.id }) else { return }

        consultationReminders[index].doctorName = formData.doctorName
        consultationReminders[index].purpose = formData.purpose
        consultationReminders[index].date = formData.consultationDate
        consultationReminders[index].time = formData.time
        consultationReminders[index].repeatDays = formData.repeatDays
        consultationReminders[index].isSnoozeOn = formData.isSnoozeOn
        consultationReminders[index].snoozeTime = formData.snoozeTime
        consultationReminders[index].isPaused = formData.isPaused
        ConsultationReminderStore.shared.reminders = consultationReminders

        selectedSegment = .consultation
        reloadReminderTable()
    }

    private func updateReminder(_ medication: Medication, from formData: AddMedicineFormData) {
        guard let index = reminders.firstIndex(where: { $0.id == medication.id }) else { return }

        reminders[index].name = formData.medicineName
        reminders[index].dosage = formData.dosage
        reminders[index].times = formData.times.isEmpty ? reminders[index].times : formData.times
        reminders[index].inactiveTimes = formData.inactiveTimes
        reminders[index].mealTiming = formData.mealTiming
        reminders[index].repeatDays = formData.repeatDays
        reminders[index].isSnoozeOn = formData.isSnoozeOn
        reminders[index].snoozeTime = formData.snoozeTime

        reloadReminderTable()
    }

    private func defaultReminderTime() -> Date {
        Calendar.current.date(from: DateComponents(hour: 8, minute: 0)) ?? Date()
    }

    override func prepare(for segue: UIStoryboardSegue, sender: Any?) {
        if segue.identifier == SegueIdentifier.addMedicine,
           let navigationController = segue.destination as? UINavigationController,
           let addMedicineVC = navigationController.topViewController as? AddMedicineTableViewController {
            addMedicineVC.onSave = { [weak self] formData in
                self?.appendReminder(from: formData)
            }
        }
    }

    private func presentEditor(for medication: Medication) {
        let storyboard = UIStoryboard(name: "RemindersScreen", bundle: nil)
        guard let addMedicineVC = storyboard.instantiateViewController(withIdentifier: "AddMedicineTableViewController") as? AddMedicineTableViewController else {
            return
        }

        addMedicineVC.medicationToEdit = medication
        addMedicineVC.onSave = { [weak self] formData in
            self?.updateReminder(medication, from: formData)
        }

        let navigationController = UINavigationController(rootViewController: addMedicineVC)
        present(navigationController, animated: true)
    }

    private func presentConsultationEditor() {
        let storyboard = UIStoryboard(name: "RemindersScreen", bundle: nil)
        guard let addConsultationVC = storyboard.instantiateViewController(withIdentifier: SegueIdentifier.addConsultation) as? AddConsultationTableViewController else {
            return
        }

        addConsultationVC.onSave = { [weak self] formData in
            self?.appendConsultationReminder(from: formData)
        }

        let navigationController = UINavigationController(rootViewController: addConsultationVC)
        present(navigationController, animated: true)
    }

    private func presentConsultationEditor(for reminder: ConsultationReminder) {
        let storyboard = UIStoryboard(name: "RemindersScreen", bundle: nil)
        guard let addConsultationVC = storyboard.instantiateViewController(withIdentifier: SegueIdentifier.addConsultation) as? AddConsultationTableViewController else {
            return
        }

        addConsultationVC.consultationToEdit = AddConsultationFormData(
            doctorName: reminder.doctorName,
            purpose: reminder.purpose,
            consultationDate: reminder.date,
            time: reminder.time,
            isPaused: reminder.isPaused,
            repeatDays: reminder.repeatDays,
            isSnoozeOn: reminder.isSnoozeOn,
            snoozeTime: reminder.snoozeTime
        )
        addConsultationVC.onSave = { [weak self] formData in
            self?.updateConsultationReminder(reminder, from: formData)
        }

        let navigationController = UINavigationController(rootViewController: addConsultationVC)
        present(navigationController, animated: true)
    }

    private func reloadReminderTable() {
        UIView.transition(with: tableView, duration: 0.25, options: .transitionCrossDissolve) {
            self.tableView.reloadData()
        }
    }

    func numberOfSections(in tableView: UITableView) -> Int {
        1
    }

    func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        switch selectedSegment {
        case .medicine:
            return 1
            + (currentRows.isEmpty ? 0 : 1 + currentRows.count)
            + (pausedRows.isEmpty ? 0 : 1 + pausedRows.count)
        case .consultation:
            return 1
            + (currentConsultationRows.isEmpty ? 0 : 1 + currentConsultationRows.count)
            + (pausedConsultationRows.isEmpty ? 0 : 1 + pausedConsultationRows.count)
        }
    }

    func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        if indexPath.row == 0 {
            let cell = tableView.dequeueReusableCell(withIdentifier: "SegmentCell", for: indexPath) as! SegmentTableViewCell
            cell.segmentControl.removeTarget(nil, action: nil, for: .valueChanged)
            cell.segmentControl.selectedSegmentIndex = selectedSegment.rawValue
            cell.segmentControl.addTarget(self, action: #selector(segmentChanged(_:)), for: .valueChanged)
            return cell
        }

        switch selectedSegment {
        case .medicine:
            return medicineCell(for: indexPath, tableView: tableView)
        case .consultation:
            return consultationCell(for: indexPath, tableView: tableView)
        }
    }

    @objc private func segmentChanged(_ sender: UISegmentedControl) {
        let newValue = ReminderSegment(rawValue: sender.selectedSegmentIndex) ?? .medicine
        guard selectedSegment != newValue else { return }
        selectedSegment = newValue
        pendingSegmentReload?.cancel()

        let workItem = DispatchWorkItem { [weak self] in
            guard let self = self else { return }
            UIView.performWithoutAnimation {
                self.tableView.reloadData()
            }
        }

        pendingSegmentReload = workItem
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.2, execute: workItem)
    }

    private func medicineCell(for indexPath: IndexPath, tableView: UITableView) -> UITableViewCell {
        if !currentRows.isEmpty && indexPath.row == 1 {
            let cell = tableView.dequeueReusableCell(withIdentifier: "HeaderCell", for: indexPath) as! HeaderTableViewCell
            cell.titleLabel.text = "Current Medicines"
            return cell
        }

        if !currentRows.isEmpty && indexPath.row <= currentRows.count + 1 {
            let cell = tableView.dequeueReusableCell(withIdentifier: "MedicineCell", for: indexPath) as! MedicineTableViewCell
            let row = currentRows[indexPath.row - 2]
            configureReminderCell(cell, with: row)
            return cell
        }

        let pausedHeaderRow = 1 + (currentRows.isEmpty ? 0 : 1 + currentRows.count)

        if !pausedRows.isEmpty && indexPath.row == pausedHeaderRow {
            let cell = tableView.dequeueReusableCell(withIdentifier: "HeaderCell", for: indexPath) as! HeaderTableViewCell
            cell.titleLabel.text = "Paused Medicines"
            return cell
        }

        let cell = tableView.dequeueReusableCell(withIdentifier: "MedicineCell", for: indexPath) as! MedicineTableViewCell
        let row = pausedRows[indexPath.row - (pausedHeaderRow + 1)]
        configureReminderCell(cell, with: row)
        return cell
    }

    private func consultationCell(for indexPath: IndexPath, tableView: UITableView) -> UITableViewCell {
        if !currentConsultationRows.isEmpty && indexPath.row == 1 {
            let cell = tableView.dequeueReusableCell(withIdentifier: "HeaderCell", for: indexPath) as! HeaderTableViewCell
            cell.titleLabel.text = "Upcoming Consultations"
            return cell
        }

        if !currentConsultationRows.isEmpty && indexPath.row <= currentConsultationRows.count + 1 {
            let cell = tableView.dequeueReusableCell(withIdentifier: "ConsultationCell", for: indexPath) as! ConsultationTableViewCell
            let row = currentConsultationRows[indexPath.row - 2]
            configureConsultationCell(cell, with: row)
            return cell
        }

        let pausedHeaderRow = 1 + (currentConsultationRows.isEmpty ? 0 : 1 + currentConsultationRows.count)

        if !pausedConsultationRows.isEmpty && indexPath.row == pausedHeaderRow {
            let cell = tableView.dequeueReusableCell(withIdentifier: "HeaderCell", for: indexPath) as! HeaderTableViewCell
            cell.titleLabel.text = "Paused Consultations"
            return cell
        }

        let cell = tableView.dequeueReusableCell(withIdentifier: "ConsultationCell", for: indexPath) as! ConsultationTableViewCell
        let row = pausedConsultationRows[indexPath.row - (pausedHeaderRow + 1)]
        configureConsultationCell(cell, with: row)
        return cell
    }

    func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        defer { tableView.deselectRow(at: indexPath, animated: true) }

        switch selectedSegment {
        case .medicine:
            if let medication = medicationForIndexPath(indexPath) {
                presentEditor(for: medication)
            }
        case .consultation:
            if let reminder = consultationForIndexPath(indexPath) {
                presentConsultationEditor(for: reminder)
            }
        }
    }

    func tableView(_ tableView: UITableView, canEditRowAt indexPath: IndexPath) -> Bool {
        switch selectedSegment {
        case .medicine:
            return medicationForIndexPath(indexPath) != nil
        case .consultation:
            return consultationForIndexPath(indexPath) != nil
        }
    }

    func tableView(_ tableView: UITableView, trailingSwipeActionsConfigurationForRowAt indexPath: IndexPath) -> UISwipeActionsConfiguration? {
        switch selectedSegment {
        case .medicine:
            return medicineSwipeConfiguration(for: indexPath)
        case .consultation:
            return consultationSwipeConfiguration(for: indexPath)
        }
    }

    private func medicineSwipeConfiguration(for indexPath: IndexPath) -> UISwipeActionsConfiguration? {
        guard let card = reminderCardForIndexPath(indexPath),
              let medication = medicationForCard(card) else {
            return nil
        }

        let deleteAction = UIContextualAction(style: .destructive, title: "Delete") { [weak self] _, _, completion in
            guard let self = self else {
                completion(false)
                return
            }

            guard let reminderIndex = self.reminders.firstIndex(where: { $0.id == medication.id }) else {
                completion(false)
                return
            }

            self.reminders.remove(at: reminderIndex)
            self.reloadReminderTable()
            completion(true)
        }

        deleteAction.backgroundColor = .systemRed

        let configuration = UISwipeActionsConfiguration(actions: [deleteAction])
        configuration.performsFirstActionWithFullSwipe = true
        return configuration
    }

    private func consultationSwipeConfiguration(for indexPath: IndexPath) -> UISwipeActionsConfiguration? {
        guard let reminder = consultationForIndexPath(indexPath) else {
            return nil
        }

        let deleteAction = UIContextualAction(style: .destructive, title: "Delete") { [weak self] _, _, completion in
            guard let self = self else {
                completion(false)
                return
            }

            guard let index = self.consultationReminders.firstIndex(where: { $0.id == reminder.id }) else {
                completion(false)
                return
            }

            self.consultationReminders.remove(at: index)
            ConsultationReminderStore.shared.reminders = self.consultationReminders
            self.reloadReminderTable()
            completion(true)
        }

        deleteAction.backgroundColor = .systemRed

        let configuration = UISwipeActionsConfiguration(actions: [deleteAction])
        configuration.performsFirstActionWithFullSwipe = true
        return configuration
    }

    private func configureReminderCell(_ cell: MedicineTableViewCell, with card: ReminderCard) {
        guard let medication = medicationForCard(card) else { return }

        cell.nameLabel.text = medication.name
        let dosageText = dosageLabelText(for: medication.dosage)
        cell.unitLabel.text = dosageText
        cell.unitLabel.isHidden = dosageText == nil
        cell.timeLabel.text = timeSummary(for: card.times)

        let meal = mealText(card.mealTiming)
        cell.mealTimeLabel.text = meal
        cell.mealTimeLabel.isHidden = meal.isEmpty
        cell.dotLabel.isHidden = meal.isEmpty
        cell.toggleSwitch.isOn = card.isActiveCard

        cell.onToggleChanged = { [weak self] isOn in
            guard let self = self else { return }

            if let reminderIndex = self.reminders.firstIndex(where: { $0.id == medication.id }) {
                if isOn {
                    self.reminders[reminderIndex].inactiveTimes.removeAll { inactiveTime in
                        card.times.contains(where: {
                            Calendar.current.isDate($0, equalTo: inactiveTime, toGranularity: .minute)
                        })
                    }
                } else {
                    for time in card.times where !self.reminders[reminderIndex].inactiveTimes.contains(where: {
                        Calendar.current.isDate($0, equalTo: time, toGranularity: .minute)
                    }) {
                        self.reminders[reminderIndex].inactiveTimes.append(time)
                    }
                }
            }

            self.reloadReminderTable()
        }
    }

    private func configureConsultationCell(_ cell: ConsultationTableViewCell, with card: ConsultationReminderCard) {
        guard let consultation = consultationForCard(card) else { return }

        cell.nameLabel.text = consultation.doctorName
        cell.dateLabel.text = formatDate(consultation.date)
        cell.timeLabel.text = formatTime(card.time)
        cell.purposeLabel.text = consultation.purpose
        cell.dotLabel.isHidden = cell.dateLabel.text?.isEmpty ?? true
        cell.dot2Label.isHidden = cell.timeLabel.text?.isEmpty ?? true
        cell.toggleSwitch.isOn = card.isActiveCard

        cell.onToggleChanged = { [weak self] isOn in
            guard let self = self,
                  let index = self.consultationReminders.firstIndex(where: { $0.id == consultation.id }) else { return }

            self.consultationReminders[index].isPaused = !isOn

            ConsultationReminderStore.shared.reminders = self.consultationReminders
            self.reloadReminderTable()
        }
    }

    private func formatTime(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "h:mm a"
        return formatter.string(from: date)
    }

    private func formatDate(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "dd MMM"
        return formatter.string(from: date)
    }

    private func mealText(_ timing: MealTiming) -> String {
        switch timing {
        case .beforeMeal:
            return "Before Meal"
        case .afterMeal:
            return "After Meal"
        case .emptyStomach:
            return "Empty Stomach"
        case .none:
            return ""
        }
    }

    private func activeTimes(for medication: Medication) -> [Date] {
        medication.times.filter { time in
            !medication.inactiveTimes.contains(where: {
                Calendar.current.isDate($0, equalTo: time, toGranularity: .minute)
            })
        }
    }

    private func pausedTimes(for medication: Medication) -> [Date] {
        medication.times.filter { time in
            medication.inactiveTimes.contains(where: {
                Calendar.current.isDate($0, equalTo: time, toGranularity: .minute)
            })
        }
    }

    private func timeSummary(for times: [Date]) -> String {
        let sortedTimes = times.sorted()
        guard !sortedTimes.isEmpty else { return "" }

        if sortedTimes.count == 1 {
            return formatTime(sortedTimes[0])
        }

        return "\(sortedTimes.count) reminders"
    }

    private func dosageLabelText(for dosage: String?) -> String? {
        guard let dosage,
              !dosage.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            return nil
        }

        return "(\(dosage))"
    }

    private func medicationForIndexPath(_ indexPath: IndexPath) -> Medication? {
        guard let card = reminderCardForIndexPath(indexPath) else {
            return nil
        }

        return medicationForCard(card)
    }

    private func medicationForCard(_ card: ReminderCard) -> Medication? {
        reminders.first(where: { $0.id == card.medicationID })
    }

    private func reminderCardForIndexPath(_ indexPath: IndexPath) -> ReminderCard? {
        if !currentRows.isEmpty && indexPath.row >= 2 && indexPath.row <= currentRows.count + 1 {
            return currentRows[indexPath.row - 2]
        }

        let pausedHeaderRow = 1 + (currentRows.isEmpty ? 0 : 1 + currentRows.count)

        if !pausedRows.isEmpty && indexPath.row >= pausedHeaderRow + 1 {
            return pausedRows[indexPath.row - (pausedHeaderRow + 1)]
        }

        return nil
    }

    private func consultationForIndexPath(_ indexPath: IndexPath) -> ConsultationReminder? {
        guard let card = consultationCardForIndexPath(indexPath) else {
            return nil
        }

        return consultationForCard(card)
    }

    private func consultationForCard(_ card: ConsultationReminderCard) -> ConsultationReminder? {
        consultationReminders.first(where: { $0.id == card.consultationID })
    }

    private func consultationCardForIndexPath(_ indexPath: IndexPath) -> ConsultationReminderCard? {
        if !currentConsultationRows.isEmpty && indexPath.row >= 2 && indexPath.row <= currentConsultationRows.count + 1 {
            return currentConsultationRows[indexPath.row - 2]
        }

        let pausedHeaderRow = 1 + (currentConsultationRows.isEmpty ? 0 : 1 + currentConsultationRows.count)

        if !pausedConsultationRows.isEmpty && indexPath.row >= pausedHeaderRow + 1 {
            return pausedConsultationRows[indexPath.row - (pausedHeaderRow + 1)]
        }

        return nil
    }
}
