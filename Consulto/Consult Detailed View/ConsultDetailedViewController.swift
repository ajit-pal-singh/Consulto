//
//  ViewController.swift
//  ConsultSession
//
//  Created by geu on 03/02/26.
//

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

    override func viewDidLoad() {
        super.viewDidLoad()
        let bgColor = UIColor(red: 245 / 255, green: 245 / 255, blue: 245 / 255, alpha: 1.0)
        view.backgroundColor = bgColor
        collectionView.backgroundColor = .clear

        // Add action to the Done button defined in Storyboard
        if let doneBtn = navigationItem.rightBarButtonItem {
            doneBtn.target = self
            doneBtn.action = #selector(doneTapped)
        } else {
            // Fallback if not hooked up in storyboard properly
            let doneBtn = UIBarButtonItem(
                barButtonSystemItem: .done, target: self, action: #selector(doneTapped))
            navigationItem.rightBarButtonItem = doneBtn
        }

        loadSessionData()

        setupCollectionView()
        // applyScreenBackgroundGradient()
        collectionView.reloadData()
    }

    @objc private func doneTapped() {
        // Mark session as completed
        if var session = consultSession {
            session.status = .completed
            session.questions = self.questions
            session.symptoms = self.symptoms

            consultSession = session  // Update local copy just in case

            // Post notification to inform Main Consult Screen to reload
            NotificationCenter.default.post(
                name: NSNotification.Name("ConsultSessionUpdated"),
                object: nil,
                userInfo: ["session": session]
            )
        }

        // Pop back to the previous screen
        self.navigationController?.popViewController(animated: true)
    }

    override func viewDidLayoutSubviews() {
        super.viewDidLayoutSubviews()
        screenGradientLayer?.frame = view.bounds
    }

    private func loadSessionData() {

        // If session was passed from previous screen
        if let session = consultSession {
            sessionTitle = session.title
            symptoms = session.symptoms
            medications = session.medications
            records = session.records
            questions = session.questions
        } else {
            // fallback for testing
            let sampleSession = SampleData.consultSessions.first!

            sessionTitle = sampleSession.title
            symptoms = sampleSession.symptoms
            medications = sampleSession.medications
            records = sampleSession.records
            questions = sampleSession.questions
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

        collectionView.collectionViewLayout = generateLayout()
    }

    private func applyScreenBackgroundGradient() {
        if screenGradientLayer != nil { return }

        let gradient = CAGradientLayer()
        gradient.colors = [
            UIColor(hex: "D9EBFF")!.cgColor,
            UIColor(hex: "F7F9FC")!.cgColor,
        ]

        gradient.startPoint = CGPoint(x: 0.5, y: 0.0)
        gradient.endPoint = CGPoint(x: 0.5, y: 1.0)
        gradient.locations = [0.0, 1.0]

        gradient.frame = view.bounds
        view.layer.insertSublayer(gradient, at: 0)

        screenGradientLayer = gradient
    }

    private func generateLayout() -> UICollectionViewCompositionalLayout {
        UICollectionViewCompositionalLayout { sectionIndex, _ in
            switch sectionIndex {
            case 0:
                return self.headerSection()
            case 1:
                return self.symptomsSection()
            case 2:
                return self.medicationsSection()
            case 3:
                return self.recordsSection()
            case 4:
                return self.questionsSection()
            default:
                return nil
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

        // Section header
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

    func collectionView(
        _ collectionView: UICollectionView,
        didSelectItemAt indexPath: IndexPath
    ) {
        if indexPath.section == 1 {
            symptoms[indexPath.item].isExpanded.toggle()
            let symptom = symptoms[indexPath.item]
            if let cell = collectionView.cellForItem(at: indexPath) as? SymptomCollectionViewCell {
                cell.configure(
                    title: symptom.name, description: symptom.description,
                    isExpanded: symptom.isExpanded)
            }
            collectionView.performBatchUpdates(nil)
        } else if indexPath.section == 3 {
            let selectedRecord = records[indexPath.item]
            let storyboard = UIStoryboard(name: "Main", bundle: nil)
            if let destinationVC = storyboard.instantiateViewController(
                withIdentifier: "RecordDetailedViewController") as? RecordDetailedViewController
            {
                destinationVC.record = selectedRecord
                if let navigationController = self.navigationController {
                    navigationController.pushViewController(destinationVC, animated: true)
                } else {
                    self.present(destinationVC, animated: true, completion: nil)
                }
            } else {
                print("Could not instantiate RecordDetailedViewController")
            }
        } else if indexPath.section == 4 {
            questions[indexPath.item].isSelected.toggle()
            if let cell = collectionView.cellForItem(at: indexPath) as? QuestionCollectionViewCell {
                cell.configure(with: questions[indexPath.item])
            }
            collectionView.performBatchUpdates(nil)
        }
    }
}

extension ConsultDetailedViewController: UICollectionViewDataSource {

    func numberOfSections(in collectionView: UICollectionView) -> Int {
        return 5
    }

    func collectionView(_ collectionView: UICollectionView, numberOfItemsInSection section: Int)
        -> Int
    {
        switch section {
        case 0: return 1
        case 1: return symptoms.count
        case 2: return medications.count
        case 3: return records.count
        case 4: return questions.count
        default: return 0
        }
    }

    func collectionView(_ collectionView: UICollectionView, cellForItemAt indexPath: IndexPath)
        -> UICollectionViewCell
    {

        if indexPath.section == 0 {
            let cell =
                collectionView.dequeueReusableCell(
                    withReuseIdentifier: "HeaderCell", for: indexPath) as! HeaderCollectionViewCell
            cell.titleLabel.text = sessionTitle
            return cell
        } else if indexPath.section == 1 {
            let cell =
                collectionView.dequeueReusableCell(
                    withReuseIdentifier: "SymptomCell", for: indexPath)
                as! SymptomCollectionViewCell
            let symptom = symptoms[indexPath.item]
            cell.configure(
                title: symptom.name, description: symptom.description,
                isExpanded: symptom.isExpanded)

            cell.onChevronTap = { [weak self, weak cell] in
                guard
                    let self = self,
                    let cell = cell,
                    let tappedIndexPath = self.collectionView.indexPath(for: cell)
                else { return }

                self.symptoms[tappedIndexPath.item].isExpanded.toggle()
                let symptom = self.symptoms[tappedIndexPath.item]
                cell.configure(
                    title: symptom.name, description: symptom.description,
                    isExpanded: symptom.isExpanded)

                self.collectionView.performBatchUpdates(nil)
            }
            return cell
        } else if indexPath.section == 2 {
            let cell =
                collectionView.dequeueReusableCell(
                    withReuseIdentifier: "MedicationCell", for: indexPath)
                as! MedicationCollectionViewCell
            let med = medications[indexPath.item]
            cell.configure(
                name: med.name, dosage: med.dosage ?? "", frequency: med.frequency?.rawValue ?? "",
                duration: med.duration ?? "")
            return cell
        } else if indexPath.section == 3 {
            let cell =
                collectionView.dequeueReusableCell(
                    withReuseIdentifier: "RecordCell", for: indexPath)
                as! RecordCardCollectionViewCell
            let record = records[indexPath.item]
            cell.configure(with: record)
            return cell
        } else if indexPath.section == 4 {
            let cell =
                collectionView.dequeueReusableCell(
                    withReuseIdentifier: "QuestionCell", for: indexPath)
                as! QuestionCollectionViewCell
            cell.configure(with: questions[indexPath.item])
            return cell
        }

        // Return empty cell if none matched (should not happen)
        return UICollectionViewCell()
    }

    func collectionView(
        _ collectionView: UICollectionView, viewForSupplementaryElementOfKind kind: String,
        at indexPath: IndexPath
    ) -> UICollectionReusableView {

        guard kind == UICollectionView.elementKindSectionHeader else {
            return UICollectionReusableView()
        }

        let header =
            collectionView.dequeueReusableSupplementaryView(
                ofKind: kind, withReuseIdentifier: "SectionHeaderView", for: indexPath)
            as! SectionHeaderView

        switch indexPath.section {
        case 1:
            header.configure(title: "Symptoms")
        case 2:
            header.configure(title: "Current Medications")
        case 3:
            header.configure(title: "Added Records")
        case 4:
            header.configure(title: "Questions")
        default:
            header.configure(title: "")
        }
        return header
    }
}
