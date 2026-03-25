import UIKit

class ConsultDetailedViewController: UIViewController, UICollectionViewDelegate {

    @IBOutlet weak var collectionView: UICollectionView!

    private var screenGradientLayer: CAGradientLayer?

    //Session passed from previous screen
    var consultSession: ConsultSession?

    //Data used by collection view
    var sessionTitle: String = ""
    var symptoms: [Symptom] = []
    var medications: [Medication] = []
    var records: [HealthRecord] = []
    var questions: [Question] = []
    
    enum DetailSection {
        case header, symptoms, medications, records, questions
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

    override func viewDidLoad() {
        super.viewDidLoad()
        view.backgroundColor = UIColor(hex: "F5F5F5")
        collectionView.backgroundColor = .clear
        collectionView.showsVerticalScrollIndicator = false


        loadSessionData()

        setupCollectionView()
        collectionView.reloadData()
        
        NotificationCenter.default.addObserver(self, selector: #selector(handleSessionUpdate(_:)), name: NSNotification.Name("ConsultSessionUpdated"), object: nil)
    }
    
    @objc private func handleSessionUpdate(_ notification: Notification) {
        if let userInfo = notification.userInfo,
           let updatedSession = userInfo["session"] as? ConsultSession {
            if self.consultSession == nil || self.consultSession?.id == updatedSession.id {
                self.consultSession = updatedSession
                self.loadSessionData()
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
        } else {
            let sampleSession = SampleData.consultSessions.first!
            sessionTitle = sampleSession.title
            symptoms = sampleSession.symptoms
            medications = sampleSession.medications
            records = sampleSession.records
            questions = sampleSession.questions
        }
        buildVisibleSections()
    }
    
    private func buildVisibleSections() {
        visibleSections = [.header, .symptoms]  
        if !medications.isEmpty { visibleSections.append(.medications) }
        if !records.isEmpty { visibleSections.append(.records) }
        if !questions.isEmpty { visibleSections.append(.questions) }
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

        collectionView.collectionViewLayout = generateLayout()
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
        section.contentInsets = NSDirectionalEdgeInsets(
            top: 0, leading: 16, bottom: 0, trailing: 16)

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
            widthDimension: .fractionalWidth(0.5), heightDimension: .estimated(120))
        let item = NSCollectionLayoutItem(layoutSize: itemSize)

        let groupSize = NSCollectionLayoutSize(
            widthDimension: .fractionalWidth(1.0),
            heightDimension: .estimated(120))
        let group = NSCollectionLayoutGroup.horizontal(layoutSize: groupSize, subitems: [item])
        group.interItemSpacing = .fixed(16)

        let section = NSCollectionLayoutSection(group: group)
        section.contentInsets = NSDirectionalEdgeInsets(
            top: 0, leading: 16, bottom: 0, trailing: 16)
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
            top: 0, leading: 16, bottom: 0,
            trailing: 16)
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
            top: 0, leading: 16, bottom: 100, trailing: 16)

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
            cell.configure(name: med.name, dosage: med.dosage ?? "", frequency: med.frequency?.rawValue ?? "", duration: med.duration ?? "")
            return cell
        case .records:
            let cell = collectionView.dequeueReusableCell(withReuseIdentifier: "RecordCell", for: indexPath) as! RecordCardCollectionViewCell
            cell.configure(with: records[indexPath.item])
            return cell
        case .questions:
            let cell = collectionView.dequeueReusableCell(withReuseIdentifier: "QuestionCell", for: indexPath) as! QuestionCollectionViewCell
            cell.configure(with: questions[indexPath.item])
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
        default: header.configure(title: "")
        }
        return header
    }
}
