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
    
    var sessionTitle: String = ""
    var symptoms: [Symptom] = []
    var medications: [Medication] = []
    var records: [HealthRecord] = []
    var questions: [Question] = []

    override func viewDidLoad() {
        super.viewDidLoad()
        view.backgroundColor = .clear
        collectionView.backgroundColor = .clear
        
        sessionTitle = ConsultSessionDataModel.sampleSessionTitle()
        symptoms = ConsultSessionDataModel.sampleSymptoms()
        medications = ConsultSessionDataModel.sampleMedications()
        records = ConsultSessionDataModel.sampleRecords()
        questions = ConsultSessionDataModel.sampleQuestions()

        setupCollectionView()
        applyScreenBackgroundGradient()
        collectionView.reloadData()
    }
    
    override func viewDidLayoutSubviews() {
        super.viewDidLayoutSubviews()
        screenGradientLayer?.frame = view.bounds
    }
    
    private func setupCollectionView() {
        collectionView.dataSource = self
        collectionView.delegate = self
        collectionView.contentInsetAdjustmentBehavior = .never
        
        collectionView.register(UINib(nibName: "HeaderCollectionViewCell", bundle: nil), forCellWithReuseIdentifier: "HeaderCell")
        
        collectionView.register(UINib(nibName: "SymptomCollectionViewCell", bundle: nil),
            forCellWithReuseIdentifier: "SymptomCell")
        
        collectionView.register(UINib(nibName: "SectionHeaderView", bundle: nil),
            forSupplementaryViewOfKind: UICollectionView.elementKindSectionHeader, withReuseIdentifier: "SectionHeaderView")
        
        collectionView.register(UINib(nibName: "MedicationCollectionViewCell", bundle: nil), forCellWithReuseIdentifier: "MedicationCell")
        
        collectionView.register(UINib(nibName: "RecordCardCollectionViewCell", bundle: nil), forCellWithReuseIdentifier: "RecordCell")
        
        collectionView.register(UINib(nibName: "QuestionCollectionViewCell", bundle: nil), forCellWithReuseIdentifier: "QuestionCell")
        
        collectionView.collectionViewLayout = generateLayout()
    }
    
    private func applyScreenBackgroundGradient() {
            if screenGradientLayer != nil { return }
    
            let gradient = CAGradientLayer()
            gradient.colors = [
                UIColor(hex: "D9EBFF")!.cgColor,
                UIColor(hex: "F7F9FC")!.cgColor
            ]
    
            gradient.startPoint = CGPoint(x: 0.5, y: 0.0)
            gradient.endPoint   = CGPoint(x: 0.5, y: 1.0)
            gradient.locations  = [0.0, 1.0]
    
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

        let itemSize = NSCollectionLayoutSize(widthDimension: .fractionalWidth(1.0), heightDimension: .absolute(120))

        let item = NSCollectionLayoutItem(layoutSize: itemSize)

        let group = NSCollectionLayoutGroup.horizontal(layoutSize: itemSize, subitems: [item])

        let section = NSCollectionLayoutSection(group: group)
        section.contentInsets = NSDirectionalEdgeInsets(top: 120, leading: 16, bottom: 0, trailing: 16)

        return section
    }
    
    private func symptomsSection() -> NSCollectionLayoutSection {

        let itemSize = NSCollectionLayoutSize(widthDimension: .fractionalWidth(1.0), heightDimension: .estimated(140))

        let item = NSCollectionLayoutItem(layoutSize: itemSize)

        let groupSize = NSCollectionLayoutSize(widthDimension: .fractionalWidth(1.0),
            heightDimension: .estimated(140))

        let group = NSCollectionLayoutGroup.vertical(layoutSize: groupSize, subitems: [item])

        let section = NSCollectionLayoutSection(group: group)
        section.interGroupSpacing = 6
        section.contentInsets = NSDirectionalEdgeInsets(top: 0, leading: 16, bottom: 0, trailing: 16)

        // Section header
        let headerSize = NSCollectionLayoutSize(widthDimension: .fractionalWidth(1.0), heightDimension: .absolute(50))

        let header = NSCollectionLayoutBoundarySupplementaryItem(layoutSize: headerSize, elementKind: UICollectionView.elementKindSectionHeader, alignment: .top)

        section.boundarySupplementaryItems = [header]

        return section
    }
    
    private func medicationsSection() -> NSCollectionLayoutSection {
        
        let itemSize = NSCollectionLayoutSize(widthDimension: .fractionalWidth(0.5), heightDimension: .absolute(114))
        let item = NSCollectionLayoutItem(layoutSize: itemSize)

        let groupSize = NSCollectionLayoutSize(widthDimension: .fractionalWidth(1.0),
            heightDimension: .absolute(114))
        let group = NSCollectionLayoutGroup.horizontal(layoutSize: groupSize, subitems: [item])
        group.interItemSpacing = .fixed(16)

        let section = NSCollectionLayoutSection(group: group)
        section.contentInsets = NSDirectionalEdgeInsets(top: 0, leading: 16, bottom: 0, trailing: 16)
        section.interGroupSpacing = 16

        let headerSize = NSCollectionLayoutSize(widthDimension: .fractionalWidth(1.0),
            heightDimension: .absolute(50))

        let header = NSCollectionLayoutBoundarySupplementaryItem(layoutSize: headerSize,
            elementKind: UICollectionView.elementKindSectionHeader, alignment: .top)

        section.boundarySupplementaryItems = [header]

        return section
    }
    
    private func recordsSection() -> NSCollectionLayoutSection {
        let itemSize = NSCollectionLayoutSize(widthDimension: .fractionalWidth(0.5), heightDimension: .absolute(140))

        let item = NSCollectionLayoutItem(layoutSize: itemSize)

        // Horizontal spacing between two cards
        item.contentInsets = NSDirectionalEdgeInsets(top: 0, leading: 0, bottom: 0, trailing: 0)

        let groupSize = NSCollectionLayoutSize(widthDimension: .fractionalWidth(1.0), heightDimension: .absolute(140))

        let group = NSCollectionLayoutGroup.horizontal(layoutSize: groupSize, subitem: item, count: 2)
        group.interItemSpacing = .fixed(16)

        let section = NSCollectionLayoutSection(group: group)

        section.contentInsets = NSDirectionalEdgeInsets(top: 0, leading: 16, bottom: 0,
            trailing: 16)
        section.interGroupSpacing = 16

        let headerSize = NSCollectionLayoutSize(widthDimension: .fractionalWidth(1.0),
            heightDimension: .absolute(50))

        let header = NSCollectionLayoutBoundarySupplementaryItem(layoutSize: headerSize,
            elementKind: UICollectionView.elementKindSectionHeader, alignment: .top)
        
        section.boundarySupplementaryItems = [header]

        return section
    }
    
    private func questionsSection() -> NSCollectionLayoutSection {

        let itemSize = NSCollectionLayoutSize(widthDimension: .fractionalWidth(1.0),
            heightDimension: .estimated(75))

        let item = NSCollectionLayoutItem(layoutSize: itemSize)

        let groupSize = NSCollectionLayoutSize(widthDimension: .fractionalWidth(1.0), heightDimension: .estimated(75))

        let group = NSCollectionLayoutGroup.vertical(layoutSize: groupSize, subitems: [item])

        let section = NSCollectionLayoutSection(group: group)
        section.interGroupSpacing = 12
        section.contentInsets = NSDirectionalEdgeInsets(top: 0, leading: 16, bottom: 0, trailing: 16)
        
        let headerSize = NSCollectionLayoutSize(widthDimension: .fractionalWidth(1.0),
            heightDimension: .absolute(50))

        let header = NSCollectionLayoutBoundarySupplementaryItem(layoutSize: headerSize,
            elementKind: UICollectionView.elementKindSectionHeader, alignment: .top)

        section.boundarySupplementaryItems = [header]

        return section
    }
    
    func collectionView(_ collectionView: UICollectionView,
                        didSelectItemAt indexPath: IndexPath) {
        if indexPath.section == 3 {
            questions[indexPath.item].isSelected.toggle()
            collectionView.performBatchUpdates(nil)
        }
    }
}

extension ConsultDetailedViewController: UICollectionViewDataSource {
    
    func numberOfSections(in collectionView: UICollectionView) -> Int {
        return 5
    }
    
    func collectionView(_ collectionView: UICollectionView, numberOfItemsInSection section: Int) -> Int {
        switch section {
        case 0: return 1
        case 1: return symptoms.count
        // Temporarily disabled medications section items count
        // case 2: return medications.count
        case 2: return 0
        case 3: return records.count
        // Temporarily disabled questions section items count
        // case 4: return questions.count
        case 4: return 0
        default: return 0
        }
    }
    
    func collectionView(_ collectionView: UICollectionView, cellForItemAt indexPath: IndexPath) -> UICollectionViewCell {
        
        if indexPath.section == 0 {
            let cell = collectionView.dequeueReusableCell(withReuseIdentifier: "HeaderCell", for: indexPath) as! HeaderCollectionViewCell
            cell.titleLabel.text = sessionTitle
//            cell.configure(title: sessionTitle)
            return cell
        }
        else if indexPath.section == 1 {
            let cell = collectionView.dequeueReusableCell(withReuseIdentifier: "SymptomCell", for: indexPath) as! SymptomCollectionViewCell
            let symptom = symptoms[indexPath.item]
            cell.configure(title: symptom.name, description: symptom.description, isExpanded: symptom.isExpanded)
            
            cell.onChevronTap = { [weak self, weak cell] in
                guard
                    let self = self,
                    let cell = cell,
                    let tappedIndexPath = self.collectionView.indexPath(for: cell)
                else { return }
                
                self.symptoms[tappedIndexPath.item].isExpanded.toggle()
                
                self.collectionView.performBatchUpdates(nil)
            }
            return cell
        }
        /*
        // Temporarily disabled MedicationCell block
        else if indexPath.section == 2 {
            let cell = collectionView.dequeueReusableCell(withReuseIdentifier: "MedicationCell", for: indexPath) as! MedicationCollectionViewCell
            let med = medications[indexPath.item]
            cell.configure(name: med.name, dose: med.dosage ?? "", frequency: med.frequency?.rawValue ?? "", duration: med.duration ?? "")
            return cell
        }
        */
        else if indexPath.section == 3 {
            let cell = collectionView.dequeueReusableCell(withReuseIdentifier: "RecordCell", for: indexPath) as! RecordCardCollectionViewCell
            let record = records[indexPath.item]
            cell.configure(with: record)
            return cell
        }
        /*
        // Temporarily disabled QuestionCell block
        else {
            let cell = collectionView.dequeueReusableCell(withReuseIdentifier: "QuestionCell", for: indexPath) as! QuestionCollectionViewCell
            cell.configure(with: questions[indexPath.item])
            return cell
        }
        */
        // Return empty cell if none matched (should not happen)
        return UICollectionViewCell()
    }
        
    func collectionView(_ collectionView: UICollectionView, viewForSupplementaryElementOfKind kind: String, at indexPath: IndexPath) -> UICollectionReusableView {
            
        guard kind == UICollectionView.elementKindSectionHeader else {
            return UICollectionReusableView()
        }
            
        let header = collectionView.dequeueReusableSupplementaryView(ofKind: kind, withReuseIdentifier: "SectionHeaderView", for: indexPath) as! SectionHeaderView
            
        switch indexPath.section {
        case 1:
            header.configure(title: "Symptoms")
        /*
        // Temporarily disabled medications section header
        case 2:
            header.configure(title: "Current Medications")
        */
        case 3:
            header.configure(title: "Added Records")
        /*
        // Temporarily disabled questions section header
        case 4:
            header.configure(title: "Questions")
        */
        default:
            header.configure(title: "")
        }
        return header
    }
}

