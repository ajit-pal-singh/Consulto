import UIKit

class HomeViewController: UIViewController, UINavigationControllerDelegate,
                          UICollectionViewDataSource,
                          UICollectionViewDelegate {

    private enum HomeSection: Int, CaseIterable {
        case consultation
        case medicineReminders
        case quickActions
        case recentVitals
    }

    private enum HomeMedicineListRow {
        case dose(HomeMedicine)
        case listFooter(hiddenCountWhenCollapsed: Int, isExpanded: Bool)
    }

    private struct QuickActionItem {
        let title: String
        let assetName: String?
        let tintColor: UIColor
    }
    
    private var vitalReadings: [VitalReading] = VitalData.generateMockData()
    
    private struct RecentVitals {
        let assetName: String?
        let title: String
        let unit: String
    }

    private let maxMedicineRowsOnHome = 3
    private var isMedicineHomeListExpanded = false

    @IBOutlet weak var headerActionsContainerView: UIView!
    @IBOutlet weak var homeCollectionView: UICollectionView!
    @IBOutlet weak var blurEffectView: UIVisualEffectView!
    @IBOutlet weak var profileButton: UIButton!

    private var upcomingConsultation: ConsultSession? {
        ConsultSessionStore.shared.nearestPendingSession()
    }

    private var homeMedicineRows: [HomeMedicineListRow] {
        let items: [HomeMedicine] = MedicineStore.shared.medicines.map {
            HomeMedicine(
                rowId: $0.rowId,
                name: $0.name,
                dosage: $0.dosage,
                time: $0.time,
                mealTime: $0.mealTime,
                isDone: $0.isDone
            )
        }
        guard !items.isEmpty else { return [] }
        if items.count <= maxMedicineRowsOnHome {
            return items.map { .dose($0) }
        }
        let hiddenCount = items.count - maxMedicineRowsOnHome
        if isMedicineHomeListExpanded {
            return items.map { .dose($0) } + [.listFooter(hiddenCountWhenCollapsed: hiddenCount, isExpanded: true)]
        }
        let visible = Array(items.prefix(maxMedicineRowsOnHome)).map { HomeMedicineListRow.dose($0) }
        return visible + [.listFooter(hiddenCountWhenCollapsed: hiddenCount, isExpanded: false)]
    }

    private let quickActions: [QuickActionItem] = [
        QuickActionItem(title: "Add Record", assetName: "Records", tintColor: UIColor(named: "PrescriptionColor") ?? .systemBlue),
        QuickActionItem(title: "Log Vitals", assetName: "Vitals", tintColor: UIColor(named: "ReportColor") ?? .systemRed),
        QuickActionItem(title: "Prepare", assetName: "Consult", tintColor: UIColor(named: "ScanColor") ?? .systemPurple)
    ]
    
    private let recentVitals: [RecentVitals] = [
        RecentVitals(assetName: "HeartSymbol", title: "Heart Rate", unit: "bpm"),
        RecentVitals(assetName: "Blood Symbol", title: "Blood Pressure", unit: "mmHg"),
        RecentVitals(assetName: "GlucometerFill", title: "Blood Glucose", unit: "mg/dL"),
        RecentVitals(assetName: "Body Symbol", title: "Body Weight", unit: "kg"),
    ]

    required init?(coder: NSCoder) {
        super.init(coder: coder)

        tabBarItem = UITabBarItem(
            title: "Home",
            image: UIImage(named: "Home"),
            selectedImage: UIImage(systemName: "house")
        )
    }

    override func viewDidLoad() {
        super.viewDidLoad()

        homeCollectionView.delegate = self
        homeCollectionView.dataSource = self
        homeCollectionView.showsVerticalScrollIndicator = false

        blurEffectView.backgroundColor = UIColor(hex: "F1F6FF")
        homeCollectionView.backgroundColor = UIColor(hex: "F1F6FF")
        configureProfileButton()

        homeCollectionView.register(UINib(nibName: "HomeConsultCardCollectionViewCell", bundle: nil),
                                    forCellWithReuseIdentifier: "HomeConsultCell")
        homeCollectionView.register(
            UINib(nibName: "HomeSectionHeaderCollectionViewCell", bundle: nil), forSupplementaryViewOfKind: UICollectionView.elementKindSectionHeader,
            withReuseIdentifier: "HeaderView")

        homeCollectionView.register(UINib(nibName: "QuickActionCollectionViewCell", bundle: nil),
                                    forCellWithReuseIdentifier: "QuickActionCell")
        homeCollectionView.register(UINib(nibName: "HomeMedicineCollectionViewCell", bundle: nil), forCellWithReuseIdentifier: "HomeMedicineCell")
        homeCollectionView.register(HomeMoreMedicinesCollectionViewCell.self, forCellWithReuseIdentifier: HomeMoreMedicinesCollectionViewCell.reuseId)
        homeCollectionView.register(UINib(nibName: "HomeVitalsCollectionViewCell", bundle: nil), forCellWithReuseIdentifier: "HomeVitalsCell")

        homeCollectionView.collectionViewLayout = createLayout()

        NotificationCenter.default.addObserver(
            self,
            selector: #selector(handleConsultSessionChange),
            name: NSNotification.Name("ConsultSessionUpdated"),
            object: nil
        )

        NotificationCenter.default.addObserver(
            self,
            selector: #selector(handleConsultSessionChange),
            name: NSNotification.Name("NewConsultSessionCreated"),
            object: nil
        )

        NotificationCenter.default.addObserver(
            self,
            selector: #selector(handleMedicineUpdate),
            name: NSNotification.Name("MedicineUpdated"),
            object: nil
        )
        
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(handleVitalsUpdate),
            name: NSNotification.Name("VitalsUpdated"),
            object: nil
        )
    }

    override func viewDidLayoutSubviews() {
        super.viewDidLayoutSubviews()
        profileButton.layer.cornerRadius = profileButton.bounds.height / 2
    }

    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        navigationController?.setNavigationBarHidden(true, animated: animated)
        MedicineStore.shared.syncFromMedications(MedicationReminderStore.shared.medications)
        vitalReadings = VitalData.generateMockData()
        homeCollectionView.reloadData()
    }

    override func viewWillDisappear(_ animated: Bool) {
        super.viewWillDisappear(animated)
        navigationController?.setNavigationBarHidden(false, animated: animated)
    }

    deinit {
        NotificationCenter.default.removeObserver(self)
    }

    @objc private func handleConsultSessionChange() {
        homeCollectionView.reloadData()
    }

    @objc private func handleMedicineUpdate() {
        if MedicineStore.shared.medicines.count <= maxMedicineRowsOnHome {
            isMedicineHomeListExpanded = false
        }
        homeCollectionView.reloadData()
    }
    
    @objc private func handleVitalsUpdate() {
        vitalReadings = VitalData.generateMockData()
        homeCollectionView.reloadData()
    }

    private func configureProfileButton() {
        let symbolConfig = UIImage.SymbolConfiguration(pointSize: 22, weight: .medium)
        profileButton.setImage(UIImage(systemName: "person.fill", withConfiguration: symbolConfig), for: .normal)
        profileButton.tintColor = UIColor(red: 0.36, green: 0.60, blue: 0.86, alpha: 1)
        profileButton.backgroundColor = UIColor(red: 0.78, green: 0.89, blue: 1.0, alpha: 1)
        profileButton.clipsToBounds = true
        profileButton.imageView?.contentMode = .scaleAspectFit
        profileButton.contentHorizontalAlignment = .center
        profileButton.contentVerticalAlignment = .center
        profileButton.contentEdgeInsets = UIEdgeInsets(top: 9, left: 9, bottom: 9, right: 9)
        profileButton.layer.cornerCurve = .continuous
    }

    private func toggleMedicineHomeListExpanded() {
        isMedicineHomeListExpanded.toggle()
        homeCollectionView.reloadSections(IndexSet(integer: HomeSection.medicineReminders.rawValue))
    }

    private func openRemindersScreen() {
        let storyboard = UIStoryboard(name: "RemindersScreen", bundle: nil)
        guard let remindersVC = storyboard.instantiateViewController(withIdentifier: "RemindersVC") as? RemindersViewController else { return }
        remindersVC.hidesBottomBarWhenPushed = true
        navigationController?.pushViewController(remindersVC, animated: true)
    }
    
    private func openVitalsScreen() {
        let storyboard = UIStoryboard(name: "Vital", bundle: nil)
        guard let vc = storyboard.instantiateViewController(
            withIdentifier: "VitalViewController"
        ) as? ViewController else {
            return }
        navigationController?.pushViewController(vc, animated: true)
    }

    func numberOfSections(in collectionView: UICollectionView) -> Int {
        HomeSection.allCases.count
    }

    func collectionView(_ collectionView: UICollectionView, numberOfItemsInSection section: Int) -> Int {
        guard let section = HomeSection(rawValue: section) else { return 0 }

        switch section {
        case .consultation:
            return upcomingConsultation == nil ? 0 : 1
        case .medicineReminders:
            return homeMedicineRows.count
        case .quickActions:
            return quickActions.count
        case .recentVitals:
            return recentVitals.count
        }
    }

    func collectionView(_ collectionView: UICollectionView, cellForItemAt indexPath: IndexPath) -> UICollectionViewCell {
        guard let section = HomeSection(rawValue: indexPath.section) else {
            return UICollectionViewCell()
        }

        switch section {
        case .consultation:
            let cell = collectionView.dequeueReusableCell(withReuseIdentifier: "HomeConsultCell", for: indexPath) as! HomeConsultCardCollectionViewCell

            if let consultation = upcomingConsultation {
                cell.headingLabel.text = "UPCOMING CONSULTATION"
                cell.nameLabel.text = consultation.doctorName
                cell.purposeLabel.text = consultation.title
                cell.dateLabel.text = formatDate(consultation.date)
                cell.timeLabel.text = formatTime(consultation.date)
                cell.onTapMarkDone = { [weak self] in
                    self?.markConsultationAsCompleted(consultation)
                }
                cell.onTapOpenSession = { [weak self] in
                    self?.openConsultationDetail(for: consultation)
                }
            }
            return cell

        case .medicineReminders:
            let row = homeMedicineRows[indexPath.item]
            switch row {
            case .dose(let item):
                let cell = collectionView.dequeueReusableCell(
                    withReuseIdentifier: "HomeMedicineCell",
                    for: indexPath) as! HomeMedicineCollectionViewCell
                let rowId = item.rowId
                cell.configure(with: item)
                cell.onStatusTapped = { [weak self] in
                    guard let self = self else { return }
                    MedicineStore.shared.toggleDone(rowId: rowId)
                    self.homeCollectionView.reloadSections(IndexSet(integer: HomeSection.medicineReminders.rawValue))
                }
                return cell
            case .listFooter(let hiddenCount, let isExpanded):
                let cell = collectionView.dequeueReusableCell(
                    withReuseIdentifier: HomeMoreMedicinesCollectionViewCell.reuseId,
                    for: indexPath) as! HomeMoreMedicinesCollectionViewCell
                cell.configure(hiddenCountWhenCollapsed: hiddenCount, isExpanded: isExpanded)
                cell.onTap = { [weak self] in
                    self?.toggleMedicineHomeListExpanded()
                }
                return cell
            }
        case .quickActions:
            let cell = collectionView.dequeueReusableCell(withReuseIdentifier: "QuickActionCell", for: indexPath) as! QuickActionCollectionViewCell
            let item = quickActions[indexPath.item]
            cell.actionLabel.text = item.title
            if let assetName = item.assetName {
                cell.iconImageview.image = UIImage(named: assetName)
            } else {
                cell.iconImageview.image = nil
            }
            cell.iconImageview.tintColor = item.tintColor
            return cell
        case .recentVitals:
            let cell = collectionView.dequeueReusableCell(
                withReuseIdentifier: "HomeVitalsCell",
                for: indexPath
            ) as! HomeVitalsCollectionViewCell
            let item = recentVitals[indexPath.item]
            let reading = vitalReadings.first { $0.title == item.title }
            let value = reading?.value ?? "--"
            cell.configure(title: item.title, value: value, unit: item.unit, imageName: item.assetName)
            return cell
    }
}

    func collectionView(_ collectionView: UICollectionView, viewForSupplementaryElementOfKind kind: String, at indexPath: IndexPath) -> UICollectionReusableView {
        let header = collectionView.dequeueReusableSupplementaryView(
            ofKind: kind,
            withReuseIdentifier: "HeaderView",
            for: indexPath
        ) as! HomeSectionHeaderCollectionViewCell
        let section = HomeSection(rawValue: indexPath.section)!
        switch section {
        case .medicineReminders:
            header.configure(title: "Today's Medicines", showsViewAll: true)
            header.onViewAllTapped = { [weak self] in
                self?.openRemindersScreen()
            }
        case .quickActions:
            header.configure(title: "Quick Actions", showsViewAll: false)
        case .recentVitals:
            header.configure(title: "Recent Vitals", showsViewAll: true)
            header.onViewAllTapped = { [weak self] in self?.openVitalsScreen()
            }
        default:
            header.configure(title: "", showsViewAll: false)
        }
        return header
    }

    func collectionView(_ collectionView: UICollectionView, didSelectItemAt indexPath: IndexPath) {
        guard let section = HomeSection(rawValue: indexPath.section) else { return }

        switch section {
        case .consultation:
            if let consultation = upcomingConsultation {
                openConsultationDetail(for: consultation)
            }
        case .medicineReminders:
            break
        case .quickActions:
            handleQuickActionTap(at: indexPath.item)
        case .recentVitals:
            break
        }
    }

    private func formatDate(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "dd MMM yyyy"
        return formatter.string(from: date)
    }

    private func formatTime(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "h:mm a"
        return formatter.string(from: date)
    }

    private func markConsultationAsCompleted(_ session: ConsultSession) {
        var updatedSession = session
        updatedSession.status = .completed

        ConsultSessionStore.shared.updateSession(updatedSession)

        NotificationCenter.default.post(
            name: NSNotification.Name("ConsultSessionUpdated"),
            object: nil,
            userInfo: ["session": updatedSession]
        )

        homeCollectionView.reloadData()
    }

    private func openConsultationDetail(for session: ConsultSession) {
        let storyboard = UIStoryboard(name: "ConsultDetailView", bundle: nil)
        guard let detailVC = storyboard.instantiateViewController(
            withIdentifier: "ConsultDetailedView"
        ) as? ConsultDetailedViewController else {
            return
        }

        detailVC.consultSession = session
        navigationController?.pushViewController(detailVC, animated: true)
    }

    private func handleQuickActionTap(at index: Int) {
        switch index {
        case 0:
            let storyboard = UIStoryboard(name: "Main", bundle: nil)
            guard let recordsVC = storyboard.instantiateViewController(withIdentifier: "RecordsViewController") as? RecordsViewController else { return }
            recordsVC.shouldShowAttachmentPlatterOnAppear = true
            navigationController?.pushViewController(recordsVC, animated: true)
        case 1:
            let storyboard = UIStoryboard(name: "Vital", bundle: nil)
            guard let vitalsVC = storyboard.instantiateViewController(withIdentifier: "VitalViewController") as? ViewController else { return }
            vitalsVC.shouldShowAddReadingPlatterOnAppear = true
            navigationController?.pushViewController(vitalsVC, animated: true)
        case 2:
            let storyboard = UIStoryboard(name: "Consult-Screen", bundle: nil)
            guard let navVC = storyboard.instantiateViewController(withIdentifier: "PrepareConsultationNav") as? UINavigationController else { return }
            present(navVC, animated: true)
        default:
            break
        }
    }

    private func createLayout() -> UICollectionViewLayout {
        UICollectionViewCompositionalLayout { [weak self] sectionIndex, _ in
            guard let section = HomeSection(rawValue: sectionIndex) else { return nil }

            switch section {
            case .consultation:
                let itemSize = NSCollectionLayoutSize(
                    widthDimension: .fractionalWidth(1.0),
                    heightDimension: .estimated(180)
                )
                let item = NSCollectionLayoutItem(layoutSize: itemSize)
                let group = NSCollectionLayoutGroup.vertical(layoutSize: itemSize, subitems: [item])
                let section = NSCollectionLayoutSection(group: group)
                section.contentInsets = NSDirectionalEdgeInsets(top: 64, leading: 16, bottom: 4, trailing: 16)
                return section

            case .medicineReminders:
                let itemSize = NSCollectionLayoutSize(
                    widthDimension: .fractionalWidth(1.0),
                    heightDimension: .estimated(90)
                )

                let item = NSCollectionLayoutItem(layoutSize: itemSize)

                let group = NSCollectionLayoutGroup.vertical(
                    layoutSize: itemSize,
                    subitems: [item]
                )
                
                let section = NSCollectionLayoutSection(group: group)
                section.interGroupSpacing = 10
                section.contentInsets = NSDirectionalEdgeInsets(top: 0, leading: 16, bottom: 0, trailing: 16)

                let header = NSCollectionLayoutBoundarySupplementaryItem(
                    layoutSize: NSCollectionLayoutSize(widthDimension: .fractionalWidth(1.0), heightDimension: .absolute(40)), elementKind: UICollectionView.elementKindSectionHeader,
                    alignment: .top)
                section.boundarySupplementaryItems = [header]
                return section

            case .quickActions:
                let itemSize = NSCollectionLayoutSize(
                    widthDimension: .fractionalWidth(1.0 / 3.0),
                    heightDimension: .estimated(104)
                )
                let item = NSCollectionLayoutItem(layoutSize: itemSize)
                let groupSize = NSCollectionLayoutSize(
                    widthDimension: .fractionalWidth(1.0),
                    heightDimension: .estimated(104)
                )
                let group = NSCollectionLayoutGroup.horizontal(layoutSize: groupSize, repeatingSubitem: item, count: 3)
                group.interItemSpacing = .fixed(10)

                let section = NSCollectionLayoutSection(group: group)
                section.contentInsets = NSDirectionalEdgeInsets(top: 0, leading: 16, bottom: 4, trailing: 16)

                let header = NSCollectionLayoutBoundarySupplementaryItem(
                    layoutSize: NSCollectionLayoutSize(widthDimension: .fractionalWidth(1.0), heightDimension: .absolute(40)), elementKind: UICollectionView.elementKindSectionHeader,
                    alignment: .top)
                section.boundarySupplementaryItems = [header]
                return section
                
            case .recentVitals:
                let itemSize = NSCollectionLayoutSize(
                    widthDimension: .fractionalWidth(0.5),
                    heightDimension: .absolute(90))
                let item = NSCollectionLayoutItem(layoutSize: itemSize)
                
                let groupSize = NSCollectionLayoutSize(
                    widthDimension: .fractionalWidth(1.0),
                    heightDimension: .absolute(90)
                )
                let group = NSCollectionLayoutGroup.horizontal(layoutSize: groupSize, subitems: [item])
                group.interItemSpacing = .fixed(10)

                let section = NSCollectionLayoutSection(group: group)
                section.contentInsets = NSDirectionalEdgeInsets(
                    top: 0, leading: 16, bottom: 0, trailing: 16)
                section.interGroupSpacing = 10
                
                let header = NSCollectionLayoutBoundarySupplementaryItem(
                    layoutSize: NSCollectionLayoutSize(
                        widthDimension: .fractionalWidth(1.0),
                        heightDimension: .absolute(40)
                    ),
                    elementKind: UICollectionView.elementKindSectionHeader,
                    alignment: .top
                )
                section.boundarySupplementaryItems = [header]
                return section
            }
        }
    }
}

final class HomeMoreMedicinesCollectionViewCell: UICollectionViewCell {

    static let reuseId = "HomeMoreMedicinesCell"

    private let pillView: UIView = {
        let v = UIView()
        v.translatesAutoresizingMaskIntoConstraints = false
        v.backgroundColor = .white
        v.layer.cornerCurve = .continuous
        return v
    }()

    private let actionButton: UIButton = {
        let b = UIButton(type: .system)
        b.translatesAutoresizingMaskIntoConstraints = false
        return b
    }()

    var onTap: (() -> Void)?

    private var hiddenCountWhenCollapsed: Int = 0
    private var listExpanded: Bool = false

    override init(frame: CGRect) {
        super.init(frame: frame)
        contentView.backgroundColor = .clear
        contentView.addSubview(pillView)
        pillView.addSubview(actionButton)
        NSLayoutConstraint.activate([
            pillView.leadingAnchor.constraint(equalTo: contentView.leadingAnchor, constant: 2),
            pillView.topAnchor.constraint(equalTo: contentView.topAnchor, constant: 2),
            pillView.bottomAnchor.constraint(equalTo: contentView.bottomAnchor, constant: -4),

            actionButton.leadingAnchor.constraint(equalTo: pillView.leadingAnchor),
            actionButton.trailingAnchor.constraint(equalTo: pillView.trailingAnchor),
            actionButton.topAnchor.constraint(equalTo: pillView.topAnchor),
            actionButton.bottomAnchor.constraint(equalTo: pillView.bottomAnchor)
        ])
        actionButton.addTarget(self, action: #selector(buttonTapped), for: .touchUpInside)
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    override func layoutSubviews() {
        super.layoutSubviews()
        let h = pillView.bounds.height
        pillView.layer.cornerRadius = h > 0 ? h / 2 : 18
        pillView.layer.shadowPath = UIBezierPath(roundedRect: pillView.bounds, cornerRadius: pillView.layer.cornerRadius).cgPath
    }

    override func prepareForReuse() {
        super.prepareForReuse()
        onTap = nil
    }

    func configure(hiddenCountWhenCollapsed: Int, isExpanded: Bool) {
        self.hiddenCountWhenCollapsed = hiddenCountWhenCollapsed
        self.listExpanded = isExpanded
        pillView.layer.shadowColor = UIColor.black.cgColor
        pillView.layer.shadowOffset = CGSize(width: 0, height: 2)
        pillView.layer.shadowRadius = 6
        pillView.layer.shadowOpacity = 0.08
        pillView.layer.masksToBounds = false
        applyButtonConfiguration()
    }

    private func applyButtonConfiguration() {
        let font = UIFont.systemFont(ofSize: 14, weight: .medium).rounded
        let title: String
        let chevronName: String
        if listExpanded {
            title = "Show less"
            chevronName = "chevron.up"
        } else {
            title = "+\(hiddenCountWhenCollapsed) more"
            chevronName = "chevron.down"
        }

        let symbolConfig = UIImage.SymbolConfiguration(pointSize: 11, weight: .semibold)
        let chevron = UIImage(systemName: chevronName, withConfiguration: symbolConfig)?
            .withTintColor(.black, renderingMode: .alwaysOriginal)

        var config = UIButton.Configuration.plain()
        config.title = title
        config.image = chevron
        config.imagePlacement = .trailing
        config.imagePadding = 6
        config.baseForegroundColor = .black
        config.background.backgroundColor = .clear
        config.contentInsets = NSDirectionalEdgeInsets(top: 10, leading: 16, bottom: 10, trailing: 14)
        config.titleTextAttributesTransformer = UIConfigurationTextAttributesTransformer { incoming in
            var outgoing = incoming
            outgoing.font = font
            outgoing.foregroundColor = .black
            return outgoing
        }

        actionButton.configuration = config

        actionButton.configurationUpdateHandler = { [weak self] button in
            guard let self = self else { return }
            let font = UIFont.systemFont(ofSize: 15, weight: .medium).rounded
            let title: String
            let chevronName: String
            if self.listExpanded {
                title = "Show less"
                chevronName = "chevron.up"
            } else {
                title = "+\(self.hiddenCountWhenCollapsed) more"
                chevronName = "chevron.down"
            }
            let symbolConfig = UIImage.SymbolConfiguration(pointSize: 11, weight: .semibold)
            let chevron = UIImage(systemName: chevronName, withConfiguration: symbolConfig)?
                .withTintColor(.black, renderingMode: .alwaysOriginal)

            var c = button.configuration ?? .plain()
            c.title = title
            c.image = chevron
            c.imagePlacement = .trailing
            c.imagePadding = 6
            c.baseForegroundColor = .black
            c.background.backgroundColor = .clear
            c.contentInsets = NSDirectionalEdgeInsets(top: 8, leading: 16, bottom: 8, trailing: 14)
            c.titleTextAttributesTransformer = UIConfigurationTextAttributesTransformer { incoming in
                var outgoing = incoming
                outgoing.font = font
                outgoing.foregroundColor = .black
                return outgoing
            }
            button.configuration = c
        }
    }

    @objc private func buttonTapped() {
        onTap?()
    }
}
