import UIKit

class ConsultDetailedViewController: UIViewController, UICollectionViewDelegate {

    @IBOutlet weak var collectionView: UICollectionView!

    private var screenGradientLayer: CAGradientLayer?
    private let lastSectionBottomInset: CGFloat = 100
    private let noteButtonBottomSpacing: CGFloat = 16

    //Session passed from previous screen
    var consultSession: ConsultSession?

    //Data used by collection view
    var sessionTitle: String = ""
    var symptoms: [Symptom] = []
    var medications: [Medication] = []
    var records: [HealthRecord] = []
    var questions: [Question] = []
    var notes: String? = nil
    var postConsultationNotes: String? = nil

    private lazy var noteButtonContainerView: UIVisualEffectView = {
        let effectView = UIVisualEffectView(effect: UIBlurEffect(style: .systemUltraThinMaterial))
        effectView.translatesAutoresizingMaskIntoConstraints = false
        effectView.clipsToBounds = true
        effectView.layer.cornerRadius = 23
        effectView.layer.cornerCurve = .continuous
        effectView.layer.borderWidth = 1
        effectView.layer.borderColor = UIColor.white.withAlphaComponent(0.35).cgColor
        effectView.layer.shadowColor = UIColor.black.withAlphaComponent(0.14).cgColor
        effectView.layer.shadowOpacity = 1
        effectView.layer.shadowRadius = 18
        effectView.layer.shadowOffset = CGSize(width: 0, height: 8)
        effectView.contentView.backgroundColor = UIColor.white.withAlphaComponent(0.12)
        return effectView
    }()

    private lazy var noteButton: UIButton = {
        let button = UIButton(type: .system)
        button.translatesAutoresizingMaskIntoConstraints = false
        button.addTarget(self, action: #selector(noteButtonTapped), for: .touchUpInside)

        var configuration = UIButton.Configuration.plain()
        configuration.title = "Note"
        configuration.image = UIImage(systemName: "square.and.pencil")
        configuration.imagePadding = 8
        configuration.cornerStyle = .capsule
        configuration.contentInsets = NSDirectionalEdgeInsets(top: 12, leading: 14, bottom: 12, trailing: 16)
        button.configuration = configuration
        return button
    }()
    
    enum DetailSection {
        case header, symptoms, medications, records, questions, notes
    }
    var visibleSections: [DetailSection] = []

    @IBAction func editTapped(_ sender: Any) {
        let storyboard = UIStoryboard(name: "Consult-Screen", bundle: nil)
        if let navVC = storyboard.instantiateViewController(withIdentifier: "PrepareConsultationNav") as? UINavigationController,
           let prepareVC = navVC.topViewController as? PrepareConsultationTableViewController {
            
            let session = consultSession ?? SampleData.consultSessions.first!
            
            prepareVC.sessionTitle = self.sessionTitle
            prepareVC.doctorName = session.doctorName
            prepareVC.sessionDate = session.date
            prepareVC.symptoms = self.symptoms
            prepareVC.medications = self.medications
            prepareVC.records = self.records
            prepareVC.questions = self.questions
            prepareVC.notes = session.notes ?? ""
            
            prepareVC.existingSessionID = session.id
            prepareVC.existingUserID = session.userID
            prepareVC.existingCreatedAt = session.createdAt
            
            self.present(navVC, animated: true, completion: nil)
        }
    }

    @IBAction func doneTapped(_ sender: Any) {
        // 1. Mark the session as completed
        if var session = consultSession {
            session.title = self.sessionTitle
            session.symptoms = self.symptoms
            session.medications = self.medications
            session.records = self.records
            session.questions = self.questions
            session.notes = self.notes
            session.postConsultationNotes = self.postConsultationNotes
            
            session.status = .completed
            ConsultSessionStore.shared.updateSession(session)
            
            // Post notification to update other views
            NotificationCenter.default.post(name: NSNotification.Name("ConsultSessionUpdated"), object: nil, userInfo: ["session": session])
        }
        
        // 2. Go back to the 'prepare screen'
        if let nav = self.navigationController {
            nav.popViewController(animated: true)
        } else {
            self.dismiss(animated: true, completion: nil)
        }
    }

    override func viewDidLoad() {
        super.viewDidLoad()
        view.backgroundColor = UIColor(hex: "F1F6FF")
        collectionView.backgroundColor = .clear
        collectionView.showsVerticalScrollIndicator = false


        loadSessionData()

        setupCollectionView()
        setupNoteButton()
        updateNoteButtonAppearance()
        collectionView.reloadData()
        
        NotificationCenter.default.addObserver(self, selector: #selector(handleSessionUpdate(_:)), name: NSNotification.Name("ConsultSessionUpdated"), object: nil)
    }
    
    @objc private func handleSessionUpdate(_ notification: Notification) {
        if let userInfo = notification.userInfo,
           let updatedSession = userInfo["session"] as? ConsultSession {
            if self.consultSession == nil || self.consultSession?.id == updatedSession.id {
                self.consultSession = updatedSession
                self.loadSessionData()
                self.updateNoteButtonAppearance()
                self.collectionView.reloadData()
            }
        }
    }


    override func viewDidLayoutSubviews() {
        super.viewDidLayoutSubviews()
        screenGradientLayer?.frame = view.bounds
    }

    private func loadSessionData() {
        if let session = consultSession {
            sessionTitle = session.title
            symptoms = session.symptoms
            medications = session.medications
            records = session.records
            questions = session.questions
            notes = session.notes
            postConsultationNotes = session.postConsultationNotes
        } else {
            let sampleSession = SampleData.consultSessions.first!
            sessionTitle = sampleSession.title
            symptoms = sampleSession.symptoms
            medications = sampleSession.medications
            records = sampleSession.records
            questions = sampleSession.questions
            notes = sampleSession.notes
            postConsultationNotes = sampleSession.postConsultationNotes
        }
        buildVisibleSections()
    }
    
    private func buildVisibleSections() {
        visibleSections = [.header, .symptoms]  
        if !medications.isEmpty { visibleSections.append(.medications) }
        if !records.isEmpty { visibleSections.append(.records) }
        if !questions.isEmpty { visibleSections.append(.questions) }
        if let notes = notes, !notes.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            visibleSections.append(.notes)
        }
    }

    private func setupCollectionView() {
        collectionView.dataSource = self
        collectionView.delegate = self
        collectionView.contentInsetAdjustmentBehavior = .never

        collectionView.register(
            UINib(nibName: "HeaderCollectionViewCell", bundle: nil),
            forCellWithReuseIdentifier: "HeaderCell")

        collectionView.register(
            UINib(nibName: "SymptomCollectionViewCell", bundle: nil),
            forCellWithReuseIdentifier: "SymptomCell")

        collectionView.register(
            UINib(nibName: "SectionHeaderView", bundle: nil),
            forSupplementaryViewOfKind: UICollectionView.elementKindSectionHeader,
            withReuseIdentifier: "SectionHeaderView")

        collectionView.register(
            UINib(nibName: "MedicationCollectionViewCell", bundle: nil),
            forCellWithReuseIdentifier: "MedicationCell")

        collectionView.register(
            UINib(nibName: "RecordCardCollectionViewCell", bundle: nil),
            forCellWithReuseIdentifier: "RecordCell")

        collectionView.register(
            UINib(nibName: "QuestionCollectionViewCell", bundle: nil),
            forCellWithReuseIdentifier: "QuestionCell")
            
        collectionView.register(
            UINib(nibName: "NoteCollectionViewCell", bundle: nil),
            forCellWithReuseIdentifier: "NoteCell")

        collectionView.collectionViewLayout = generateLayout()
    }

    private func setupNoteButton() {
        view.addSubview(noteButtonContainerView)
        noteButtonContainerView.contentView.addSubview(noteButton)

        NSLayoutConstraint.activate([
            noteButtonContainerView.trailingAnchor.constraint(equalTo: view.safeAreaLayoutGuide.trailingAnchor, constant: -16),
            noteButtonContainerView.bottomAnchor.constraint(equalTo: view.safeAreaLayoutGuide.bottomAnchor, constant: -noteButtonBottomSpacing),

            noteButton.topAnchor.constraint(equalTo: noteButtonContainerView.contentView.topAnchor),
            noteButton.bottomAnchor.constraint(equalTo: noteButtonContainerView.contentView.bottomAnchor),
            noteButton.leadingAnchor.constraint(equalTo: noteButtonContainerView.contentView.leadingAnchor),
            noteButton.trailingAnchor.constraint(equalTo: noteButtonContainerView.contentView.trailingAnchor),
            noteButton.heightAnchor.constraint(greaterThanOrEqualToConstant: 46)
        ])
    }

    private func updateNoteButtonAppearance() {
        let hasNote = !(postConsultationNotes?.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ?? true)
        var configuration = noteButton.configuration ?? UIButton.Configuration.plain()
        configuration.title = "Note"
        configuration.image = UIImage(systemName: "square.and.pencil")
        configuration.baseForegroundColor = .label
        noteButton.configuration = configuration

        noteButtonContainerView.effect = UIBlurEffect(style: .systemUltraThinMaterial)
        noteButtonContainerView.contentView.backgroundColor = hasNote
            ? UIColor.white.withAlphaComponent(0.18)
            : UIColor.white.withAlphaComponent(0.12)
        noteButtonContainerView.layer.borderColor = hasNote
            ? UIColor.white.withAlphaComponent(0.45).cgColor
            : UIColor.white.withAlphaComponent(0.35).cgColor
    }

    @objc private func noteButtonTapped() {
        let notesVC = PostConsultationNotesViewController()
        notesVC.initialText = postConsultationNotes
        notesVC.onSave = { [weak self] text in
            guard let self = self else { return }
            self.postConsultationNotes = text
            self.updateNoteButtonAppearance()
        }

        let navigationController = UINavigationController(rootViewController: notesVC)
        navigationController.modalPresentationStyle = .pageSheet

        if let sheet = navigationController.sheetPresentationController {
            sheet.detents = [.medium(), .large()]
            sheet.prefersGrabberVisible = true
            sheet.preferredCornerRadius = 28
        }

        present(navigationController, animated: true)
    }

    private func bottomInset(for section: DetailSection) -> CGFloat {
        visibleSections.last == section ? lastSectionBottomInset : 0
    }


    private func generateLayout() -> UICollectionViewCompositionalLayout {
        UICollectionViewCompositionalLayout { [weak self] sectionIndex, _ in
            guard let self = self, sectionIndex < self.visibleSections.count else { return nil }
            switch self.visibleSections[sectionIndex] {
            case .header: return self.headerSection()
            case .symptoms: return self.symptomsSection()
            case .medications: return self.medicationsSection()
            case .records: return self.recordsSection()
            case .questions: return self.questionsSection()
            case .notes: return self.notesSection()
            }
        }
    }

    private func headerSection() -> NSCollectionLayoutSection {

        let itemSize = NSCollectionLayoutSize(
            widthDimension: .fractionalWidth(1.0), heightDimension: .absolute(120))

        let item = NSCollectionLayoutItem(layoutSize: itemSize)

        let group = NSCollectionLayoutGroup.horizontal(layoutSize: itemSize, subitems: [item])

        let section = NSCollectionLayoutSection(group: group)
        section.contentInsets = NSDirectionalEdgeInsets(
            top: 120, leading: 16, bottom: 0, trailing: 16)

        return section
    }

    private func symptomsSection() -> NSCollectionLayoutSection {

        let itemSize = NSCollectionLayoutSize(
            widthDimension: .fractionalWidth(1.0), heightDimension: .estimated(140))

        let item = NSCollectionLayoutItem(layoutSize: itemSize)

        let groupSize = NSCollectionLayoutSize(
            widthDimension: .fractionalWidth(1.0),
            heightDimension: .estimated(140))

        let group = NSCollectionLayoutGroup.vertical(layoutSize: groupSize, subitems: [item])

        let section = NSCollectionLayoutSection(group: group)
        section.interGroupSpacing = 10
        let isLast = visibleSections.last == .questions
        section.contentInsets = NSDirectionalEdgeInsets(
            top: 0, leading: 16, bottom: bottomInset(for: .symptoms), trailing: 16)

        let headerSize = NSCollectionLayoutSize(
            widthDimension: .fractionalWidth(1.0), heightDimension: .absolute(50))

        let header = NSCollectionLayoutBoundarySupplementaryItem(
            layoutSize: headerSize, elementKind: UICollectionView.elementKindSectionHeader,
            alignment: .top)

        section.boundarySupplementaryItems = [header]

        return section
    }

    private func medicationsSection() -> NSCollectionLayoutSection {

        let itemSize = NSCollectionLayoutSize(
            widthDimension: .fractionalWidth(1.0), heightDimension: .estimated(120))
        let item = NSCollectionLayoutItem(layoutSize: itemSize)

        let groupSize = NSCollectionLayoutSize(
            widthDimension: .fractionalWidth(1.0),
            heightDimension: .estimated(120))
        let group = NSCollectionLayoutGroup.horizontal(layoutSize: groupSize, subitems: [item])

        let section = NSCollectionLayoutSection(group: group)
        let isLast = visibleSections.last == .questions
        section.contentInsets = NSDirectionalEdgeInsets(
            top: 0, leading: 16, bottom: bottomInset(for: .medications), trailing: 16)
        section.interGroupSpacing = 10

        let headerSize = NSCollectionLayoutSize(
            widthDimension: .fractionalWidth(1.0),
            heightDimension: .absolute(50))

        let header = NSCollectionLayoutBoundarySupplementaryItem(
            layoutSize: headerSize,
            elementKind: UICollectionView.elementKindSectionHeader, alignment: .top)

        section.boundarySupplementaryItems = [header]

        return section
    }

    private func recordsSection() -> NSCollectionLayoutSection {
        let itemSize = NSCollectionLayoutSize(
            widthDimension: .fractionalWidth(0.5), heightDimension: .absolute(140))

        let item = NSCollectionLayoutItem(layoutSize: itemSize)

        // Horizontal spacing between two cards
        item.contentInsets = NSDirectionalEdgeInsets(top: 0, leading: 0, bottom: 0, trailing: 0)

        let groupSize = NSCollectionLayoutSize(
            widthDimension: .fractionalWidth(1.0), heightDimension: .absolute(140))

        let group = NSCollectionLayoutGroup.horizontal(
            layoutSize: groupSize, subitem: item, count: 2)
        group.interItemSpacing = .fixed(16)

        let section = NSCollectionLayoutSection(group: group)
        section.contentInsets = NSDirectionalEdgeInsets(
            top: 0, leading: 16, bottom: bottomInset(for: .records), trailing: 16)
        section.interGroupSpacing = 16

        let headerSize = NSCollectionLayoutSize(
            widthDimension: .fractionalWidth(1.0),
            heightDimension: .absolute(50))

        let header = NSCollectionLayoutBoundarySupplementaryItem(
            layoutSize: headerSize,
            elementKind: UICollectionView.elementKindSectionHeader, alignment: .top)

        section.boundarySupplementaryItems = [header]

        return section
    }

    private func questionsSection() -> NSCollectionLayoutSection {

        let itemSize = NSCollectionLayoutSize(
            widthDimension: .fractionalWidth(1.0),
            heightDimension: .estimated(75))

        let item = NSCollectionLayoutItem(layoutSize: itemSize)

        let groupSize = NSCollectionLayoutSize(
            widthDimension: .fractionalWidth(1.0), heightDimension: .estimated(75))

        let group = NSCollectionLayoutGroup.vertical(layoutSize: groupSize, subitems: [item])

        let section = NSCollectionLayoutSection(group: group)
        section.interGroupSpacing = 10
        section.contentInsets = NSDirectionalEdgeInsets(
            top: 0, leading: 16, bottom: bottomInset(for: .questions), trailing: 16)

        let headerSize = NSCollectionLayoutSize(
            widthDimension: .fractionalWidth(1.0),
            heightDimension: .absolute(50))

        let header = NSCollectionLayoutBoundarySupplementaryItem(
            layoutSize: headerSize,
            elementKind: UICollectionView.elementKindSectionHeader, alignment: .top)

        section.boundarySupplementaryItems = [header]

        return section
    }

    private func notesSection() -> NSCollectionLayoutSection {
        let itemSize = NSCollectionLayoutSize(
            widthDimension: .fractionalWidth(1.0),
            heightDimension: .estimated(75))

        let item = NSCollectionLayoutItem(layoutSize: itemSize)

        let groupSize = NSCollectionLayoutSize(
            widthDimension: .fractionalWidth(1.0), heightDimension: .estimated(75))

        let group = NSCollectionLayoutGroup.vertical(layoutSize: groupSize, subitems: [item])

        let section = NSCollectionLayoutSection(group: group)
        section.interGroupSpacing = 10
        section.contentInsets = NSDirectionalEdgeInsets(
            top: 0, leading: 16, bottom: bottomInset(for: .notes), trailing: 16)

        let headerSize = NSCollectionLayoutSize(
            widthDimension: .fractionalWidth(1.0),
            heightDimension: .absolute(50))

        let header = NSCollectionLayoutBoundarySupplementaryItem(
            layoutSize: headerSize,
            elementKind: UICollectionView.elementKindSectionHeader, alignment: .top)

        section.boundarySupplementaryItems = [header]

        return section
    }

    func collectionView(_ collectionView: UICollectionView, didSelectItemAt indexPath: IndexPath) {
        switch visibleSections[indexPath.section] {
        case .symptoms:
            symptoms[indexPath.item].isExpanded.toggle()
            let symptom = symptoms[indexPath.item]
            if let cell = collectionView.cellForItem(at: indexPath) as? SymptomCollectionViewCell {
                cell.configure(title: symptom.name, description: symptom.description, isExpanded: symptom.isExpanded)
            }
            collectionView.performBatchUpdates(nil)
        case .records:
            let selectedRecord = records[indexPath.item]
            let storyboard = UIStoryboard(name: "Main", bundle: nil)
            if let destinationVC = storyboard.instantiateViewController(withIdentifier: "RecordDetailedViewController") as? RecordDetailedViewController {
                destinationVC.record = selectedRecord
                if let navigationController = self.navigationController {
                    navigationController.pushViewController(destinationVC, animated: true)
                } else {
                    self.present(destinationVC, animated: true, completion: nil)
                }
            }
        case .questions:
            questions[indexPath.item].isSelected.toggle()
            if let cell = collectionView.cellForItem(at: indexPath) as? QuestionCollectionViewCell {
                cell.configure(with: questions[indexPath.item])
            }
            collectionView.performBatchUpdates(nil)
        default: break
        }
    }
}

extension ConsultDetailedViewController: UICollectionViewDataSource {

    func numberOfSections(in collectionView: UICollectionView) -> Int {
        return visibleSections.count
    }

    func collectionView(_ collectionView: UICollectionView, numberOfItemsInSection section: Int) -> Int {
        switch visibleSections[section] {
        case .header: return 1
        case .symptoms: return symptoms.count
        case .medications: return medications.count
        case .records: return records.count
        case .questions: return questions.count
        case .notes: return 1
        }
    }

    func collectionView(_ collectionView: UICollectionView, cellForItemAt indexPath: IndexPath) -> UICollectionViewCell {
        switch visibleSections[indexPath.section] {
        case .header:
            let cell = collectionView.dequeueReusableCell(withReuseIdentifier: "HeaderCell", for: indexPath) as! HeaderCollectionViewCell
            cell.titleLabel.text = sessionTitle
            return cell
        case .symptoms:
            let cell = collectionView.dequeueReusableCell(withReuseIdentifier: "SymptomCell", for: indexPath) as! SymptomCollectionViewCell
            let symptom = symptoms[indexPath.item]
            cell.configure(title: symptom.name, description: symptom.description, isExpanded: symptom.isExpanded)
            cell.onChevronTap = { [weak self, weak cell] in
                guard let self = self, let cell = cell, let tappedIndexPath = self.collectionView.indexPath(for: cell) else { return }
                self.symptoms[tappedIndexPath.item].isExpanded.toggle()
                let s = self.symptoms[tappedIndexPath.item]
                cell.configure(title: s.name, description: s.description, isExpanded: s.isExpanded)
                self.collectionView.performBatchUpdates(nil)
            }
            return cell
        case .medications:
            let cell = collectionView.dequeueReusableCell(withReuseIdentifier: "MedicationCell", for: indexPath) as! MedicationCollectionViewCell
            let med = medications[indexPath.item]
            cell.configure(
                name: med.name,
                dosage: dosageText(for: med.dosage),
                frequency: frequencyText(for: med),
                duration: derivedDurationText(for: med)
            )
            return cell
        case .records:
            let cell = collectionView.dequeueReusableCell(withReuseIdentifier: "RecordCell", for: indexPath) as! RecordCardCollectionViewCell
            cell.configure(with: records[indexPath.item])
            return cell
        case .questions:
            let cell = collectionView.dequeueReusableCell(withReuseIdentifier: "QuestionCell", for: indexPath) as! QuestionCollectionViewCell
            cell.configure(with: questions[indexPath.item])
            return cell
        case .notes:
            let cell = collectionView.dequeueReusableCell(withReuseIdentifier: "NoteCell", for: indexPath) as! NoteCollectionViewCell
            cell.configure(with: notes ?? "")
            return cell
        }
    }

    func collectionView(_ collectionView: UICollectionView, viewForSupplementaryElementOfKind kind: String, at indexPath: IndexPath) -> UICollectionReusableView {
        guard kind == UICollectionView.elementKindSectionHeader else {
            return UICollectionReusableView()
        }
        let header = collectionView.dequeueReusableSupplementaryView(ofKind: kind, withReuseIdentifier: "SectionHeaderView", for: indexPath) as! SectionHeaderView
        switch visibleSections[indexPath.section] {
        case .symptoms: header.configure(title: "Symptoms")
        case .medications: header.configure(title: "Current Medications")
        case .records: header.configure(title: "Added Records")
        case .questions: header.configure(title: "Questions")
        case .notes: header.configure(title: "Additional Notes")
        default: header.configure(title: "")
        }
        return header
    }
}

private extension ConsultDetailedViewController {
    func dosageText(for dosage: String?) -> String {
        guard let dosage,
              !dosage.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            return ""
        }
        return dosage
    }

    func derivedFrequency(for medication: Medication) -> MedicationFrequency {
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

    func frequencyText(for medication: Medication) -> String {
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

    func derivedDurationText(for medication: Medication, relativeTo now: Date = Date()) -> String {
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
