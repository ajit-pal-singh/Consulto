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
        
        //Temporary Reminder section as tab
        if let tabBarController = self.tabBarController,
               !(tabBarController.viewControllers?.contains(where: { $0.tabBarItem.title == "Reminders" }) ?? false) {

                var viewControllers = tabBarController.viewControllers ?? []

                let storyboard = UIStoryboard(name: "RemindersScreen", bundle: nil)
                let remindersVC = storyboard.instantiateViewController(withIdentifier: "RemindersVC")

                let nav = UINavigationController(rootViewController: remindersVC)

                nav.tabBarItem = UITabBarItem(
                    title: "Reminders",
                    image: UIImage(systemName: "bell"),
                    selectedImage: UIImage(systemName: "bell.fill")
                )

                viewControllers.append(nav)
                tabBarController.viewControllers = viewControllers
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
    
    func setupHeaderActions() {
        guard let container = headerActionsContainerView else { return }
        
        // Clear any existing subviews
        container.subviews.forEach { $0.removeFromSuperview() }
        container.backgroundColor = .clear
        
        let swiftUIView = HeaderActionsView(
            onAddAction: { [weak self] in
                self?.showAttachmentPlatter()
            },
            onFilterAction: {
                print("Filter Tapped")
            }
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
        filterRecords(by: filterViewModel.selectedFilter)
    }
    
    func filterRecords(by filter: String) {
        if filter == "All" {
            records = allRecords
        } else {
            records = allRecords.filter { record in
                switch filter {
                case "Prescription": return record.recordType == .prescription
                case "Lab Report": return record.recordType == .labReport
                case "Discharge": return record.recordType == .dischargeSummary
                case "Scan": return record.recordType == .scan
                case "Other": return record.recordType == .other
                default: return false
                }
            }
        }
        recordsCollectionView.reloadData()
    }

    private func presentDeleteConfirmation(for record: HealthRecord) {
        let alert = UIAlertController(
            title: "Delete Record?",
            message: "This will remove the record from your saved records.",
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
