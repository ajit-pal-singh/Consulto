import UIKit
import SwiftUI
import Combine
import PhotosUI
import UniformTypeIdentifiers

class RecordsViewController: UIViewController, UINavigationControllerDelegate, PHPickerViewControllerDelegate, UIDocumentPickerDelegate, UIImagePickerControllerDelegate {

    @IBOutlet weak var recordsCollectionView: UICollectionView!
        
    @IBOutlet weak var chipsContainerView: UIView!

    @IBOutlet weak var blurEffectView: UIVisualEffectView!
    @IBOutlet weak var headerActionsContainerView: UIView! 
    

    var records: [HealthRecord] = []
    private var allRecords: [HealthRecord] = []
    
    // Selection Mode
    var selectionMode: Bool = false
    var alreadySelectedRecordIDs: Set<UUID> = []
    var selectedRecords: [HealthRecord] = []
    var didSelectRecords: (([HealthRecord]) -> Void)?
    
    @IBOutlet weak var platterContainerView: UIView!

    @IBOutlet weak var dimmingOverlayView: UIView!

    // Platter Properties
    var platterViewController: AttachmentPlatterViewController?
    var platterBottomConstraint: NSLayoutConstraint?
    var platterHeightConstraint: NSLayoutConstraint?
    
    // Segue Identifier
    let detailSegueIdentifier = "Card-Details"
    
    // View Model for Filters
    var filterViewModel = FilterViewModel()
    var cancellables = Set<AnyCancellable>()
    
    override func viewDidLoad() {
        super.viewDidLoad()
        navigationController?.delegate = self
        
        platterContainerView?.isUserInteractionEnabled = false
        
        // Dimming overlay: hidden and non-interactive until the platter is shown
        dimmingOverlayView?.alpha = 0
        dimmingOverlayView?.isHidden = true
        dimmingOverlayView?.isUserInteractionEnabled = false
        
        // Prevent background elements from turning gray/black when popover is presented
        self.view.tintAdjustmentMode = .normal
                setupCollectionView()
        setupChipsView()
        setupHeaderActions()
        
        filterViewModel.$selectedFilter
            .receive(on: RunLoop.main)
            .sink { [weak self] newFilter in
                print("Filter Changed to: \(newFilter)")
                self?.filterRecords(by: newFilter)
            }
            .store(in: &cancellables)
        
        if selectionMode {
            self.title = "Select Records"
            navigationItem.rightBarButtonItem = UIBarButtonItem(
                title: "Done", style: .done, target: self, action: #selector(doneSelectingTapped))
            navigationItem.leftBarButtonItem = UIBarButtonItem(
                title: "Cancel", style: .plain, target: self, action: #selector(cancelSelectionTapped))
            navigationController?.setNavigationBarHidden(false, animated: false)
            
            headerActionsContainerView?.superview?.isHidden = true
            blurEffectView?.isHidden = true
        }
        

    }

    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        loadData()
    }
    
    @objc private func doneSelectingTapped() {
        didSelectRecords?(selectedRecords)
        dismiss(animated: true)
    }
    
    @objc private func cancelSelectionTapped() {
        dismiss(animated: true)
    }
    
    var currentDoctorFilters: Set<String> = []
    var currentFacilityFilters: Set<String> = []
    var currentDateFilter: (start: Date, end: Date)?

    func setupHeaderActions() {
        guard let container = headerActionsContainerView else { return }
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
        
        let facilityAction = UIAction(title: "Filter by Health Facility", image: UIImage(systemName: "building.2.fill"), state: currentFacilityFilters.isEmpty ? .off : .on) { [weak self] _ in
            self?.openFacilitySelection()
        }
        
        let clearFiltersAction = UIAction(title: "Remove all filters", image: UIImage(systemName: "xmark.circle"), attributes: .destructive) { [weak self] _ in
            self?.currentDoctorFilters.removeAll()
            self?.currentFacilityFilters.removeAll()
            self?.currentDateFilter = nil
            self?.applyFilters()
        }
        
        var menuChildren: [UIMenuElement] = [dateAction, doctorAction, facilityAction]
        if !currentDoctorFilters.isEmpty || !currentFacilityFilters.isEmpty || currentDateFilter != nil {
            menuChildren.insert(clearFiltersAction, at: 0)
        }
        
        let menu = UIMenu(title: "", children: menuChildren)
        
        let swiftUIView = HeaderActionsView(
            onAddAction: { [weak self] in
                self?.showAttachmentPlatter()
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
            hostingController.view.trailingAnchor.constraint(equalTo: container.trailingAnchor)
        ])
        
        hostingController.didMove(toParent: self)
    }

    // MARK: - Sticky Chips View Setup
    func setupChipsView() {
        guard let container = chipsContainerView else { return }
        
        container.subviews.forEach { $0.removeFromSuperview() }
        container.backgroundColor = .clear 
        container.clipsToBounds = false
        
        // Create SwiftUI View with ViewModel
        let swiftUIView = ChipsView(viewModel: filterViewModel)
        let hostingController = UIHostingController(rootView: swiftUIView)
        hostingController.view.backgroundColor = .clear
        hostingController.view.clipsToBounds = false
        
        // Add as Child ViewController
        addChild(hostingController)
        container.addSubview(hostingController.view)
        
        // Constraints
        hostingController.view.translatesAutoresizingMaskIntoConstraints = false
        NSLayoutConstraint.activate([
            hostingController.view.topAnchor.constraint(equalTo: container.topAnchor),
            hostingController.view.bottomAnchor.constraint(equalTo: container.bottomAnchor),
            hostingController.view.leadingAnchor.constraint(equalTo: container.leadingAnchor),
            hostingController.view.trailingAnchor.constraint(equalTo: container.trailingAnchor)
        ])
        
        hostingController.didMove(toParent: self)
    }
    
    func setupCollectionView() {
        recordsCollectionView.delegate = self
        recordsCollectionView.dataSource = self
        
        // Register XIBs
        let nib = UINib(nibName: "RecordCardCollectionViewCell", bundle: nil)
        recordsCollectionView.register(nib, forCellWithReuseIdentifier: "RecordCardCollectionViewCell")
        
        recordsCollectionView.backgroundColor = .clear
        if let layout = recordsCollectionView.collectionViewLayout as? UICollectionViewFlowLayout {
            layout.estimatedItemSize = .zero
            layout.minimumInteritemSpacing = 16
            layout.minimumLineSpacing = 16
        }
    }
    
    func loadData() {
        do {
            allRecords = try HealthRecordStore.shared.loadRecords()
        } catch {
            allRecords = []
            print("Failed to load records: \(error)")
        }
        setupHeaderActions()
        filterRecords(by: filterViewModel.selectedFilter)
    }
    
    func filterRecords(by filter: String) {
        applyFilters()
    }
    
    func applyFilters() {
        var filtered = allRecords
        let chipFilter = filterViewModel.selectedFilter
        
        if chipFilter != "All" {
            filtered = filtered.filter { record in
                switch chipFilter {
                case "Prescription": return record.recordType == .prescription
                case "Lab Report": return record.recordType == .labReport
                case "Discharge": return record.recordType == .dischargeSummary
                case "Scan": return record.recordType == .scan
                case "Other": return record.recordType == .other
                default: return true
                }
            }
        }
        
        if !currentDoctorFilters.isEmpty {
            filtered = filtered.filter { currentDoctorFilters.contains($0.title) }
        }
        
        if !currentFacilityFilters.isEmpty {
            filtered = filtered.filter { record in
                guard let facility = record.healthFacilityName else { return false }
                return currentFacilityFilters.contains(facility)
            }
        }
        
        if let dates = currentDateFilter {
            let calendar = Calendar.current
            let start = calendar.startOfDay(for: dates.start)
            let end = calendar.date(byAdding: .day, value: 1, to: calendar.startOfDay(for: dates.end))!
            
            filtered = filtered.filter { record in
                let targetDate = record.documentDate ?? record.dateAdded
                return targetDate >= start && targetDate < end
            }
        }
        
        records = filtered
        recordsCollectionView.reloadData()
        setupHeaderActions() // This re-renders the checkmarks correctly
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
            // Removed passthroughViews so the background is disabled and tap-to-dismiss works properly.
        }
        present(dateVC, animated: true)
    }
    
    func openDoctorSelection() {
        let doctorNames = Array(Set(allRecords.compactMap {
            $0.title.lowercased().hasPrefix("dr") ? $0.title : nil
        })).sorted()
        
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
            // Removed passthroughViews so the background is disabled and tap-to-dismiss works properly.
        }
        present(doctorVC, animated: true)
    }

    func openFacilitySelection() {
        let facilityNames = Array(Set(allRecords.compactMap { $0.healthFacilityName })).filter { !$0.trimmingCharacters(in: .whitespaces).isEmpty }.sorted()
        
        let facilityVC = FacilitySelectionViewController()
        facilityVC.facilityNames = facilityNames
        facilityVC.selectedFacilities = currentFacilityFilters
        facilityVC.onFacilitySelectionChanged = { [weak self] facilities in
            self?.currentFacilityFilters = facilities
            self?.applyFilters()
        }
        
        facilityVC.modalPresentationStyle = .popover
        let popoverHeight = min(max(facilityNames.count * 44 + 40, 100), 350)
        facilityVC.preferredContentSize = CGSize(width: 250, height: CGFloat(popoverHeight))
        
        if let popover = facilityVC.popoverPresentationController {
            popover.sourceView = self.headerActionsContainerView
            popover.sourceRect = self.headerActionsContainerView?.bounds ?? .zero
            popover.delegate = self
            popover.permittedArrowDirections = .up
        }
        present(facilityVC, animated: true)
    }

    private func presentDeleteConfirmation(for record: HealthRecord) {
        let alert = UIAlertController(
            title: "Delete Record",
            message: "Are you sure you want to delete this record?",
            preferredStyle: .alert
        )

        alert.addAction(UIAlertAction(title: "Cancel", style: .cancel))
        alert.addAction(UIAlertAction(title: "Delete", style: .destructive) { [weak self] _ in
            self?.deleteRecord(record)
        })

        present(alert, animated: true)
    }

    private func deleteRecord(_ record: HealthRecord) {
        do {
            try HealthRecordStore.shared.deleteRecord(id: record.id)
            allRecords.removeAll { $0.id == record.id }
            selectedRecords.removeAll { $0.id == record.id }
            filterRecords(by: filterViewModel.selectedFilter)
        } catch {
            let alert = UIAlertController(
                title: "Unable to Delete",
                message: "Please try again.",
                preferredStyle: .alert
            )
            alert.addAction(UIAlertAction(title: "OK", style: .default))
            present(alert, animated: true)
        }
    }

    private func indexPath(forContextMenuConfiguration configuration: UIContextMenuConfiguration) -> IndexPath? {
        guard let identifier = configuration.identifier as? NSUUID else { return nil }
        let recordID = identifier as UUID
        guard let itemIndex = records.firstIndex(where: { $0.id == recordID }) else { return nil }
        return IndexPath(item: itemIndex, section: 0)
    }

    private func targetedPreview(for configuration: UIContextMenuConfiguration) -> UITargetedPreview? {
        guard let indexPath = indexPath(forContextMenuConfiguration: configuration),
              let cell = recordsCollectionView.cellForItem(at: indexPath) as? RecordCardCollectionViewCell else {
            return nil
        }

        let parameters = UIPreviewParameters()
        parameters.backgroundColor = .clear
        parameters.visiblePath = UIBezierPath(roundedRect: cell.contentView.bounds, cornerRadius: 12)
        return UITargetedPreview(view: cell.contentView, parameters: parameters)
    }
    
    // Navigation Handler
    func navigationController(_ navigationController: UINavigationController, willShow viewController: UIViewController, animated: Bool) {
        if selectionMode { return }
        let isRecordsScreen = (viewController === self)
        navigationController.setNavigationBarHidden(isRecordsScreen, animated: animated)
    }
    
    // Gradient Generation
    override func viewDidLayoutSubviews() {
        super.viewDidLayoutSubviews()
        
        if blurEffectView != nil {
           setupBlurGradientMask()
        }
    }
    
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
            overlayLayer.backgroundColor = UIColor(hex: "#f5f5f5").withAlphaComponent(0.5).cgColor
            
            let overlayMask = CAGradientLayer()
            overlayMask.frame = overlayLayer.bounds
            overlayMask.colors = gradientMask.colors
            overlayMask.locations = gradientMask.locations
            overlayLayer.mask = overlayMask
            
            blurEffectView.layer.addSublayer(overlayLayer)
        }
    }
    
    // MARK: - Navigation
    override func prepare(for segue: UIStoryboardSegue, sender: Any?) {
        if segue.identifier == detailSegueIdentifier,
           let destinationVC = segue.destination as? RecordDetailedViewController,
           let record = sender as? HealthRecord {
            destinationVC.record = record
        } else if segue.identifier == "ShowPreview",
           let destinationVC = segue.destination as? PreviewViewController {
            if let attachments = sender as? [RecordAttachmentDraft] {
                destinationVC.attachments = attachments
            } else if let images = sender as? [UIImage] {
                destinationVC.images = images
            }
        }
    }
    
    // MARK: - Attachment Pickers
    func openCamera() {
        guard UIImagePickerController.isSourceTypeAvailable(.camera) else {
            print("Camera is not available on this device.")
            return
        }
        let picker = UIImagePickerController()
        picker.sourceType = .camera
        picker.delegate = self
        present(picker, animated: true)
    }
    
    func openGallery() {
        var config = PHPickerConfiguration()
        config.selectionLimit = 0 
        config.filter = .images
        let picker = PHPickerViewController(configuration: config)
        picker.delegate = self
        present(picker, animated: true)
    }
    
    func openDocumentPicker() {
        let picker = UIDocumentPickerViewController(forOpeningContentTypes: [.pdf, .image, .plainText], asCopy: true)
        picker.delegate = self
        picker.allowsMultipleSelection = true
        present(picker, animated: true)
    }
    
    // MARK: - Picker Delegates
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
                if !attachments.isEmpty {
                    self.performSegue(withIdentifier: "ShowPreview", sender: attachments)
                }
            }
        }
    }
    
    func documentPicker(_ controller: UIDocumentPickerViewController, didPickDocumentsAt urls: [URL]) {
        var fetchedAttachments: [RecordAttachmentDraft] = []
        for url in urls {
            // Since we initialized UIDocumentPickerViewController with `asCopy: true`,
            // iOS creates a copy in our app's tmp directory. We do NOT need security-scoped access!
            
            if url.pathExtension.lowercased() == "pdf" {
                if let pdfImage = pdfToImage(url: url) {
                    fetchedAttachments.append(.pdf(url: url, thumbnail: pdfImage))
                }
            } else if let data = try? Data(contentsOf: url), let img = UIImage(data: data) {
                 fetchedAttachments.append(.image(img, fileURL: url))
            }
        }
        
        if !fetchedAttachments.isEmpty {
            self.performSegue(withIdentifier: "ShowPreview", sender: fetchedAttachments)
        }
    }
    
    func imagePickerController(_ picker: UIImagePickerController, didFinishPickingMediaWithInfo info: [UIImagePickerController.InfoKey : Any]) {
        if let image = info[.originalImage] as? UIImage {
            picker.dismiss(animated: true) {
                self.performSegue(withIdentifier: "ShowPreview", sender: [RecordAttachmentDraft.image(image)])
            }
        } else {
            picker.dismiss(animated: true)
        }
    }
    
    // MARK: - Image Processing Helpers
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
            // We request a large enough size for preview.
            // Using a specific target size (e.g. 1500x1500px) is typically safer/faster than MaximumSize
            let targetSize = CGSize(width: 1500, height: 1500)
            manager.requestImage(for: asset, targetSize: targetSize, contentMode: .aspectFit, options: options) { image, _ in
                if let img = image {
                    fetchedAttachments[index] = .image(img)
                }
                group.leave()
            }
        }
        
        group.notify(queue: .main) {
            let attachments = fetchedAttachments.compactMap { $0 }
            if !attachments.isEmpty {
                self.performSegue(withIdentifier: "ShowPreview", sender: attachments)
            }
        }
    }
    
    private func pdfToImage(url: URL) -> UIImage? {
        guard let document = CGPDFDocument(url as CFURL),
              let page = document.page(at: 1) else { return nil }
        
        let pageRect = page.getBoxRect(.mediaBox)
        let renderer = UIGraphicsImageRenderer(size: pageRect.size)
        
        return renderer.image { ctx in
            UIColor.white.set()
            ctx.fill(pageRect)
            
            ctx.cgContext.translateBy(x: 0.0, y: pageRect.size.height)
            ctx.cgContext.scaleBy(x: 1.0, y: -1.0)
            
            ctx.cgContext.drawPDFPage(page)
        }
    }
}


// MARK: - Collection View DataSource & Layout
extension RecordsViewController: UICollectionViewDelegate, UICollectionViewDataSource, UICollectionViewDelegateFlowLayout {
    func numberOfSections(in collectionView: UICollectionView) -> Int {
        return 1
    }
    
    func collectionView(_ collectionView: UICollectionView, numberOfItemsInSection section: Int) -> Int {
        return records.count
    }
    
    func showAttachmentPlatter() {
        guard let container = platterContainerView else {
             print("Error: platterContainerView not connected!")
             return
        }
        
        // Enable interaction on the container so taps register
        container.isUserInteractionEnabled = true
        
        // Instantiate View Controller from Storyboard
        let storyboard = UIStoryboard(name: "Main", bundle: nil)
        guard let platterVC = storyboard.instantiateViewController(withIdentifier: "AttachmentPlatterVC") as? AttachmentPlatterViewController else {
            print("Could not instantiate AttachmentPlatterVC")
            return
        }
        
        // Setup Callbacks
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
        platterVC.onDismiss = { [weak self] in self?.dismissPlatter() }
        platterVC.onAddPhotosTapped = { [weak self] assets in
            self?.dismissPlatter()
            self?.processPlatterAssets(assets)
        }
        platterVC.onSelectionChange = { [weak self] hasSelection in
            guard let self = self else { return }
            let targetHeight: CGFloat = hasSelection ? 310 : 280
            let duration: TimeInterval = 0.3
            
            // Animate the mask path in sync with the height constraint change
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
        
        // Add Pan Gesture for Swipe Down to dismiss
        let panGesture = UIPanGestureRecognizer(target: self, action: #selector(handlePlatterPan(_:)))
        platterVC.view.addGestureRecognizer(panGesture)
        
        // Tap in the transparent area ABOVE the platter card to dismiss.
        // This gesture lives on platterContainerView (the true top-level interceptor),
        // so it catches taps that miss platterVC.view entirely.
        let containerTap = UITapGestureRecognizer(target: self, action: #selector(containerBackgroundTapped(_:)))
        containerTap.cancelsTouchesInView = false
        container.addGestureRecognizer(containerTap)
        
        self.platterViewController = platterVC
        
        // Constraints — start below screen, then animate in
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
        
        // Animate In — also reveal the dimming overlay
        self.platterBottomConstraint?.constant = -5
        dimmingOverlayView?.isHidden = false
        dimmingOverlayView?.isUserInteractionEnabled = true
        
        UIView.animate(withDuration: 0.5, delay: 0, usingSpringWithDamping: 0.8, initialSpringVelocity: 0.5, options: .curveEaseOut) {
            self.tabBarController?.tabBar.alpha = 0
            self.dimmingOverlayView?.alpha = 0.3
            self.view.layoutIfNeeded()
        }
    }
    
    @objc func dismissPlatter() {
        guard let vc = platterViewController else { return }
        
        // Silently reset height to collapsed before sliding down,
        // so there's no competing height animation during dismiss.
        platterHeightConstraint?.constant = 280
        platterViewController?.animateMaskPath(toHeight: 280, duration: 0)
        view.layoutIfNeeded()
        
        // Animate Out
        self.platterBottomConstraint?.constant = 400
        
        UIView.animate(withDuration: 0.3, animations: {
            self.tabBarController?.tabBar.alpha = 1
            self.dimmingOverlayView?.alpha = 0
            self.view.layoutIfNeeded()
        }) { _ in
            // Hide and disable interaction once fully faded out
            self.dimmingOverlayView?.isHidden = true
            self.dimmingOverlayView?.isUserInteractionEnabled = false
            
            vc.willMove(toParent: nil)
            vc.view.removeFromSuperview()
            vc.removeFromParent()
            
            // Remove the tap gesture from the container so it doesn't accumulate
            if let gestures = self.platterContainerView?.gestureRecognizers {
                gestures.forEach { self.platterContainerView?.removeGestureRecognizer($0) }
            }
            
            self.platterViewController = nil
            self.platterBottomConstraint = nil
            self.platterHeightConstraint = nil
            
            self.platterContainerView?.isUserInteractionEnabled = false
        }
    }
    
    /// Dismisses the platter when the user taps in the transparent
    /// area of platterContainerView above the platter card.
    @objc private func containerBackgroundTapped(_ gesture: UITapGestureRecognizer) {
        guard let platterView = platterViewController?.view else { return }
        let location = gesture.location(in: platterContainerView)
        // platterView.frame is relative to platterContainerView (its superview)
        if !platterView.frame.contains(location) {
            dismissPlatter()
        }
    }
    
    @objc func handlePlatterPan(_ gesture: UIPanGestureRecognizer) {
        guard let view = gesture.view else { return }
        let translation = gesture.translation(in: view)
        let velocity = gesture.velocity(in: view)
        
        switch gesture.state {
        case .changed:
            if translation.y > 0 {
                self.platterBottomConstraint?.constant = translation.y - 5
                // Fade dimming proportionally as user drags down
                let progress = min(translation.y / 200, 1.0)
                self.dimmingOverlayView?.alpha = 0.3 * (1 - progress)
                self.view.layoutIfNeeded()
            }
            
        case .ended, .cancelled:
            if translation.y > 150 || velocity.y > 1000 {
                dismissPlatter()
            } else {
                // Snap back — restore dimming to full visible
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
    
    func collectionView(_ collectionView: UICollectionView, cellForItemAt indexPath: IndexPath) -> UICollectionViewCell {
        guard let cell = collectionView.dequeueReusableCell(withReuseIdentifier: "RecordCardCollectionViewCell", for: indexPath) as? RecordCardCollectionViewCell else {
            return UICollectionViewCell()
        }
        
        let record = records[indexPath.item]
        cell.configure(with: record)
        
        if selectionMode {
            let isSelected = selectedRecords.contains(where: { $0.id == record.id })
            let isAlreadyAdded = alreadySelectedRecordIDs.contains(record.id)
            cell.contentView.layer.cornerRadius = 12
            cell.contentView.layer.borderWidth = isSelected ? 2.5 : 0
            cell.contentView.layer.borderColor = isSelected ? UIColor.systemBlue.cgColor : UIColor.clear.cgColor
            cell.contentView.alpha = isAlreadyAdded ? 0.5 : 1.0
        } else {
            cell.contentView.layer.borderWidth = 0
            cell.contentView.alpha = 1.0
        }
        
        return cell
    }

    func collectionView(_ collectionView: UICollectionView, layout collectionViewLayout: UICollectionViewLayout, sizeForItemAt indexPath: IndexPath) -> CGSize {
        let padding: CGFloat = 16
        let interItemSpacing: CGFloat = 16
        
        let totalPadding = (padding * 2) + interItemSpacing
        let availableWidth = collectionView.frame.width - totalPadding
        
        let width = floor(availableWidth / 2)
        let height: CGFloat = 140 
        
        return CGSize(width: width, height: height)
    }
    
    func collectionView(_ collectionView: UICollectionView, layout collectionViewLayout: UICollectionViewLayout, insetForSectionAt section: Int) -> UIEdgeInsets {
        if selectionMode {
            return UIEdgeInsets(top: 70, left: 16, bottom: 20, right: 16)
        }
        return UIEdgeInsets(top: 130, left: 16, bottom: 20, right: 16)
    }
    
    func collectionView(_ collectionView: UICollectionView, layout collectionViewLayout: UICollectionViewLayout, minimumLineSpacingForSectionAt section: Int) -> CGFloat {
        return 16
    }
    
    func collectionView(_ collectionView: UICollectionView, layout collectionViewLayout: UICollectionViewLayout, minimumInteritemSpacingForSectionAt section: Int) -> CGFloat {
        return 16
    }
    
    func collectionView(_ collectionView: UICollectionView, didSelectItemAt indexPath: IndexPath) {
        let tappedRecord = records[indexPath.item]
        
        if selectionMode {
            if alreadySelectedRecordIDs.contains(tappedRecord.id) {
                return
            }
            if let existingIndex = selectedRecords.firstIndex(where: { $0.id == tappedRecord.id }) {
                selectedRecords.remove(at: existingIndex)
            } else {
                selectedRecords.append(tappedRecord)
            }
            collectionView.reloadItems(at: [indexPath])
        } else {
            performSegue(withIdentifier: detailSegueIdentifier, sender: tappedRecord)
        }
    }

    func collectionView(
        _ collectionView: UICollectionView,
        contextMenuConfigurationForItemAt indexPath: IndexPath,
        point: CGPoint
    ) -> UIContextMenuConfiguration? {
        guard !selectionMode, indexPath.item < records.count else { return nil }

        let record = records[indexPath.item]
        return UIContextMenuConfiguration(identifier: record.id as NSUUID, previewProvider: nil) { [weak self] _ in
            guard let self else { return nil }

            let deleteAction = UIAction(
                title: "Delete",
                image: UIImage(systemName: "trash"),
                attributes: .destructive
            ) { [weak self] _ in
                self?.presentDeleteConfirmation(for: record)
            }

            return UIMenu(title: "", children: [deleteAction])
        }
    }

    func collectionView(
        _ collectionView: UICollectionView,
        previewForHighlightingContextMenuWithConfiguration configuration: UIContextMenuConfiguration
    ) -> UITargetedPreview? {
        targetedPreview(for: configuration)
    }

    func collectionView(
        _ collectionView: UICollectionView,
        previewForDismissingContextMenuWithConfiguration configuration: UIContextMenuConfiguration
    ) -> UITargetedPreview? {
        targetedPreview(for: configuration)
    }
}

extension RecordsViewController: UIPopoverPresentationControllerDelegate {
    func adaptivePresentationStyle(for controller: UIPresentationController) -> UIModalPresentationStyle {
        return .none
    }
}

class DateFilterViewController: UIViewController {
    var onFilterSingleDate: ((Date) -> Void)?
    var onFilterDateRange: ((Date, Date) -> Void)?
    
    let segmentedControl = UISegmentedControl(items: ["Specific Date", "Custom Range"])
    let singleDatePicker = UIDatePicker()
    let startDatePicker = UIDatePicker()
    let endDatePicker = UIDatePicker()
    
    let singleDateContainer = UIView()
    let dateRangeContainer = UIStackView()
    
    override func viewDidLoad() {
        super.viewDidLoad()
        view.backgroundColor = .systemBackground
        
        segmentedControl.selectedSegmentIndex = 0
        segmentedControl.addTarget(self, action: #selector(segmentChanged), for: .valueChanged)
        
        singleDatePicker.datePickerMode = .date
        singleDatePicker.maximumDate = Date()
        if #available(iOS 14.0, *) {
            singleDatePicker.preferredDatePickerStyle = .inline
        }
        singleDatePicker.addTarget(self, action: #selector(singleDateChanged), for: .valueChanged)
        
        singleDateContainer.addSubview(singleDatePicker)
        singleDatePicker.translatesAutoresizingMaskIntoConstraints = false
        NSLayoutConstraint.activate([
            singleDatePicker.topAnchor.constraint(equalTo: singleDateContainer.topAnchor),
            singleDatePicker.bottomAnchor.constraint(equalTo: singleDateContainer.bottomAnchor),
            singleDatePicker.leadingAnchor.constraint(equalTo: singleDateContainer.leadingAnchor),
            singleDatePicker.trailingAnchor.constraint(equalTo: singleDateContainer.trailingAnchor)
        ])
        
        dateRangeContainer.axis = .vertical
        dateRangeContainer.spacing = 24
        dateRangeContainer.alignment = .fill
        
        startDatePicker.datePickerMode = .date
        startDatePicker.maximumDate = Date()
        if #available(iOS 14.0, *) {
            startDatePicker.preferredDatePickerStyle = .compact
        }
        startDatePicker.addTarget(self, action: #selector(rangeDateChanged), for: .valueChanged)
        
        endDatePicker.datePickerMode = .date
        endDatePicker.maximumDate = Date()
        if #available(iOS 14.0, *) {
            endDatePicker.preferredDatePickerStyle = .compact
        }
        endDatePicker.addTarget(self, action: #selector(rangeDateChanged), for: .valueChanged)
        
        let startLabel = UILabel()
        startLabel.text = "Start Date"
        startLabel.font = .systemFont(ofSize: 16, weight: .medium)
        let startRow = UIStackView(arrangedSubviews: [startLabel, startDatePicker])
        startRow.axis = .horizontal
        startRow.distribution = .equalSpacing
        
        let endLabel = UILabel()
        endLabel.text = "End Date"
        endLabel.font = .systemFont(ofSize: 16, weight: .medium)
        let endRow = UIStackView(arrangedSubviews: [endLabel, endDatePicker])
        endRow.axis = .horizontal
        endRow.distribution = .equalSpacing
        
        dateRangeContainer.addArrangedSubview(startRow)
        dateRangeContainer.addArrangedSubview(endRow)
        dateRangeContainer.isHidden = true
        
        let spacer = UIView()
        spacer.translatesAutoresizingMaskIntoConstraints = false
        spacer.heightAnchor.constraint(greaterThanOrEqualToConstant: 0).isActive = true
        dateRangeContainer.addArrangedSubview(spacer)
        
        let mainStack = UIStackView(arrangedSubviews: [segmentedControl, singleDateContainer, dateRangeContainer])
        mainStack.axis = .vertical
        mainStack.spacing = 20
        mainStack.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(mainStack)
        
        NSLayoutConstraint.activate([
            mainStack.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor, constant: 20),
            mainStack.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 20),
            mainStack.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -20),
            mainStack.bottomAnchor.constraint(lessThanOrEqualTo: view.safeAreaLayoutGuide.bottomAnchor, constant: -20)
        ])
    }
    
    @objc func segmentChanged() {
        singleDateContainer.isHidden = segmentedControl.selectedSegmentIndex != 0
        dateRangeContainer.isHidden = segmentedControl.selectedSegmentIndex == 0
    }
    
    @objc func singleDateChanged() {
        onFilterSingleDate?(singleDatePicker.date)
        dismiss(animated: true)
    }
    
    @objc func rangeDateChanged() {
        onFilterDateRange?(startDatePicker.date, endDatePicker.date)
        // Does not dismiss when range changes so user can easily adjust both ends!
    }
}

class DoctorSelectionViewController: UIViewController, UITableViewDelegate, UITableViewDataSource {
    var doctorNames: [String] = []
    var selectedDoctors: Set<String> = []
    var onDoctorSelectionChanged: ((Set<String>) -> Void)?
    
    let tableView = UITableView()
    
    override func viewDidLoad() {
        super.viewDidLoad()
        view.backgroundColor = .systemBackground
        
        tableView.delegate = self
        tableView.dataSource = self
        tableView.register(UITableViewCell.self, forCellReuseIdentifier: "cell")
        tableView.rowHeight = 44
        
        let headerLabel = UILabel()
        headerLabel.text = "Select Doctors"
        headerLabel.font = .systemFont(ofSize: 16, weight: .bold)
        headerLabel.textAlignment = .center
        let headerView = UIView(frame: CGRect(x: 0, y: 0, width: view.bounds.width, height: 40))
        headerLabel.frame = headerView.bounds
        headerLabel.autoresizingMask = [.flexibleWidth, .flexibleHeight]
        headerView.addSubview(headerLabel)
        tableView.tableHeaderView = headerView
        
        view.addSubview(tableView)
        tableView.translatesAutoresizingMaskIntoConstraints = false
        NSLayoutConstraint.activate([
            tableView.topAnchor.constraint(equalTo: view.topAnchor),
            tableView.bottomAnchor.constraint(equalTo: view.bottomAnchor),
            tableView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            tableView.trailingAnchor.constraint(equalTo: view.trailingAnchor)
        ])
    }
    
    func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        return doctorNames.count
    }
    
    func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let cell = tableView.dequeueReusableCell(withIdentifier: "cell", for: indexPath)
        let doctor = doctorNames[indexPath.row]
        cell.textLabel?.text = doctor
        cell.accessoryType = selectedDoctors.contains(doctor) ? .checkmark : .none
        cell.selectionStyle = .none
        return cell
    }
    
    func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        let doctor = doctorNames[indexPath.row]
        if selectedDoctors.contains(doctor) {
            selectedDoctors.remove(doctor)
        } else {
            selectedDoctors.insert(doctor)
        }
        tableView.reloadRows(at: [indexPath], with: .automatic)
        onDoctorSelectionChanged?(selectedDoctors)
    }
}

class FacilitySelectionViewController: UIViewController, UITableViewDelegate, UITableViewDataSource {
    var facilityNames: [String] = []
    var selectedFacilities: Set<String> = []
    var onFacilitySelectionChanged: ((Set<String>) -> Void)?
    
    let tableView = UITableView()
    
    override func viewDidLoad() {
        super.viewDidLoad()
        view.backgroundColor = .systemBackground
        
        tableView.delegate = self
        tableView.dataSource = self
        tableView.register(UITableViewCell.self, forCellReuseIdentifier: "cell")
        tableView.rowHeight = 44
        
        let headerLabel = UILabel()
        headerLabel.text = "Select Health Facilities"
        headerLabel.font = .systemFont(ofSize: 16, weight: .bold)
        headerLabel.textAlignment = .center
        let headerView = UIView(frame: CGRect(x: 0, y: 0, width: view.bounds.width, height: 40))
        headerLabel.frame = headerView.bounds
        headerLabel.autoresizingMask = [.flexibleWidth, .flexibleHeight]
        headerView.addSubview(headerLabel)
        tableView.tableHeaderView = headerView
        
        view.addSubview(tableView)
        tableView.translatesAutoresizingMaskIntoConstraints = false
        NSLayoutConstraint.activate([
            tableView.topAnchor.constraint(equalTo: view.topAnchor),
            tableView.bottomAnchor.constraint(equalTo: view.bottomAnchor),
            tableView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            tableView.trailingAnchor.constraint(equalTo: view.trailingAnchor)
        ])
    }
    
    func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        return max(1, facilityNames.count)
    }
    
    func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let cell = tableView.dequeueReusableCell(withIdentifier: "cell", for: indexPath)
        if facilityNames.isEmpty {
            cell.textLabel?.text = "No facilities available"
            cell.textLabel?.textColor = .systemGray
            cell.accessoryType = .none
            cell.selectionStyle = .none
        } else {
            let facility = facilityNames[indexPath.row]
            cell.textLabel?.text = facility
            cell.textLabel?.textColor = .label
            cell.accessoryType = selectedFacilities.contains(facility) ? .checkmark : .none
            cell.selectionStyle = .none
        }
        return cell
    }
    
    func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        guard !facilityNames.isEmpty else { return }
        
        let facility = facilityNames[indexPath.row]
        if selectedFacilities.contains(facility) {
            selectedFacilities.remove(facility)
        } else {
            selectedFacilities.insert(facility)
        }
        tableView.reloadRows(at: [indexPath], with: .automatic)
        onFacilitySelectionChanged?(selectedFacilities)
    }
}
