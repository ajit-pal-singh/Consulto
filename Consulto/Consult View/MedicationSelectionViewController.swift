import UIKit

final class MedicationSelectionViewController: UIViewController, UICollectionViewDataSource, UICollectionViewDelegate {

    var initiallySelectedMedicationIDs: Set<UUID> = []
    var preselectAllIfSelectionEmpty = false
    var onDone: (([Medication]) -> Void)?

    private var hasShownInfoMessage = false
    private var collectionView: UICollectionView!
    private var medications: [Medication] = []
    private var selectedMedicationIDs: Set<UUID> = []

    override func viewDidLoad() {
        super.viewDidLoad()
        medications = activeReminderMedications()
        selectedMedicationIDs = initiallySelectedMedicationIDs
        if preselectAllIfSelectionEmpty && selectedMedicationIDs.isEmpty {
            selectedMedicationIDs = Set(medications.map(\.id))
        }
        setupUI()
        updateDoneButtonState()
    }

    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
        guard !hasShownInfoMessage else { return }
        hasShownInfoMessage = true

        let alert = UIAlertController(
            title: "Current Medications",
            message: "Current medications are being fetched from your set medicine reminders.",
            preferredStyle: .alert
        )
        alert.addAction(UIAlertAction(title: "OK", style: .default))
        present(alert, animated: true)
    }

    private func setupUI() {
        title = "Select Medicines"
        view.backgroundColor = UIColor(hex: "F5F5F5")

        navigationItem.leftBarButtonItem = UIBarButtonItem(
            image: UIImage(systemName: "xmark"),
            style: .plain,
            target: self,
            action: #selector(cancelTapped)
        )
        navigationItem.rightBarButtonItem = UIBarButtonItem(
            image: UIImage(systemName: "checkmark"),
            style: .done,
            target: self,
            action: #selector(doneTapped)
        )

        collectionView = UICollectionView(frame: .zero, collectionViewLayout: makeLayout())
        collectionView.translatesAutoresizingMaskIntoConstraints = false
        collectionView.backgroundColor = .clear
        collectionView.alwaysBounceVertical = true
        collectionView.allowsMultipleSelection = true
        collectionView.dataSource = self
        collectionView.delegate = self
        collectionView.register(UINib(nibName: "MedicationCollectionViewCell", bundle: nil), forCellWithReuseIdentifier: "MedicationCell")
        view.addSubview(collectionView)

        NSLayoutConstraint.activate([
            collectionView.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor),
            collectionView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            collectionView.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            collectionView.bottomAnchor.constraint(equalTo: view.bottomAnchor)
        ])

        if medications.isEmpty {
            let label = UILabel()
            label.text = "No active medicine reminders found."
            label.textColor = .secondaryLabel
            label.textAlignment = .center
            label.numberOfLines = 0
            collectionView.backgroundView = label
        }
    }

    private func makeLayout() -> UICollectionViewCompositionalLayout {
        UICollectionViewCompositionalLayout { _, _ in
            let itemSize = NSCollectionLayoutSize(
                widthDimension: .fractionalWidth(1.0),
                heightDimension: .estimated(91)
            )
            let item = NSCollectionLayoutItem(layoutSize: itemSize)

            let groupSize = NSCollectionLayoutSize(
                widthDimension: .fractionalWidth(1.0),
                heightDimension: .estimated(91)
            )
            let group = NSCollectionLayoutGroup.horizontal(layoutSize: groupSize, subitems: [item])

            let section = NSCollectionLayoutSection(group: group)
            section.contentInsets = NSDirectionalEdgeInsets(top: 16, leading: 16, bottom: 0, trailing: 16)
            section.interGroupSpacing = 10
            return section
        }
    }

    private func activeReminderMedications() -> [Medication] {
        MedicationReminderStore.shared.medications.filter { medication in
            medication.times.contains { time in
                !medication.inactiveTimes.contains(where: {
                    Calendar.current.isDate($0, equalTo: time, toGranularity: .minute)
                })
            }
        }
    }

    private func medicationForConsult(from reminder: Medication) -> Medication {
        var medication = reminder
        medication.frequency = derivedFrequency(for: reminder)
        medication.duration = derivedDurationText(for: reminder)
        return medication
    }

    private func updateDoneButtonState() {
        navigationItem.rightBarButtonItem?.isEnabled = true
    }

    @objc private func cancelTapped() {
        dismiss(animated: true)
    }

    @objc private func doneTapped() {
        let selected = medications
            .filter { selectedMedicationIDs.contains($0.id) }
            .map(medicationForConsult)
        onDone?(selected)
        dismiss(animated: true)
    }

    func collectionView(_ collectionView: UICollectionView, numberOfItemsInSection section: Int) -> Int {
        medications.count
    }

    func collectionView(_ collectionView: UICollectionView, cellForItemAt indexPath: IndexPath) -> UICollectionViewCell {
        let cell = collectionView.dequeueReusableCell(withReuseIdentifier: "MedicationCell", for: indexPath) as! MedicationCollectionViewCell
        let medication = medications[indexPath.item]
        cell.configure(
            name: medication.name,
            dosage: dosageText(for: medication.dosage),
            frequency: frequencyText(for: medication),
            duration: derivedDurationText(for: medication)
        )
        cell.backgroundColor = .clear
        cell.layer.borderWidth = 0
        cell.layer.borderColor = UIColor.clear.cgColor
        cell.contentView.backgroundColor = .clear
        cell.contentView.layer.borderWidth = 0
        cell.contentView.layer.borderColor = UIColor.clear.cgColor
        cell.selectedBackgroundView = UIView(frame: .zero)
        cell.selectedBackgroundView?.backgroundColor = .clear
        configureSelectionIndicator(in: cell, isSelected: selectedMedicationIDs.contains(medication.id))
        return cell
    }

    func collectionView(_ collectionView: UICollectionView, didSelectItemAt indexPath: IndexPath) {
        let medication = medications[indexPath.item]
        if selectedMedicationIDs.contains(medication.id) {
            selectedMedicationIDs.remove(medication.id)
        } else {
            selectedMedicationIDs.insert(medication.id)
        }
        collectionView.reloadItems(at: [indexPath])
    }

    private func configureSelectionIndicator(in cell: UICollectionViewCell, isSelected: Bool) {
        let indicatorTag = 12039
        cell.contentView.viewWithTag(indicatorTag)?.removeFromSuperview()

        let indicator = UIImageView()
        indicator.tag = indicatorTag
        indicator.translatesAutoresizingMaskIntoConstraints = false
        indicator.image = UIImage(
            systemName: isSelected ? "checkmark.circle.fill" : "circle"
        )
        indicator.tintColor = isSelected ? UIColor(hex: "4285F4") : UIColor.systemGray4
        indicator.backgroundColor = .white
        indicator.layer.cornerRadius = 12.5
        indicator.clipsToBounds = true

        cell.contentView.addSubview(indicator)
        NSLayoutConstraint.activate([
            indicator.widthAnchor.constraint(equalToConstant: 25),
            indicator.heightAnchor.constraint(equalToConstant: 25),
            indicator.trailingAnchor.constraint(equalTo: cell.contentView.trailingAnchor, constant: -12),
            indicator.centerYAnchor.constraint(equalTo: cell.contentView.centerYAnchor)
        ])
    }

    private func dosageText(for dosage: String?) -> String {
        guard let dosage,
              !dosage.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            return ""
        }
        return dosage
    }

    private func derivedFrequency(for medication: Medication) -> MedicationFrequency {
        let hasCustomRepeatDays = !medication.repeatDays.isEmpty && medication.repeatDays.count != 7
        guard !hasCustomRepeatDays else {
            return .asNeeded
        }

        switch medication.times.count {
        case 1:
            return .onceDaily
        case 2:
            return .twiceDaily
        case 3:
            return .thriceDaily
        default:
            return medication.frequency ?? .asNeeded
        }
    }

    private func frequencyText(for medication: Medication) -> String {
        switch derivedFrequency(for: medication) {
        case .onceDaily:
            return "Once Daily"
        case .twiceDaily:
            return "Twice Daily"
        case .thriceDaily:
            return "Thrice Daily"
        case .asNeeded:
            return "As Needed"
        }
    }

    private func derivedDurationText(for medication: Medication, relativeTo now: Date = Date()) -> String {
        if let reminderCreatedAt = medication.reminderCreatedAt {
            let calendar = Calendar.current
            let start = calendar.startOfDay(for: reminderCreatedAt)
            let end = calendar.startOfDay(for: now)
            let components = calendar.dateComponents([.year, .month, .weekOfYear, .day], from: start, to: end)

            if let years = components.year, years > 0 {
                return "From last \(years) year" + (years == 1 ? "" : "s")
            }
            if let months = components.month, months > 0 {
                return "From last \(months) month" + (months == 1 ? "" : "s")
            }
            if let weeks = components.weekOfYear, weeks > 0 {
                return "From last \(weeks) week" + (weeks == 1 ? "" : "s")
            }
            if let days = components.day, days > 0 {
                return "From last \(days) day" + (days == 1 ? "" : "s")
            }
            return "From today"
        }
        return medication.duration ?? ""
    }
}
