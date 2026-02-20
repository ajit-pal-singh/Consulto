import UIKit
import SwiftUI
import Combine

class RecordsViewController: UIViewController, UINavigationControllerDelegate {

    @IBOutlet weak var recordsCollectionView: UICollectionView!
        
    @IBOutlet weak var chipsContainerView: UIView!

    @IBOutlet weak var blurEffectView: UIVisualEffectView!
    @IBOutlet weak var headerActionsContainerView: UIView! 
    

    var records: [HealthRecord] = []
    private var allRecords: [HealthRecord] = []
    
    @IBOutlet weak var platterContainerView: UIView!

    // Platter Properties
    var platterHostingController: UIHostingController<AttachmentPlatterView>?
    var overlayDimmingView: UIView?
    var platterBottomConstraint: NSLayoutConstraint?
    
    // Segue Identifier
    let detailSegueIdentifier = "Card-Details"
    
    // View Model for Filters
    var filterViewModel = FilterViewModel()
    var cancellables = Set<AnyCancellable>()
    
    override func viewDidLoad() {
        super.viewDidLoad()
        navigationController?.delegate = self
        
        // Ensure container ignores touches when empty
        platterContainerView?.isUserInteractionEnabled = false
        
        setupCollectionView()
        setupChipsView()
        setupHeaderActions() // Initialize Header Buttons
        loadData()
        
        // Subscribe to Filter Changes
        filterViewModel.$selectedFilter
            .receive(on: RunLoop.main)
            .sink { [weak self] newFilter in
                print("Filter Changed to: \(newFilter)")
                self?.filterRecords(by: newFilter)
            }
            .store(in: &cancellables)
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
        
        // Clear any existing subviews if needed
        container.subviews.forEach { $0.removeFromSuperview() }
        container.backgroundColor = .clear 
        container.clipsToBounds = false // Allow shadows to flow out
        
        // Create SwiftUI View with ViewModel
        let swiftUIView = ChipsView(viewModel: filterViewModel)
        let hostingController = UIHostingController(rootView: swiftUIView)
        hostingController.view.backgroundColor = .clear
        hostingController.view.clipsToBounds = false // Allow shadows to flow out
        
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
        
        // Transparent background for collection view
        recordsCollectionView.backgroundColor = .clear
        
        // Disable automatic estimation to fix spacing issues
        if let layout = recordsCollectionView.collectionViewLayout as? UICollectionViewFlowLayout {
            layout.estimatedItemSize = .zero
            layout.minimumInteritemSpacing = 16
            layout.minimumLineSpacing = 16
        }
    }
    
    func loadData() {
        allRecords = SampleData.getSampleRecords()
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
    
    // Navigation Handler
    func navigationController(_ navigationController: UINavigationController, willShow viewController: UIViewController, animated: Bool) {
            let isRecordsScreen = (viewController === self)
            navigationController.setNavigationBarHidden(isRecordsScreen, animated: animated)
    }
    
    // Gradient Generation

    
    override func viewDidLayoutSubviews() {
        super.viewDidLayoutSubviews()
        
        // Re-apply mask when layout changes (e.g., rotation)
        if blurEffectView != nil {
           setupBlurGradientMask()
        }
    }
    
    func setupBlurGradientMask() {
        // Create a gradient layer that goes from opaque to transparent
        let gradientMask = CAGradientLayer()
        gradientMask.frame = blurEffectView.bounds
        
        // Colors for the mask: 
        // solid black = full blur, clear = no blur
        gradientMask.colors = [
            UIColor.black.cgColor,      // Top (Full Blur)
            UIColor.black.cgColor,      // Middle (Full Blur)
            UIColor.clear.cgColor       // Bottom (No Blur)
        ]
        
        // Locations: Keep it blury until the very bottom edge where it fades out
        gradientMask.locations = [0.0, 0.8, 1.0] 
        
        // Apply the mask to the blur view's layer
        blurEffectView.layer.mask = gradientMask
        
        // Add solid overlay
        // Check if overlay already exists to avoid duplicates
        if let existingOverlay = blurEffectView.layer.sublayers?.first(where: { $0.name == "SolidOverlay" }) {
            existingOverlay.frame = blurEffectView.bounds
        } else {
            let overlayLayer = CALayer()
            overlayLayer.name = "SolidOverlay"
            overlayLayer.frame = blurEffectView.bounds
            overlayLayer.backgroundColor = UIColor(hex: "#f5f5f5")?.withAlphaComponent(0.5).cgColor
            
            // Important: We need to mask the overlay too so it fades out with the blur
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
             // Fallback to view if needed, or just return
             return
        }
        
        // 0. Enable interaction on the container so taps register
        container.isUserInteractionEnabled = true
        
        // 1. Create Dimming View (optional, for focus)
        let dimmingView = UIView()
        dimmingView.backgroundColor = UIColor.black.withAlphaComponent(0.3)
        dimmingView.alpha = 0
        dimmingView.translatesAutoresizingMaskIntoConstraints = false
        
        // Add Tap Gesture to Dismiss
        let tap = UITapGestureRecognizer(target: self, action: #selector(dismissPlatter))
        dimmingView.addGestureRecognizer(tap)
        
        container.addSubview(dimmingView)
        NSLayoutConstraint.activate([
            dimmingView.topAnchor.constraint(equalTo: container.topAnchor),
            dimmingView.leadingAnchor.constraint(equalTo: container.leadingAnchor),
            dimmingView.trailingAnchor.constraint(equalTo: container.trailingAnchor),
            dimmingView.bottomAnchor.constraint(equalTo: container.bottomAnchor)
        ])
        self.overlayDimmingView = dimmingView
        
        // 2. specific setup for hosting controller
        let platterView = AttachmentPlatterView(
            onCameraTap: { print("Camera Tapped") },
            onGalleryTap: { print("Gallery Tapped") },
            onDocumentTap: { print("Document Tapped") },
            onDismiss: { [weak self] in self?.dismissPlatter() }
        )
        
        let hostingController = UIHostingController(rootView: platterView)
        
        hostingController.view.backgroundColor = .clear
        hostingController.view.translatesAutoresizingMaskIntoConstraints = false
        
        addChild(hostingController)
        container.addSubview(hostingController.view)
        hostingController.didMove(toParent: self)
        
        // Add Pan Gesture for Swipe Down
        let panGesture = UIPanGestureRecognizer(target: self, action: #selector(handlePlatterPan(_:)))
        hostingController.view.addGestureRecognizer(panGesture)
        
        self.platterHostingController = hostingController
        
        // 3. Constraints (Start Off-Screen)
        let bottomConstraint = hostingController.view.bottomAnchor.constraint(equalTo: container.bottomAnchor, constant: 400) // Start below screen
        self.platterBottomConstraint = bottomConstraint
        
        NSLayoutConstraint.activate([
            hostingController.view.leadingAnchor.constraint(equalTo: container.leadingAnchor, constant: 5),
            hostingController.view.trailingAnchor.constraint(equalTo: container.trailingAnchor, constant: -5),
            bottomConstraint,
            // Height is handled by intrinsic content size of SwiftUI view
        ])
        
        container.layoutIfNeeded() // Set initial state
        
        // 4. Animate In
        self.platterBottomConstraint?.constant = -5 // Float 5pt from bottom
        
        UIView.animate(withDuration: 0.5, delay: 0, usingSpringWithDamping: 0.8, initialSpringVelocity: 0.5, options: .curveEaseOut) {
            dimmingView.alpha = 1
            self.tabBarController?.tabBar.alpha = 0 // Hide Tab Bar
            self.view.layoutIfNeeded()
        }
    }
    
    @objc func dismissPlatter() {
        guard let hostingController = platterHostingController else { return }
        
        // Animate Out
        self.platterBottomConstraint?.constant = 400 // Move down
        
        UIView.animate(withDuration: 0.3, animations: {
            self.overlayDimmingView?.alpha = 0
            self.tabBarController?.tabBar.alpha = 1 // Show Tab Bar
            self.view.layoutIfNeeded()
        }) { _ in
            // Clean up
            self.overlayDimmingView?.removeFromSuperview()
            hostingController.willMove(toParent: nil)
            hostingController.view.removeFromSuperview()
            hostingController.removeFromParent()
            
            self.overlayDimmingView = nil
            self.platterHostingController = nil
            self.platterBottomConstraint = nil
            
            // Disable interaction on the container so it doesn't block touches
            self.platterContainerView?.isUserInteractionEnabled = false
        }
    }
    
    @objc func handlePlatterPan(_ gesture: UIPanGestureRecognizer) {
        guard let view = gesture.view else { return }
        let translation = gesture.translation(in: view)
        let velocity = gesture.velocity(in: view)
        
        switch gesture.state {
        case .changed:
            // Only allow dragging down
            if translation.y > 0 {
                // Adjust for start position (-5) so it doesn't jump
                self.platterBottomConstraint?.constant = translation.y - 5
                // Fade out dimming view slightly as we drag down
                let progress = min(translation.y / 200, 1.0)
                self.overlayDimmingView?.alpha = 1 - progress
            }
            
        case .ended, .cancelled:
            // Threshold to dismiss: dragged down 150pt OR fast velocity down
            if translation.y > 150 || velocity.y > 1000 {
                dismissPlatter()
            } else {
                // Snap back to floating position
                self.platterBottomConstraint?.constant = -5
                UIView.animate(withDuration: 0.3, delay: 0, usingSpringWithDamping: 0.8, initialSpringVelocity: 0.5, options: .curveEaseOut) {
                    self.overlayDimmingView?.alpha = 1
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
        
        return cell
    }
    
    // Layout Logic
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
        // Records Grid
        return UIEdgeInsets(top: 130, left: 16, bottom: 20, right: 16)
    }
    
    func collectionView(_ collectionView: UICollectionView, layout collectionViewLayout: UICollectionViewLayout, minimumLineSpacingForSectionAt section: Int) -> CGFloat {
        return 16
    }
    
    func collectionView(_ collectionView: UICollectionView, layout collectionViewLayout: UICollectionViewLayout, minimumInteritemSpacingForSectionAt section: Int) -> CGFloat {
        return 16
    }
    
    func collectionView(_ collectionView: UICollectionView, didSelectItemAt indexPath: IndexPath) {
        let selectedRecord = records[indexPath.item]
        performSegue(withIdentifier: detailSegueIdentifier, sender: selectedRecord)
    }
}



