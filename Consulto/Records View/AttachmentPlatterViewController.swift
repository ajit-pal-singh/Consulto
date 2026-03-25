import UIKit
import Photos

class AttachmentPlatterViewController: UIViewController {

    // MARK: - Outlets
    @IBOutlet weak var platterContainerView: UIView!
    @IBOutlet weak var grabberView: UIView!
    @IBOutlet weak var collectionView: UICollectionView!
    @IBOutlet weak var documentRowContainer: UIView!
    @IBOutlet weak var addPhotosButton: UIButton!
    
    // MARK: - Callbacks
    var onCameraTap: (() -> Void)?
    var onGalleryTap: (() -> Void)?
    var onDocumentTap: (() -> Void)?
    var onDismiss: (() -> Void)?
    var onAddPhotosTapped: (([PHAsset]) -> Void)?
    
    // MARK: - Properties
    private var recentAssets: [PHAsset] = []
    private var selectedAssets: [PHAsset] = [] // Keeps track of selected photos and their order
    
    override func viewDidLoad() {
        super.viewDidLoad()
        setupUI()
        setupCollectionView()
        fetchRecentPhotos()
    }
    
    private func setupUI() {
        // Ensure background is transparent so the dimming view from the parent shows
        view.backgroundColor = .clear
        
        // Setup Glass Effect
        platterContainerView.backgroundColor = .clear
        let blurEffect = UIBlurEffect(style: .systemUltraThinMaterial)
        let blurEffectView = UIVisualEffectView(effect: blurEffect)
        blurEffectView.frame = platterContainerView.bounds
        blurEffectView.autoresizingMask = [.flexibleWidth, .flexibleHeight]
        
        // Here is your opacity control! 
        // 1.0 is solid white, 0.0 is completely transparent (just raw blur)
        blurEffectView.contentView.backgroundColor = UIColor(white: 1.0, alpha: 0.45)
        
        // Insert the blur view behind everything else
        platterContainerView.insertSubview(blurEffectView, at: 0)
        
        // Add action for the document row
        let docTap = UITapGestureRecognizer(target: self, action: #selector(documentRowTapped))
        documentRowContainer.addGestureRecognizer(docTap)
        
        // Ensure initial correct state for bottom button/file row
        updateBottomActions()
        
        // Modern iOS Buttons use Configurations, which ignore layer.cornerRadius.
        // This forces the button to be a perfect pill (capsule) shape!
        if addPhotosButton.configuration != nil {
            addPhotosButton.configuration?.cornerStyle = .capsule
        } else {
            addPhotosButton.layer.cornerRadius = addPhotosButton.bounds.height / 2
            addPhotosButton.layer.masksToBounds = true
        }
    }
    
    override func viewDidLayoutSubviews() {
        super.viewDidLayoutSubviews()
        // Update mask path without animation during normal layout passes
        // (animated updates are driven explicitly via animateMaskPath)
        let newPath = buildPlatterPath(for: platterContainerView.bounds)
        if let existingMask = platterContainerView.layer.mask as? CAShapeLayer {
            existingMask.path = newPath.cgPath
        } else {
            let maskLayer = CAShapeLayer()
            maskLayer.path = newPath.cgPath
            platterContainerView.layer.mask = maskLayer
        }
    }
    
    // MARK: - Layout Logic
    
    /// Builds the platter bezier path for a given rect.
    private func buildPlatterPath(for rect: CGRect) -> UIBezierPath {
        let topRadius: CGFloat = 24
        let bottomRadius: CGFloat = 55
        let width = rect.width
        let height = rect.height
        
        let path = UIBezierPath()
        // Top left
        path.move(to: CGPoint(x: 0, y: topRadius))
        path.addArc(withCenter: CGPoint(x: topRadius, y: topRadius), radius: topRadius, startAngle: .pi, endAngle: 3 * .pi / 2, clockwise: true)
        // Top right
        path.addLine(to: CGPoint(x: width - topRadius, y: 0))
        path.addArc(withCenter: CGPoint(x: width - topRadius, y: topRadius), radius: topRadius, startAngle: 3 * .pi / 2, endAngle: 0, clockwise: true)
        // Bottom right
        path.addLine(to: CGPoint(x: width, y: height - bottomRadius))
        path.addArc(withCenter: CGPoint(x: width - bottomRadius, y: height - bottomRadius), radius: bottomRadius, startAngle: 0, endAngle: .pi / 2, clockwise: true)
        // Bottom left
        path.addLine(to: CGPoint(x: bottomRadius, y: height))
        path.addArc(withCenter: CGPoint(x: bottomRadius, y: height - bottomRadius), radius: bottomRadius, startAngle: .pi / 2, endAngle: .pi, clockwise: true)
        path.close()
        return path
    }
    
    /// Animates the mask shape layer path to match a new target height.
    /// Call this alongside any height constraint animation to keep corners in sync.
    func animateMaskPath(toHeight targetHeight: CGFloat, duration: TimeInterval) {
        guard let maskLayer = platterContainerView.layer.mask as? CAShapeLayer else { return }
        
        let targetRect = CGRect(x: 0, y: 0, width: platterContainerView.bounds.width, height: targetHeight)
        let newPath = buildPlatterPath(for: targetRect).cgPath
        
        let animation = CABasicAnimation(keyPath: "path")
        animation.fromValue = maskLayer.path
        animation.toValue = newPath
        animation.duration = duration
        animation.timingFunction = CAMediaTimingFunction(name: .easeInEaseOut)
        animation.fillMode = .forwards
        animation.isRemovedOnCompletion = false
        
        maskLayer.add(animation, forKey: "pathAnimation")
        // Set the model value so it stays after animation completes
        CATransaction.begin()
        CATransaction.setDisableActions(true)
        maskLayer.path = newPath
        CATransaction.commit()
    }
    
    private func setupCollectionView() {
        collectionView.delegate = self
        collectionView.dataSource = self
        
        // Register XIBs
        collectionView.register(UINib(nibName: "CameraCollectionViewCell", bundle: nil), forCellWithReuseIdentifier: "CameraCell")
        collectionView.register(UINib(nibName: "PhotoCollectionViewCell", bundle: nil), forCellWithReuseIdentifier: "PhotoCell")
        
        // Setup internal padding
        collectionView.contentInset = UIEdgeInsets(top: 0, left: 20, bottom: 0, right: 20)
    }
    
    // MARK: - Actions
    @IBAction func allPhotosTapped(_ sender: UIButton) {
        onGalleryTap?()
    }
    
    @IBAction func addPhotosTapped(_ sender: UIButton) {
        onAddPhotosTapped?(selectedAssets)
    }
    
    @objc private func documentRowTapped() {
        onDocumentTap?()
    }
    
    var onSelectionChange: ((Bool) -> Void)?
    
    private func updateBottomActions() {
        let count = selectedAssets.count
        let hasSelection = count > 0
        
        if hasSelection {
            // Update title
            let titleText = count == 1 ? "Add 1 Photo" : "Add \(count) Photos"
            
            // Use an AttributedString to set text while preserving font styling
            var container = AttributeContainer()
            container.font = UIFont.systemFont(ofSize: 15.5, weight: .medium)
            addPhotosButton.configuration?.attributedTitle = AttributedString(titleText, attributes: container)
        }
        
        // Notify parent controller to expand/collapse height
        onSelectionChange?(hasSelection)
        
        // Animate fade in/out for add photos button
        UIView.animate(withDuration: 0.3) {
            self.addPhotosButton.alpha = hasSelection ? 1.0 : 0.0
        }
        
        // Update interaction so invisible views don't steal touches
        self.addPhotosButton.isUserInteractionEnabled = hasSelection
        self.documentRowContainer.isUserInteractionEnabled = true
    }
    
    // MARK: - Photo Fetching
    private func fetchRecentPhotos() {
        PHPhotoLibrary.requestAuthorization { [weak self] status in
            guard status == .authorized || status == .limited else { return }
            
            let fetchOptions = PHFetchOptions()
            fetchOptions.sortDescriptors = [NSSortDescriptor(key: "creationDate", ascending: false)]
            fetchOptions.fetchLimit = 15 // Load 15 recent photos
            
            let fetchResult = PHAsset.fetchAssets(with: .image, options: fetchOptions)
            
            var assets: [PHAsset] = []
            fetchResult.enumerateObjects { asset, _, _ in
                assets.append(asset)
            }
            
            DispatchQueue.main.async {
                self?.recentAssets = assets
                self?.collectionView.reloadData()
            }
        }
    }
}

// MARK: - UICollectionView Delegate & DataSource
extension AttachmentPlatterViewController: UICollectionViewDelegate, UICollectionViewDataSource, UICollectionViewDelegateFlowLayout {
    
    func collectionView(_ collectionView: UICollectionView, numberOfItemsInSection section: Int) -> Int {
        return recentAssets.count + 1 // +1 for the camera cell at index 0
    }
    
    func collectionView(_ collectionView: UICollectionView, cellForItemAt indexPath: IndexPath) -> UICollectionViewCell {
        
        if indexPath.item == 0 {
            // Camera Cell
            let cell = collectionView.dequeueReusableCell(withReuseIdentifier: "CameraCell", for: indexPath) as! CameraCollectionViewCell
            return cell
        } else {
            // Photo Cell
            let cell = collectionView.dequeueReusableCell(withReuseIdentifier: "PhotoCell", for: indexPath) as! PhotoCollectionViewCell
            
            let assetIndex = indexPath.item - 1
            let asset = recentAssets[assetIndex]
            
            // Fetch Image for Thumbnail
            let manager = PHImageManager.default()
            let options = PHImageRequestOptions()
            options.isSynchronous = false
            options.deliveryMode = .opportunistic
            
            manager.requestImage(for: asset, targetSize: CGSize(width: 200, height: 200), contentMode: .aspectFill, options: options) { image, _ in
                DispatchQueue.main.async {
                    cell.photoImageView.image = image
                }
            }
            
            // Check Selection State
            if let index = selectedAssets.firstIndex(of: asset) {
                // It is selected, pass the order (index + 1 so it starts at 1)
                cell.configure(isSelected: true, selectionOrder: index + 1)
            } else {
                // Not selected
                cell.configure(isSelected: false, selectionOrder: nil)
            }
            
            return cell
        }
    }
    
    func collectionView(_ collectionView: UICollectionView, didSelectItemAt indexPath: IndexPath) {
        if indexPath.item == 0 {
            // Camera tapped
            onCameraTap?()
        } else {
            // Photo tapped - Toggle selection
            let assetIndex = indexPath.item - 1
            let asset = recentAssets[assetIndex]
            
            if let index = selectedAssets.firstIndex(of: asset) {
                // Deselect
                selectedAssets.remove(at: index)
            } else {
                // Select
                selectedAssets.append(asset)
            }
            
            // Update visible cells instead of reloading the entire collection view to prevent glitching/flashing
            for visibleIndexPath in collectionView.indexPathsForVisibleItems {
                guard visibleIndexPath.item > 0,
                      let cell = collectionView.cellForItem(at: visibleIndexPath) as? PhotoCollectionViewCell else {
                    continue
                }
                
                let visibleAssetIndex = visibleIndexPath.item - 1
                if visibleAssetIndex >= 0 && visibleAssetIndex < recentAssets.count {
                    let visibleAsset = recentAssets[visibleAssetIndex]
                    
                    if let selectedIndex = selectedAssets.firstIndex(of: visibleAsset) {
                        cell.configure(isSelected: true, selectionOrder: selectedIndex + 1)
                    } else {
                        cell.configure(isSelected: false, selectionOrder: nil)
                    }
                }
            }
            
            // Toggle UI state for bottom elements (File Row vs Add Photo Button)
            self.updateBottomActions()
        }
    }
    
    func collectionView(_ collectionView: UICollectionView, layout collectionViewLayout: UICollectionViewLayout, sizeForItemAt indexPath: IndexPath) -> CGSize {
        return CGSize(width: 100, height: 100)
    }
}
