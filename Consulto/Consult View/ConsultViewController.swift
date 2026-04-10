import SwiftUI
import UIKit

class ConsultViewController: UIViewController,
    UINavigationControllerDelegate,
    UICollectionViewDataSource,
    UICollectionViewDelegate
{

    @IBOutlet weak var headerActionsContainerView: UIView!
    @IBOutlet weak var consultCollectionView: UICollectionView!
    @IBOutlet weak var blurEffectView: UIVisualEffectView!

    // MARK: - Data Source
    private var consultSessions: [ConsultSession] = []
    private var allConsultSessions: [ConsultSession] = []
    
    // For Filters
    var currentDoctorFilters: Set<String> = []
    var currentDateFilter: (start: Date, end: Date)?
    
    required init?(coder: NSCoder) {
        super.init(coder: coder)
        print("[ConsultVC] init(coder:) called")

        tabBarItem = UITabBarItem(
            title: "Prepare",
            image: UIImage(named: "Consult"),
            selectedImage: UIImage(named: "Consult")
        )
    }

    override func viewDidLoad() {
        super.viewDidLoad()
        self.view.tintAdjustmentMode = .normal

        // Load persisted sessions
        allConsultSessions = ConsultSessionStore.shared.loadSessions()
        applyFilters()

        navigationController?.delegate = self
        consultCollectionView.delegate = self
        consultCollectionView.dataSource = self
        consultCollectionView.showsVerticalScrollIndicator = false
        print("[ConsultVC] Collection view dataSource and delegate set")
        consultCollectionView.collectionViewLayout = createLayout()

        consultCollectionView.register(
            UINib(nibName: "consultCollectionViewCell", bundle: nil),
            forCellWithReuseIdentifier: "consult_cell"
        )

        setupHeaderActions()

        NotificationCenter.default.addObserver(
            self, selector: #selector(handleSessionUpdate(_:)),
            name: NSNotification.Name("ConsultSessionUpdated"), object: nil)
        
        NotificationCenter.default.addObserver(
            self, selector: #selector(handleNewSession(_:)),
            name: NSNotification.Name("NewConsultSessionCreated"), object: nil)
    }

    @objc private func handleSessionUpdate(_ notification: Notification) {
        if let userInfo = notification.userInfo,
            let updatedSession = userInfo["session"] as? ConsultSession
        {
            if let index = allConsultSessions.firstIndex(where: { $0.id == updatedSession.id }) {
                allConsultSessions[index] = updatedSession
                ConsultSessionStore.shared.updateSession(updatedSession)
                applyFilters()
            }
        }
    }
    
    @objc private func handleNewSession(_ notification: Notification) {
        if let userInfo = notification.userInfo,
           let newSession = userInfo["session"] as? ConsultSession
        {
            allConsultSessions.insert(newSession, at: 0)
            ConsultSessionStore.shared.addSession(newSession)
            applyFilters()
        }
    }
    
    override func prepare(for segue: UIStoryboardSegue, sender: Any?) {
          
          if segue.identifier == "prepare_consultation" {
              let navVC = segue.destination as! UINavigationController
              let prepareVC = navVC.topViewController as! PrepareConsultationTableViewController
          }
      }

    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
        let hasNav = (navigationController != nil)
        print("[ConsultVC] viewDidAppear. navigationController present? \(hasNav)")
    }

    func collectionView(_ collectionView: UICollectionView, didSelectItemAt indexPath: IndexPath) {
        print("[ConsultVC] didSelectItemAt: \(indexPath)")

        let storyboardB = UIStoryboard(name: "ConsultDetailView", bundle: nil)

        guard
            let detailVC = storyboardB.instantiateViewController(
                withIdentifier: "ConsultDetailedView"
            ) as? ConsultDetailedViewController
        else {
            assertionFailure("Could not cast to ConsultDetailedViewController")
            return
        }

        let selectedSession = consultSessions[indexPath.item]
        detailVC.consultSession = selectedSession

        print("[ConsultVC] Passing session: \(selectedSession.title)")

        navigationController?.pushViewController(detailVC, animated: true)
    }

    func applyFilters() {
        var filtered = allConsultSessions
        
        if !currentDoctorFilters.isEmpty {
            filtered = filtered.filter { currentDoctorFilters.contains($0.doctorName) }
        }
        
        if let dates = currentDateFilter {
            let calendar = Calendar.current
            let start = calendar.startOfDay(for: dates.start)
            let end = calendar.date(byAdding: .day, value: 1, to: calendar.startOfDay(for: dates.end))!
            
            filtered = filtered.filter { session in
                let targetDate = session.date
                return targetDate >= start && targetDate < end
            }
        }
        
        consultSessions = filtered
        consultCollectionView.reloadData()
        setupHeaderActions()
    }

    func setupHeaderActions() {
        guard let container = headerActionsContainerView else { return }
        print("[ConsultVC] Setting up header actions")
        
        container.subviews.forEach { $0.removeFromSuperview() }
        container.backgroundColor = .clear

        let isDateSelected = currentDateFilter != nil
        var dateTitle = "Filter by Date"
        if let dates = currentDateFilter {
            let formatter = DateFormatter()
            formatter.dateStyle = .short
            if dates.start == dates.end {
                dateTitle = formatter.string(from: dates.start)
            } else {
                dateTitle = "\(formatter.string(from: dates.start)) - \(formatter.string(from: dates.end))"
            }
        }
        
        let dateAction = UIAction(title: dateTitle, image: UIImage(systemName: "calendar"), state: isDateSelected ? .on : .off) { [weak self] _ in
            if isDateSelected {
                self?.currentDateFilter = nil
                self?.applyFilters()
            } else {
                self?.openDatePicker()
            }
        }
        
        let doctorAction = UIAction(title: "Filter by Doctor", image: UIImage(systemName: "stethoscope"), state: currentDoctorFilters.isEmpty ? .off : .on) { [weak self] _ in
            self?.openDoctorSelection()
        }
        
        let clearFiltersAction = UIAction(title: "Remove all filters", image: UIImage(systemName: "xmark.circle"), attributes: .destructive) { [weak self] _ in
            self?.currentDoctorFilters.removeAll()
            self?.currentDateFilter = nil
            self?.applyFilters()
        }
        
        var menuChildren: [UIMenuElement] = [dateAction, doctorAction]
        if !currentDoctorFilters.isEmpty || currentDateFilter != nil {
            menuChildren.insert(clearFiltersAction, at: 0)
        }
        
        let menu = UIMenu(title: "", children: menuChildren)

        let swiftUIView = ConsultHeaderActionsView(
            onAddAction: { [weak self] in
                print("Add Consult Tapped")
                self?.performSegue(withIdentifier: "prepare_consultation", sender: nil)
            },
            filterMenu: menu
        )

        let hostingController = UIHostingController(rootView: swiftUIView)
        hostingController.view.backgroundColor = .clear
        hostingController.view.translatesAutoresizingMaskIntoConstraints = false

        addChild(hostingController)
        container.addSubview(hostingController.view)

        NSLayoutConstraint.activate([
            hostingController.view.topAnchor.constraint(equalTo: container.topAnchor),
            hostingController.view.bottomAnchor.constraint(equalTo: container.bottomAnchor),
            hostingController.view.leadingAnchor.constraint(equalTo: container.leadingAnchor),
            hostingController.view.trailingAnchor.constraint(equalTo: container.trailingAnchor),
        ])

        hostingController.didMove(toParent: self)
    }

    func openDatePicker() {
        let dateVC = DateFilterViewController()
        dateVC.onFilterSingleDate = { [weak self] selectedDate in
            self?.currentDateFilter = (start: selectedDate, end: selectedDate)
            self?.applyFilters()
        }
        dateVC.onFilterDateRange = { [weak self] start, end in
            self?.currentDateFilter = (start: min(start, end), end: max(start, end))
            self?.applyFilters()
        }
        
        dateVC.modalPresentationStyle = .popover
        dateVC.preferredContentSize = CGSize(width: 320, height: 420)
        
        if let popover = dateVC.popoverPresentationController {
            popover.sourceView = self.headerActionsContainerView
            popover.sourceRect = self.headerActionsContainerView?.bounds ?? .zero
            popover.delegate = self
            popover.permittedArrowDirections = .up
        }
        present(dateVC, animated: true)
    }
    
    func openDoctorSelection() {
        let doctorNames = Array(Set(allConsultSessions.map { $0.doctorName })).sorted()
        
        let doctorVC = DoctorSelectionViewController()
        doctorVC.doctorNames = doctorNames
        doctorVC.selectedDoctors = currentDoctorFilters
        doctorVC.onDoctorSelectionChanged = { [weak self] doctors in
            self?.currentDoctorFilters = doctors
            self?.applyFilters()
        }
        
        doctorVC.modalPresentationStyle = .popover
        let popoverHeight = min(doctorNames.count * 44 + 40, 350)
        doctorVC.preferredContentSize = CGSize(width: 250, height: popoverHeight)
        
        if let popover = doctorVC.popoverPresentationController {
            popover.sourceView = self.headerActionsContainerView
            popover.sourceRect = self.headerActionsContainerView?.bounds ?? .zero
            popover.delegate = self
            popover.permittedArrowDirections = .up
        }
        present(doctorVC, animated: true)
    }

    override func viewDidLayoutSubviews() {
        super.viewDidLayoutSubviews()
        print("[ConsultVC] viewDidLayoutSubviews")
        if blurEffectView != nil {
            setupBlurGradientMask()
        }
    }

    func setupBlurGradientMask() {
        guard let blurEffectView = blurEffectView else { return }
        print("[ConsultVC] setupBlurGradientMask with bounds: \(blurEffectView.bounds)")
        let gradientMask = CAGradientLayer()
        gradientMask.frame = blurEffectView.bounds
        gradientMask.colors = [
            UIColor.black.cgColor,
            UIColor.black.cgColor,
            UIColor.clear.cgColor,
        ]
        gradientMask.locations = [0.0, 0.8, 1.0]
        blurEffectView.layer.mask = gradientMask

        if let existingOverlay = blurEffectView.layer.sublayers?.first(where: {
            $0.name == "SolidOverlay"
        }) {
            existingOverlay.frame = blurEffectView.bounds
        } else {
            let overlayLayer = CALayer()
            overlayLayer.name = "SolidOverlay"
            overlayLayer.frame = blurEffectView.bounds
            overlayLayer.backgroundColor = UIColor(hex: "#f5f5f5").withAlphaComponent(0.5).cgColor

            let overlayMask = CAGradientLayer()
            overlayMask.frame = overlayLayer.bounds
            overlayMask.colors = gradientMask.colors
            overlayMask.locations = gradientMask.locations
            overlayLayer.mask = overlayMask

            blurEffectView.layer.addSublayer(overlayLayer)
        }
    }

    // MARK: - Navigation Bar
    func navigationController(
        _ navigationController: UINavigationController,
        willShow viewController: UIViewController,
        animated: Bool
    ) {
        print(
            "[ConsultVC] willShow: \(type(of: viewController)) hidden? \(viewController === self)")
        let isConsultScreen = (viewController === self)
        navigationController.setNavigationBarHidden(isConsultScreen, animated: animated)
    }

    // MARK: - UICollectionView DataSource
    func collectionView(
        _ collectionView: UICollectionView,
        numberOfItemsInSection section: Int
    ) -> Int {
        print("[ConsultVC] numberOfItemsInSection=\(consultSessions.count)")
        return consultSessions.count
    }

    func collectionView(
        _ collectionView: UICollectionView,
        cellForItemAt indexPath: IndexPath
    ) -> UICollectionViewCell {
        print("[ConsultVC] cellForItemAt: \(indexPath)")

        let cell =
            collectionView.dequeueReusableCell(
                withReuseIdentifier: "consult_cell",
                for: indexPath
            ) as! consultCollectionViewCell

        cell.configure(with: consultSessions[indexPath.item])
        return cell
    }
    
    // Context Menu to delete the particular prepare card and mark the consultation status.(220 to 254)
    
    func collectionView(_ collectionView: UICollectionView, contextMenuConfigurationForItemAt indexPath: IndexPath, point: CGPoint) -> UIContextMenuConfiguration? {
        let session = consultSessions[indexPath.item]
        
        let identifier = NSNumber(value: indexPath.item)
        return UIContextMenuConfiguration(identifier: identifier, previewProvider: nil) { [weak self] _ in
            let isPending = session.status == .pending
            let toggleTitle = isPending ? "Mark as Completed" : "Mark as Pending"
            let toggleIcon = isPending ? "checkmark.circle" : "arrow.uturn.backward.circle"
            
            let toggleStatusAction = UIAction(title: toggleTitle, image: UIImage(systemName: toggleIcon)) { _ in
                self?.consultSessions[indexPath.item].status = isPending ? .completed : .pending
                if let updated = self?.consultSessions[indexPath.item] {
                    ConsultSessionStore.shared.updateSession(updated)
                }
                self?.consultCollectionView.reloadItems(at: [indexPath])
            }
            
            let deleteAction = UIAction(title: "Delete", image: UIImage(systemName: "trash"), attributes: .destructive) { [weak self] _ in
                self?.presentDeleteConfirmation(for: session)
            }
            
            return UIMenu(title: "", children: [toggleStatusAction, deleteAction])
        }
    }
    
    private func presentDeleteConfirmation(for session: ConsultSession) {
        let alert = UIAlertController(
            title: "Delete Consultation",
            message: "Are you sure you want to delete this consultation details?",
            preferredStyle: .alert
        )

        alert.addAction(UIAlertAction(title: "Cancel", style: .cancel))
        alert.addAction(UIAlertAction(title: "Delete", style: .destructive) { [weak self] _ in
            self?.deleteSession(session)
        })

        present(alert, animated: true)
    }

    private func deleteSession(_ session: ConsultSession) {
        if let index = allConsultSessions.firstIndex(where: { $0.id == session.id }) {
            allConsultSessions.remove(at: index)
            ConsultSessionStore.shared.deleteSession(id: session.id)
            applyFilters()
        }
    }
    
    func collectionView(_ collectionView: UICollectionView, previewForHighlightingContextMenuWithConfiguration configuration: UIContextMenuConfiguration) -> UITargetedPreview? {
        guard let item = configuration.identifier as? NSNumber else { return nil }
        let indexPath = IndexPath(item: item.intValue, section: 0)
        
        guard let cell = collectionView.cellForItem(at: indexPath) else { return nil }
        
        let parameters = UIPreviewParameters()
        parameters.backgroundColor = .clear
        parameters.visiblePath = UIBezierPath(roundedRect: cell.bounds, cornerRadius: 16)
        
        return UITargetedPreview(view: cell, parameters: parameters)
    }
    
    // MARK: - Compositional Layout
    private func createLayout() -> UICollectionViewLayout {

        let itemSize = NSCollectionLayoutSize(
            widthDimension: .fractionalWidth(1.0),
            heightDimension: .absolute(120)
        )

        let item = NSCollectionLayoutItem(layoutSize: itemSize)

        let groupSize = NSCollectionLayoutSize(
            widthDimension: .fractionalWidth(1.0),
            heightDimension: .absolute(120)
        )

        let group = NSCollectionLayoutGroup.vertical(
            layoutSize: groupSize,
            subitems: [item]
        )

        let section = NSCollectionLayoutSection(group: group)
        section.contentInsets = NSDirectionalEdgeInsets(
            top: 70,
            leading: 16,
            bottom: 20,
            trailing: 16
        )

        section.interGroupSpacing = 16

        return UICollectionViewCompositionalLayout(section: section)
    }
}

extension ConsultViewController: UIPopoverPresentationControllerDelegate {
    func adaptivePresentationStyle(for controller: UIPresentationController) -> UIModalPresentationStyle {
        return .none
    }
}
