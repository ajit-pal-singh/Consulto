import UIKit
import SwiftUI
import PhotosUI
import UniformTypeIdentifiers

class HomeViewController: UIViewController, UINavigationControllerDelegate,
                          UICollectionViewDataSource,
                          UICollectionViewDelegate,
                          PHPickerViewControllerDelegate,
                          UIDocumentPickerDelegate,
                          UIImagePickerControllerDelegate {

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
    
    private var vitalReadings: [VitalReading] = VitalDataStore.shared.loadReadings()
    
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
    
    @IBOutlet weak var platterContainerView: UIView!
    @IBOutlet weak var dimmingOverlayView: UIView!
    
    private var platterViewController: AttachmentPlatterViewController?
    private var platterBottomConstraint: NSLayoutConstraint?
    private var platterHeightConstraint: NSLayoutConstraint?
    
    private var addReadingPlatterViewController: AddReadingViewController?
    private var addReadingPlatterBottomConstraint: NSLayoutConstraint?

    private var pendingConsultations: [ConsultSession] {
        ConsultSessionStore.shared.allPendingSessions()
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
        QuickActionItem(title: "Create Visit", assetName: "Consult", tintColor: UIColor(named: "ScanColor") ?? .systemPurple)
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
        homeCollectionView.contentInset = UIEdgeInsets(top: 56, left: 0, bottom: 0, right: 0)

        blurEffectView.backgroundColor = .clear
        homeCollectionView.backgroundColor = UIColor(hex: "F1F6FF")
        setupProfileButton()
        
        platterContainerView?.isUserInteractionEnabled = false
        dimmingOverlayView?.alpha = 0
        dimmingOverlayView?.isHidden = true
        dimmingOverlayView?.isUserInteractionEnabled = false

        homeCollectionView.register(UINib(nibName: "HomeConsultCardCollectionViewCell", bundle: nil),
                                    forCellWithReuseIdentifier: "HomeConsultCell")
        homeCollectionView.register(
            UINib(nibName: "HomeSectionHeaderCollectionReusableView", bundle: nil), forSupplementaryViewOfKind: UICollectionView.elementKindSectionHeader,
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

        NotificationCenter.default.addObserver(
            self,
            selector: #selector(refreshMedicineStatusesForCurrentDay),
            name: .NSCalendarDayChanged,
            object: nil
        )

        NotificationCenter.default.addObserver(
            self,
            selector: #selector(refreshMedicineStatusesForCurrentDay),
            name: UIApplication.willEnterForegroundNotification,
            object: nil
        )
    }

    override func viewDidLayoutSubviews() {
        super.viewDidLayoutSubviews()
        if blurEffectView != nil {
            setupBlurGradientMask()
        }
    }

    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        navigationController?.delegate = self
        navigationController?.setNavigationBarHidden(true, animated: animated)
        MedicineStore.shared.syncFromMedications(MedicationReminderStore.shared.medications)
        vitalReadings = VitalDataStore.shared.loadReadings()
        homeCollectionView.reloadData()
    }

    override func viewWillDisappear(_ animated: Bool) {
        super.viewWillDisappear(animated)
        if navigationController?.delegate === self {
            navigationController?.delegate = nil
        }
        navigationController?.setNavigationBarHidden(false, animated: animated)
    }
    
    func navigationController(_ navigationController: UINavigationController, willShow viewController: UIViewController, animated: Bool) {
        navigationController.setNavigationBarHidden(shouldHideNavigationBar(for: viewController), animated: animated)
    }

    private func shouldHideNavigationBar(for viewController: UIViewController) -> Bool {
        viewController is HomeViewController || viewController is ViewController
    }

    // MARK: - Blur Gradient Mask
    func setupBlurGradientMask() {
        let gradientMask = CAGradientLayer()
        gradientMask.frame = blurEffectView.bounds

        gradientMask.colors = [
            UIColor.black.cgColor,
            UIColor.black.cgColor,
            UIColor.clear.cgColor
        ]
        gradientMask.locations = [0.0, 0.8, 1.0]

        blurEffectView.layer.mask = gradientMask

        if let existingOverlay = blurEffectView.layer.sublayers?.first(where: { $0.name == "SolidOverlay" }) {
            existingOverlay.frame = blurEffectView.bounds
        } else {
            let overlayLayer = CALayer()
            overlayLayer.name = "SolidOverlay"
            overlayLayer.frame = blurEffectView.bounds
            overlayLayer.backgroundColor = UIColor(hex: "#F1F6FF").withAlphaComponent(0.5).cgColor

            let overlayMask = CAGradientLayer()
            overlayMask.frame = overlayLayer.bounds
            overlayMask.colors = gradientMask.colors
            overlayMask.locations = gradientMask.locations
            overlayLayer.mask = overlayMask

            blurEffectView.layer.addSublayer(overlayLayer)
        }
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

    @objc private func refreshMedicineStatusesForCurrentDay() {
        MedicineStore.shared.syncFromMedications(MedicationReminderStore.shared.medications)
        handleMedicineUpdate()
    }
    
    @objc private func handleVitalsUpdate() {
        vitalReadings = VitalDataStore.shared.loadReadings()
        homeCollectionView.reloadData()
    }

    private func setupProfileButton() {
        guard let container = headerActionsContainerView else { return }
        container.subviews.forEach { $0.removeFromSuperview() }
        container.backgroundColor = .clear

        let swiftUIView = HomeHeaderActionsView {
            [weak self] in
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.35) {
                self?.performSegue(withIdentifier: "ProfileSettings", sender: nil)
            }
        }

        let hostingController = UIHostingController(rootView: swiftUIView)
        hostingController.view.backgroundColor = .clear
        hostingController.view.translatesAutoresizingMaskIntoConstraints = false

        addChild(hostingController)
        container.addSubview(hostingController.view)

        NSLayoutConstraint.activate([
            hostingController.view.topAnchor.constraint(equalTo: container.topAnchor),
            hostingController.view.bottomAnchor.constraint(equalTo: container.bottomAnchor),
            hostingController.view.leadingAnchor.constraint(equalTo: container.leadingAnchor),
            hostingController.view.trailingAnchor.constraint(equalTo: container.trailingAnchor)
        ])

        hostingController.didMove(toParent: self)
    }

    private func toggleMedicineHomeListExpanded() {
        isMedicineHomeListExpanded.toggle()
        homeCollectionView.reloadSections(IndexSet(integer: HomeSection.medicineReminders.rawValue))
    }

    private func openRemindersScreen() {
        let storyboard = UIStoryboard(name: "RemindersScreen", bundle: nil)
        guard let remindersVC = storyboard.instantiateViewController(withIdentifier: "RemindersVC") as? RemindersViewController else { return }
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

    private func openVitalDetail(for title: String) {
        let latestReadings = VitalDataStore.shared.loadReadings()
        guard let reading = latestReadings.first(where: { $0.title == title }) else {
            openVitalsScreen()
            return
        }

        let storyboard = UIStoryboard(name: "Vital", bundle: nil)
        guard let detailVC = storyboard.instantiateViewController(
            withIdentifier: "VitalDetailViewController"
        ) as? VitalDetailViewController else {
            return
        }

        detailVC.reading = reading
        if reading.title == "Blood Glucose" {
            detailVC.initialGlucoseFilterType = BloodGlucoseType.from(subtitle: reading.subtitle).rawValue
        }

        navigationController?.pushViewController(detailVC, animated: true)
    }

    func numberOfSections(in collectionView: UICollectionView) -> Int {
        HomeSection.allCases.count
    }

    func collectionView(_ collectionView: UICollectionView, numberOfItemsInSection section: Int) -> Int {
        guard let section = HomeSection(rawValue: section) else { return 0 }

        switch section {
        case .consultation:
            return pendingConsultations.count
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

            let consultation = pendingConsultations[indexPath.item]
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
        ) as! HomeSectionHeaderCollectionReusableView
        let section = HomeSection(rawValue: indexPath.section)!
        switch section {
        case .consultation:
            let title = pendingConsultations.count == 1 ? "Upcoming Consultation" : "Upcoming Consultations"
            header.configure(title: title, showsViewAll: false)
        case .medicineReminders:
            let title = MedicineStore.shared.medicines.count == 1 ? "Today's Medicine" : "Today's Medicines"
            header.configure(title: title, showsViewAll: true)
            header.onViewAllTapped = { [weak self] in
                self?.openRemindersScreen()
            }
        case .quickActions:
            header.configure(title: "Quick Actions", showsViewAll: false)
        case .recentVitals:
            header.configure(title: "Recent Vitals", showsViewAll: true)
            header.onViewAllTapped = { [weak self] in self?.openVitalsScreen()
            }
        }
        return header
    }

    func collectionView(_ collectionView: UICollectionView, didSelectItemAt indexPath: IndexPath) {
        guard let section = HomeSection(rawValue: indexPath.section) else { return }

        switch section {
        case .consultation:
            if indexPath.item < pendingConsultations.count {
                openConsultationDetail(for: pendingConsultations[indexPath.item])
            }
        case .medicineReminders:
            break
        case .quickActions:
            handleQuickActionTap(at: indexPath.item)
        case .recentVitals:
            guard indexPath.item < recentVitals.count else { return }
            openVitalDetail(for: recentVitals[indexPath.item].title)
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
            showAttachmentPlatter()
        case 1:
            showAddReadingPlatter()
        case 2:
            let storyboard = UIStoryboard(name: "Consult-Screen", bundle: nil)
            guard let navVC = storyboard.instantiateViewController(withIdentifier: "PrepareConsultationNav") as? UINavigationController else { return }
            present(navVC, animated: true)
        default:
            break
        }
    }
    
    private func showAttachmentPlatter() {
        guard let container = platterContainerView else { return }
        guard platterViewController == nil, addReadingPlatterViewController == nil else { return }
        
        container.isUserInteractionEnabled = true
        
        let storyboard = UIStoryboard(name: "Main", bundle: nil)
        guard let platterVC = storyboard.instantiateViewController(withIdentifier: "AttachmentPlatterVC") as? AttachmentPlatterViewController else {
            return
        }
        
        platterVC.onCameraTap = { [weak self] in
            self?.dismissPlatter()
            self?.openCamera()
        }
        platterVC.onGalleryTap = { [weak self] in
            self?.dismissPlatter()
            self?.openGallery()
        }
        platterVC.onDocumentTap = { [weak self] in
            self?.dismissPlatter()
            self?.openDocumentPicker()
        }
        platterVC.onDismiss = { [weak self] in
            self?.dismissPlatter()
        }
        platterVC.onAddPhotosTapped = { [weak self] assets in
            self?.dismissPlatter()
            self?.processPlatterAssets(assets)
        }
        platterVC.onSelectionChange = { [weak self] hasSelection in
            guard let self else { return }
            let targetHeight: CGFloat = hasSelection ? 310 : 280
            let duration: TimeInterval = 0.3
            
            self.platterViewController?.animateMaskPath(toHeight: targetHeight, duration: duration)
            self.platterHeightConstraint?.constant = targetHeight
            UIView.animate(withDuration: duration, delay: 0, options: .curveEaseInOut) {
                self.view.layoutIfNeeded()
            }
        }
        
        platterVC.view.translatesAutoresizingMaskIntoConstraints = false
        addChild(platterVC)
        container.addSubview(platterVC.view)
        platterVC.didMove(toParent: self)
        
        let panGesture = UIPanGestureRecognizer(target: self, action: #selector(handlePlatterPan(_:)))
        platterVC.view.addGestureRecognizer(panGesture)
        
        let containerTap = UITapGestureRecognizer(target: self, action: #selector(containerBackgroundTapped(_:)))
        containerTap.cancelsTouchesInView = false
        container.addGestureRecognizer(containerTap)
        
        self.platterViewController = platterVC
        
        let bottomConstraint = platterVC.view.bottomAnchor.constraint(equalTo: container.bottomAnchor, constant: 400)
        self.platterBottomConstraint = bottomConstraint
        
        let heightConstraint = platterVC.view.heightAnchor.constraint(equalToConstant: 280)
        self.platterHeightConstraint = heightConstraint
        
        NSLayoutConstraint.activate([
            platterVC.view.leadingAnchor.constraint(equalTo: container.leadingAnchor, constant: 5),
            platterVC.view.trailingAnchor.constraint(equalTo: container.trailingAnchor, constant: -5),
            bottomConstraint,
            heightConstraint
        ])
        
        container.layoutIfNeeded()
        
        self.platterBottomConstraint?.constant = -5
        dimmingOverlayView?.isHidden = false
        dimmingOverlayView?.isUserInteractionEnabled = true
        
        UIView.animate(withDuration: 0.5, delay: 0, usingSpringWithDamping: 0.8, initialSpringVelocity: 0.5, options: .curveEaseOut) {
            self.tabBarController?.tabBar.alpha = 0
            self.dimmingOverlayView?.alpha = 0.3
            self.view.layoutIfNeeded()
        }
    }
    
    @objc private func dismissPlatter() {
        guard let vc = platterViewController else { return }
        
        platterHeightConstraint?.constant = 280
        platterViewController?.animateMaskPath(toHeight: 280, duration: 0)
        view.layoutIfNeeded()
        
        self.platterBottomConstraint?.constant = 400
        
        UIView.animate(withDuration: 0.3, animations: {
            self.tabBarController?.tabBar.alpha = 1
            self.dimmingOverlayView?.alpha = 0
            self.view.layoutIfNeeded()
        }) { _ in
            self.dimmingOverlayView?.isHidden = true
            self.dimmingOverlayView?.isUserInteractionEnabled = false
            
            vc.willMove(toParent: nil)
            vc.view.removeFromSuperview()
            vc.removeFromParent()
            
            if let gestures = self.platterContainerView?.gestureRecognizers {
                gestures.forEach { self.platterContainerView?.removeGestureRecognizer($0) }
            }
            
            self.platterViewController = nil
            self.platterBottomConstraint = nil
            self.platterHeightConstraint = nil
            self.platterContainerView?.isUserInteractionEnabled = false
        }
    }
    
    private func showAddReadingPlatter() {
        guard let container = platterContainerView else { return }
        guard platterViewController == nil, addReadingPlatterViewController == nil else { return }
        
        container.isUserInteractionEnabled = true
        
        let storyboard = UIStoryboard(name: "Vital", bundle: nil)
        guard let platterVC = storyboard.instantiateViewController(withIdentifier: "AddReadingViewController") as? AddReadingViewController else {
            return
        }
        
        platterVC.onHeartRateTap = { [weak self] in
            self?.dismissAddReadingPlatter()
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                self?.presentAddReadingAlert(
                    title: "Heart Rate",
                    message: "Enter your current heart rate\nMeasure after sitting calmly for 1-2 minutes.",
                    placeholders: ["78"],
                    units: ["BPM"]
                )
            }
        }
        
        platterVC.onBloodPressureTap = { [weak self] in
            self?.dismissAddReadingPlatter()
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                self?.presentAddReadingAlert(
                    title: "Blood Pressure",
                    message: "Enter your current blood pressure\nMeasure while seated with your arm resting at heart level.",
                    placeholders: ["Systolic", "Diastolic"],
                    units: ["mmHg", "mmHg"]
                )
            }
        }
        
        platterVC.onBloodGlucoseTap = { [weak self] in
            self?.dismissAddReadingPlatter()
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                self?.presentAddReadingAlert(
                    title: "Blood Glucose",
                    message: "Enter your blood glucose level\nBest measured either fasting (8+ hours) or 2 hours post-meal.",
                    placeholders: ["98"],
                    units: ["mg/dL"]
                )
            }
        }
        
        platterVC.onBodyWeightTap = { [weak self] in
            self?.dismissAddReadingPlatter()
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                self?.presentAddReadingAlert(
                    title: "Body Weight",
                    message: "Enter your current body weight\nFor best consistency, weigh yourself at the same time every day.",
                    placeholders: ["80.6"],
                    units: ["kg"]
                )
            }
        }
        
        platterVC.view.translatesAutoresizingMaskIntoConstraints = false
        addChild(platterVC)
        container.addSubview(platterVC.view)
        platterVC.didMove(toParent: self)
        
        let panGesture = UIPanGestureRecognizer(target: self, action: #selector(handleAddReadingPlatterPan(_:)))
        platterVC.view.addGestureRecognizer(panGesture)
        
        let containerTap = UITapGestureRecognizer(target: self, action: #selector(addReadingContainerBackgroundTapped(_:)))
        containerTap.cancelsTouchesInView = false
        container.addGestureRecognizer(containerTap)
        
        self.addReadingPlatterViewController = platterVC
        
        let bottomConstraint = platterVC.view.bottomAnchor.constraint(equalTo: container.bottomAnchor, constant: 500)
        self.addReadingPlatterBottomConstraint = bottomConstraint
        
        NSLayoutConstraint.activate([
            platterVC.view.leadingAnchor.constraint(equalTo: container.leadingAnchor, constant: 5),
            platterVC.view.trailingAnchor.constraint(equalTo: container.trailingAnchor, constant: -5),
            bottomConstraint
        ])
        
        container.layoutIfNeeded()
        
        self.addReadingPlatterBottomConstraint?.constant = -5
        dimmingOverlayView?.alpha = 0
        dimmingOverlayView?.isHidden = false
        dimmingOverlayView?.isUserInteractionEnabled = true
        if let dimmingOverlayView {
            view.bringSubviewToFront(dimmingOverlayView)
        }
        view.bringSubviewToFront(container)
        
        UIView.animate(withDuration: 0.5, delay: 0, usingSpringWithDamping: 0.8, initialSpringVelocity: 0.5, options: .curveEaseOut) {
            self.dimmingOverlayView?.alpha = 0.3
            self.tabBarController?.tabBar.alpha = 0
            self.view.layoutIfNeeded()
        }
    }
    
    @objc private func dismissAddReadingPlatter() {
        guard let vc = addReadingPlatterViewController else { return }
        
        self.addReadingPlatterBottomConstraint?.constant = 500
        
        UIView.animate(withDuration: 0.3, animations: {
            self.dimmingOverlayView?.alpha = 0
            self.tabBarController?.tabBar.alpha = 1
            self.view.layoutIfNeeded()
        }) { _ in
            self.dimmingOverlayView?.isHidden = true
            self.dimmingOverlayView?.isUserInteractionEnabled = false
            
            vc.willMove(toParent: nil)
            vc.view.removeFromSuperview()
            vc.removeFromParent()
            
            if let gestures = self.platterContainerView?.gestureRecognizers {
                gestures.forEach { self.platterContainerView?.removeGestureRecognizer($0) }
            }
            
            self.addReadingPlatterViewController = nil
            self.addReadingPlatterBottomConstraint = nil
            self.platterContainerView?.isUserInteractionEnabled = false
        }
    }
    
    @objc private func addReadingContainerBackgroundTapped(_ gesture: UITapGestureRecognizer) {
        guard let platterView = addReadingPlatterViewController?.view else { return }
        let location = gesture.location(in: platterContainerView)
        if !platterView.frame.contains(location) {
            dismissAddReadingPlatter()
        }
    }
    
    @objc private func handleAddReadingPlatterPan(_ gesture: UIPanGestureRecognizer) {
        guard let view = gesture.view else { return }
        let translation = gesture.translation(in: view)
        let velocity = gesture.velocity(in: view)
        
        switch gesture.state {
        case .changed:
            if translation.y > 0 {
                self.addReadingPlatterBottomConstraint?.constant = translation.y - 5
                let progress = min(translation.y / 200, 1.0)
                self.dimmingOverlayView?.alpha = 0.3 * (1 - progress)
                self.view.layoutIfNeeded()
            }
        case .ended, .cancelled:
            if translation.y > 150 || velocity.y > 1000 {
                dismissAddReadingPlatter()
            } else {
                self.addReadingPlatterBottomConstraint?.constant = -5
                UIView.animate(withDuration: 0.3, delay: 0, usingSpringWithDamping: 0.8, initialSpringVelocity: 0.5, options: .curveEaseOut) {
                    self.dimmingOverlayView?.alpha = 0.3
                    self.view.layoutIfNeeded()
                }
            }
        default:
            break
        }
    }
    
    @objc private func containerBackgroundTapped(_ gesture: UITapGestureRecognizer) {
        guard let platterView = platterViewController?.view else { return }
        let location = gesture.location(in: platterContainerView)
        if !platterView.frame.contains(location) {
            dismissPlatter()
        }
    }
    
    @objc private func handlePlatterPan(_ gesture: UIPanGestureRecognizer) {
        guard let view = gesture.view else { return }
        let translation = gesture.translation(in: view)
        let velocity = gesture.velocity(in: view)
        
        switch gesture.state {
        case .changed:
            if translation.y > 0 {
                self.platterBottomConstraint?.constant = translation.y - 5
                let progress = min(translation.y / 200, 1.0)
                self.dimmingOverlayView?.alpha = 0.3 * (1 - progress)
                self.view.layoutIfNeeded()
            }
        case .ended, .cancelled:
            if translation.y > 150 || velocity.y > 1000 {
                dismissPlatter()
            } else {
                self.platterBottomConstraint?.constant = -5
                UIView.animate(withDuration: 0.3, delay: 0, usingSpringWithDamping: 0.8, initialSpringVelocity: 0.5, options: .curveEaseOut) {
                    self.dimmingOverlayView?.alpha = 0.3
                    self.view.layoutIfNeeded()
                }
            }
        default:
            break
        }
    }
    
    private func openCamera() {
        guard UIImagePickerController.isSourceTypeAvailable(.camera) else {
            print("Camera is not available on this device.")
            return
        }
        let picker = UIImagePickerController()
        picker.sourceType = .camera
        picker.delegate = self
        present(picker, animated: true)
    }
    
    private func openGallery() {
        var config = PHPickerConfiguration()
        config.selectionLimit = 0
        config.filter = .images
        let picker = PHPickerViewController(configuration: config)
        picker.delegate = self
        present(picker, animated: true)
    }
    
    private func openDocumentPicker() {
        let picker = UIDocumentPickerViewController(forOpeningContentTypes: [.pdf, .image, .plainText], asCopy: true)
        picker.delegate = self
        picker.allowsMultipleSelection = true
        present(picker, animated: true)
    }
    
    func picker(_ picker: PHPickerViewController, didFinishPicking results: [PHPickerResult]) {
        let group = DispatchGroup()
        var fetchedAttachments: [RecordAttachmentDraft?] = Array(repeating: nil, count: results.count)
        
        for (index, result) in results.enumerated() {
            group.enter()
            result.itemProvider.loadObject(ofClass: UIImage.self) { object, _ in
                if let image = object as? UIImage {
                    fetchedAttachments[index] = .image(image)
                }
                group.leave()
            }
        }
        
        picker.dismiss(animated: true) {
            group.notify(queue: .main) {
                let attachments = fetchedAttachments.compactMap { $0 }
                self.presentPreview(with: attachments)
            }
        }
    }
    
    func documentPicker(_ controller: UIDocumentPickerViewController, didPickDocumentsAt urls: [URL]) {
        var fetchedAttachments: [RecordAttachmentDraft] = []
        
        for url in urls {
            if url.pathExtension.lowercased() == "pdf" {
                if let pdfImage = pdfToImage(url: url) {
                    fetchedAttachments.append(.pdf(url: url, thumbnail: pdfImage))
                }
            } else if let data = try? Data(contentsOf: url), let image = UIImage(data: data) {
                fetchedAttachments.append(.image(image, fileURL: url))
            }
        }
        
        presentPreview(with: fetchedAttachments)
    }
    
    func imagePickerController(_ picker: UIImagePickerController, didFinishPickingMediaWithInfo info: [UIImagePickerController.InfoKey : Any]) {
        if let image = info[.originalImage] as? UIImage {
            picker.dismiss(animated: true) {
                self.presentPreview(with: [.image(image)])
            }
        } else {
            picker.dismiss(animated: true)
        }
    }
    
    func imagePickerControllerDidCancel(_ picker: UIImagePickerController) {
        picker.dismiss(animated: true)
    }
    
    private func presentAddReadingAlert(title: String, message: String, placeholders: [String], units: [String]) {
        let alertController = UIAlertController(title: title, message: message, preferredStyle: .alert)
        
        for (index, placeholder) in placeholders.enumerated() {
            alertController.addTextField { textField in
                textField.placeholder = placeholder
                if placeholder.contains("Systolic") || placeholder.contains("Diastolic") || title.contains("Heart Rate") {
                    textField.keyboardType = .numberPad
                } else {
                    textField.keyboardType = .decimalPad
                }
                
                if index < units.count {
                    let unitLabel = UILabel()
                    unitLabel.text = units[index]
                    unitLabel.font = UIFont.systemFont(ofSize: 14, weight: .regular)
                    unitLabel.textColor = .black
                    unitLabel.sizeToFit()
                    
                    let paddingView = UIView(frame: CGRect(x: 0, y: 0, width: unitLabel.frame.width + 10, height: unitLabel.frame.height))
                    unitLabel.center = CGPoint(x: paddingView.frame.width / 2 - 5, y: paddingView.frame.height / 2)
                    paddingView.addSubview(unitLabel)
                    
                    textField.rightView = paddingView
                    textField.rightViewMode = .always
                }
            }
        }
        
        alertController.addTextField { textField in
            let formatter = DateFormatter()
            formatter.dateFormat = "dd-MM-yyyy"
            textField.text = formatter.string(from: Date())
            
            let iconImage = UIImage(systemName: "calendar")
            let iconView = UIImageView(image: iconImage)
            iconView.tintColor = .black
            iconView.contentMode = .scaleAspectFit
            iconView.frame = CGRect(x: 0, y: 0, width: 20, height: 20)
            
            let paddingView = UIView(frame: CGRect(x: 0, y: 0, width: 30, height: 20))
            paddingView.addSubview(iconView)
            paddingView.isUserInteractionEnabled = false
            iconView.isUserInteractionEnabled = false
            
            textField.rightView = paddingView
            textField.rightViewMode = .always
            
            let datePicker = UIDatePicker()
            datePicker.datePickerMode = .date
            datePicker.maximumDate = Date()
            if #available(iOS 14.0, *) {
                datePicker.preferredDatePickerStyle = .wheels
            }
            
            datePicker.addAction(UIAction { _ in
                textField.text = formatter.string(from: datePicker.date)
            }, for: .valueChanged)
            
            textField.inputView = datePicker
        }
        
        let cancelAction = UIAlertAction(title: "Cancel", style: .cancel)
        let addAction = UIAlertAction(title: "Add Reading", style: .default) { _ in
            var values = [String]()
            for index in 0..<placeholders.count {
                values.append(alertController.textFields?[index].text ?? "")
            }
            let dateText = alertController.textFields?.last?.text ?? ""
            print("Added \(title): \(values.joined(separator: " / ")) on \(dateText)")
        }
        
        alertController.addAction(cancelAction)
        alertController.addAction(addAction)
        
        present(alertController, animated: true)
    }
    
    private func processPlatterAssets(_ assets: [PHAsset]) {
        let manager = PHImageManager.default()
        let options = PHImageRequestOptions()
        options.isSynchronous = false
        options.deliveryMode = .highQualityFormat
        options.isNetworkAccessAllowed = true
        
        var fetchedAttachments: [RecordAttachmentDraft?] = Array(repeating: nil, count: assets.count)
        let group = DispatchGroup()
        
        for (index, asset) in assets.enumerated() {
            group.enter()
            let targetSize = CGSize(width: 1500, height: 1500)
            manager.requestImage(for: asset, targetSize: targetSize, contentMode: .aspectFit, options: options) { image, _ in
                if let image {
                    fetchedAttachments[index] = .image(image)
                }
                group.leave()
            }
        }
        
        group.notify(queue: .main) {
            let attachments = fetchedAttachments.compactMap { $0 }
            self.presentPreview(with: attachments)
        }
    }
    
    private func presentPreview(with attachments: [RecordAttachmentDraft]) {
        guard !attachments.isEmpty else { return }
        
        let storyboard = UIStoryboard(name: "Main", bundle: nil)
        guard let previewVC = storyboard.instantiateViewController(withIdentifier: "PreviewViewController") as? PreviewViewController else {
            return
        }
        
        previewVC.attachments = attachments
        navigationController?.pushViewController(previewVC, animated: true)
    }
    
    private func pdfToImage(url: URL) -> UIImage? {
        guard let document = CGPDFDocument(url as CFURL),
              let page = document.page(at: 1) else { return nil }
        
        let pageRect = page.getBoxRect(.mediaBox)
        let renderer = UIGraphicsImageRenderer(size: pageRect.size)
        
        return renderer.image { context in
            UIColor.white.set()
            context.fill(pageRect)
            
            context.cgContext.translateBy(x: 0.0, y: pageRect.size.height)
            context.cgContext.scaleBy(x: 1.0, y: -1.0)
            context.cgContext.drawPDFPage(page)
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
                
                let isMultiple = (self?.pendingConsultations.count ?? 0) > 1
                let groupSize = NSCollectionLayoutSize(
                    widthDimension: .fractionalWidth(isMultiple ? 0.85 : 1.0),
                    heightDimension: .estimated(180)
                )
                let group = NSCollectionLayoutGroup.horizontal(layoutSize: groupSize, subitems: [item])
                
                let section = NSCollectionLayoutSection(group: group)
                section.contentInsets = NSDirectionalEdgeInsets(top: 2, leading: 16, bottom: 4, trailing: 16)
                section.contentInsetsReference = .safeArea
                section.interGroupSpacing = 16
                section.orthogonalScrollingBehavior = isMultiple ? .groupPaging : .none
                
                let header = NSCollectionLayoutBoundarySupplementaryItem(
                    layoutSize: NSCollectionLayoutSize(widthDimension: .fractionalWidth(1.0), heightDimension: .absolute(40)),
                    elementKind: UICollectionView.elementKindSectionHeader,
                    alignment: .top
                )
                section.boundarySupplementaryItems = [header]
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
                section.contentInsets = NSDirectionalEdgeInsets(top: 2, leading: 16, bottom: 0, trailing: 16)

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
                section.contentInsets = NSDirectionalEdgeInsets(top: 2, leading: 16, bottom: 4, trailing: 16)

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
                    top: 2, leading: 16, bottom: 16, trailing: 16)
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
