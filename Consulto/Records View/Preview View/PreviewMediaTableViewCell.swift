import UIKit

class PreviewMediaTableViewCell: UITableViewCell {

    // MARK: - Outlets
    // Connect these from Storyboard (the prototype cell)
    @IBOutlet weak var collectionView: UICollectionView!
    @IBOutlet weak var collectionViewHeightConstraint: NSLayoutConstraint! // connect to CV height constraint
    @IBOutlet weak var pageLabel: UILabel!
    @IBOutlet weak var prevButton: UIButton!
    @IBOutlet weak var nextButton: UIButton!
    
    // Status View from Storyboard
    @IBOutlet weak var statusView: UIView!
    @IBOutlet weak var pageNavigatorView: UIView!

    // MARK: - Constants
    /// Visible peek of the adjacent card on each side
    private let peek: CGFloat = 20
    private let spacing: CGFloat = 18
    private let processingStackBackgroundExtraHeightShrink: CGFloat = 5
    
    /// Height of the page navigator below the collection view.
    /// Should match whatever vertical space sits below the CV in the storyboard cell.
    static let pageNavigatorHeight: CGFloat = 66

    // MARK: - State
    enum CardState {
        case pending
        case processing
        case form
    }
    private var images: [UIImage] = []
    private var currentPage: Int = 0
    private var cardState: CardState = .pending
    var onExpandTapped: ((Int) -> Void)?
    var onDeleteTapped: ((Int) -> Void)?
    
    /// Set to `true` to hide the delete button overlay on every thumbnail card.
    /// Useful when the cell is shown in a read-only context (e.g. Record Detailed View).
    var hideDeleteButton: Bool = false

    // MARK: - Lifecycle
    override func awakeFromNib() {
        super.awakeFromNib()
        selectionStyle = .none
        setupCollectionView()
        statusView?.isHidden = true // Ensure status is hidden initially
    }

    override func updateConfiguration(using state: UICellConfigurationState) {
        super.updateConfiguration(using: state)

        var bgConfig = UIBackgroundConfiguration.clear()
        bgConfig.cornerRadius = 0
        bgConfig.backgroundColor = .clear
        self.backgroundConfiguration = bgConfig
    }

    override func layoutSubviews() {
        super.layoutSubviews()
        self.backgroundColor = .clear
        self.contentView.backgroundColor = .clear

        // Defeat table cell grouping masks
        self.layer.cornerRadius = 0
        self.contentView.layer.cornerRadius = 0
        self.layer.masksToBounds = false
        self.contentView.layer.masksToBounds = false
        self.clipsToBounds = false
        self.contentView.clipsToBounds = false

        self.layer.mask = nil
        self.contentView.layer.mask = nil

        updateItemSize()
    }

    // MARK: - Setup
    private func setupCollectionView() {
        collectionView.delegate = self
        collectionView.dataSource = self
        // We handle snapping manually. System paging conflicts with custom item widths/insets.
        collectionView.isPagingEnabled = false

        let nib = UINib(nibName: "PreviewThumbnailCollectionViewCell", bundle: nil)
        collectionView.register(nib, forCellWithReuseIdentifier: "PreviewThumbnailCell")

        let layout = ensureCollectionViewLayout()
        layout.scrollDirection = .horizontal
        layout.minimumLineSpacing = spacing
        layout.estimatedItemSize = .zero   // ⚠️ must NOT be .automatic

        // Let adjacent cards peek outside this view's bounds
        collectionView.clipsToBounds = false
        collectionView.showsHorizontalScrollIndicator = false
        collectionView.backgroundColor = .clear
        
        // Prevent UIKit from silently adding safe-area / navigation bar insets
        // that would shift the content and break our offset calculations.
        collectionView.contentInsetAdjustmentBehavior = .never
    }

    @discardableResult
    private func ensureCollectionViewLayout() -> PreviewProcessingStackFlowLayout {
        if let layout = collectionView.collectionViewLayout as? PreviewProcessingStackFlowLayout {
            return layout
        }

        let previousLayout = collectionView.collectionViewLayout as? UICollectionViewFlowLayout
        let layout = PreviewProcessingStackFlowLayout()
        layout.scrollDirection = previousLayout?.scrollDirection ?? .horizontal
        layout.minimumLineSpacing = previousLayout?.minimumLineSpacing ?? spacing
        layout.minimumInteritemSpacing = previousLayout?.minimumInteritemSpacing ?? 0
        layout.sectionInset = previousLayout?.sectionInset ?? .zero
        layout.itemSize = previousLayout?.itemSize ?? .zero
        layout.estimatedItemSize = .zero
        collectionView.setCollectionViewLayout(layout, animated: false)
        return layout
    }

    /// Recalculates item size, section insets, and the 4:3 card height constraint
    /// based on the current collection view width. Called from layoutSubviews.
    private func updateItemSize() {
        guard collectionView.bounds.width > 0 else { return }

        let layout = ensureCollectionViewLayout()

        //  Card width = collection view width (which is now full screen) - 40pt (screen margins) - left peek - right peek
        var itemWidth  = collectionView.bounds.width - 40 - (2 * peek)
        
        // Portrait 3:4 aspect ratio → height = width × (4/3)
        // This ensures the card perfectly frames a portrait document on every device.
        var cardHeight = (itemWidth * 4 / 3).rounded()
        
        if cardState != .pending {
            // Shrink the height by 150
            cardHeight -= 150
            // Maintain the 3:4 aspect ratio by calculating the new width
            itemWidth = (cardHeight * 3 / 4).rounded()
        }
        
        let newSize = CGSize(width: itemWidth, height: cardHeight)
        
        // Always apply size and spacing conditionally based on dynamic state!
        layout.itemSize = newSize
        layout.processingStackCurrentItem = currentPage
        layout.isProcessingStackEnabled = cardState == .processing
        layout.processingStackBackgroundExtraHeightShrink = processingStackBackgroundExtraHeightShrink
        
        let centerPadding = (collectionView.bounds.width - itemWidth) / 2

        // For .pending and .form states: naturally space them out.
        // In processing, the custom layout ignores horizontal stride and explicitly stacks the frames.
        layout.minimumLineSpacing = spacing
        layout.sectionInset = UIEdgeInsets(top: 0, left: centerPadding, bottom: 0, right: centerPadding)
        
        layout.invalidateLayout()
        
        // Update the storyboard height constraint so the CV matches the card
        collectionViewHeightConstraint?.constant = cardHeight
    }

    // MARK: - Configure
    func configure(with images: [UIImage], state: CardState = .pending) {
        let didImageSetChange = self.images.count != images.count
        self.images = images
        self.cardState = state
        if didImageSetChange {
            currentPage = 0
        } else if !images.isEmpty {
            currentPage = min(currentPage, images.count - 1)
        } else {
            currentPage = 0
        }
        updateItemSize()
        collectionView.reloadData()
        if !images.isEmpty {
            scrollToPage(currentPage, animated: false)
        }
        updatePageUI()
    }

    // MARK: - Page Control

    private func updatePageUI() {
        guard !images.isEmpty else {
            pageLabel.text = "Page 0 of 0"
            prevButton.isEnabled = false
            nextButton.isEnabled = false
            return
        }
        pageLabel.text = "Page \(currentPage + 1) of \(images.count)"
        prevButton.isEnabled = currentPage > 0
        nextButton.isEnabled = currentPage < images.count - 1
    }

    private func clampedCurrentPage() -> Int {
        guard !images.isEmpty else { return 0 }
        return max(0, min(currentPage, images.count - 1))
    }

    private func preserveCurrentPageForAnimatedStateTransition() -> Int {
        let preservedPage = clampedCurrentPage()
        currentPage = preservedPage

        if let layout = collectionView.collectionViewLayout as? PreviewProcessingStackFlowLayout {
            layout.processingStackCurrentItem = preservedPage
        }

        return preservedPage
    }

    private func targetContentOffsetX(for page: Int, state: CardState) -> CGFloat {
        guard page > 0 else { return 0 }
        guard collectionView.bounds.width > 0 else { return 0 }

        var itemWidth = collectionView.bounds.width - 40 - (2 * peek)
        var cardHeight = (itemWidth * 4 / 3).rounded()

        if state != .pending {
            cardHeight -= 150
            itemWidth = (cardHeight * 3 / 4).rounded()
        }

        let pageStride = itemWidth + spacing
        guard pageStride > 0 else { return 0 }
        return CGFloat(page) * pageStride
    }

    /// Scrolls the collection view to a specific page, snapping it into the centered position.
    private func scrollToPage(_ page: Int, animated: Bool = true) {
        guard let layout = collectionView.collectionViewLayout as? UICollectionViewFlowLayout else { return }
        if let stackLayout = layout as? PreviewProcessingStackFlowLayout {
            stackLayout.processingStackCurrentItem = page
        }
        let targetX: CGFloat
        if cardState == .processing {
            // Keep the visible stack centered during processing.
            targetX = 0
        } else {
            // Each page advances by exactly one card-width + one gap
            let pageStride = layout.itemSize.width + layout.minimumLineSpacing
            guard pageStride > 0 else { return }
            targetX = max(0, CGFloat(page) * pageStride)
        }
        collectionView.setContentOffset(CGPoint(x: targetX, y: 0), animated: animated)
        currentPage = page
        updatePageUI()
    }

    @IBAction func prevButtonTapped(_ sender: UIButton) {
        guard currentPage > 0 else { return }
        scrollToPage(currentPage - 1)
    }

    @IBAction func nextButtonTapped(_ sender: UIButton) {
        guard currentPage < images.count - 1 else { return }
        scrollToPage(currentPage + 1)
    }
}

// MARK: - UICollectionView DataSource & Delegate
extension PreviewMediaTableViewCell: UICollectionViewDataSource, UICollectionViewDelegate {

    func collectionView(_ collectionView: UICollectionView, numberOfItemsInSection section: Int) -> Int {
        images.count
    }

    func collectionView(_ collectionView: UICollectionView, cellForItemAt indexPath: IndexPath) -> UICollectionViewCell {
        guard let cell = collectionView.dequeueReusableCell(
            withReuseIdentifier: "PreviewThumbnailCell",
            for: indexPath
        ) as? PreviewThumbnailCollectionViewCell else {
            return UICollectionViewCell()
        }
        // If we are in State 2 (processing) or State 3 (form), we want to keep the expand view hidden
        let hideControls = self.cardState != .pending
        cell.configure(with: images[indexPath.item], isProcessing: hideControls)
        
        // Hide the delete overlay when requested by the parent (e.g. Record Detailed View)
        if hideDeleteButton {
            cell.deleteView?.isHidden = true
        }
        
        cell.onExpandTapped = { [weak self] in
            guard let self else { return }
            guard indexPath.item >= 0, indexPath.item < self.images.count else { return }
            self.onExpandTapped?(indexPath.item)
        }
        cell.onDeleteTapped = { [weak self] in
            guard let self else { return }
            guard indexPath.item >= 0, indexPath.item < self.images.count else { return }
            self.onDeleteTapped?(indexPath.item)
        }
        return cell
    }

    // MARK: - Snap-to-page on Manual Swipe
    /// Kill the natural deceleration and redirect to our precise scrollToPage,
    /// so swipe and button tap go through EXACTLY the same code path.
    func scrollViewWillEndDragging(
        _ scrollView: UIScrollView,
        withVelocity velocity: CGPoint,
        targetContentOffset: UnsafeMutablePointer<CGPoint>
    ) {
        guard let layout = collectionView.collectionViewLayout as? UICollectionViewFlowLayout else { return }

        let pageStride = layout.itemSize.width + layout.minimumLineSpacing

        // Determine which page to snap to
        let targetPage: Int
        if velocity.x > 0.4 {
            targetPage = min(currentPage + 1, images.count - 1)
        } else if velocity.x < -0.4 {
            targetPage = max(currentPage - 1, 0)
        } else {
            let proposedX = targetContentOffset.pointee.x
            targetPage = max(0, min(images.count - 1, Int(round(proposedX / pageStride))))
        }

        // 🔑 Freeze the natural physics-based deceleration dead in its tracks.
        // Then we drive the animation ourselves via setContentOffset,
        // exactly the same as the button tap path.
        targetContentOffset.pointee = scrollView.contentOffset
        scrollToPage(targetPage, animated: true)
    }
    
    // MARK: - State 2 Animations
    
    func startProcessingAnimation() {
        guard cardState == .pending else { return }
        let preservedPage = preserveCurrentPageForAnimatedStateTransition()
        cardState = .processing
        
        // Lock scrolling
        collectionView.isScrollEnabled = false
        
        // 1. Hide Navigator Container entirely and expand views & shadows
        UIView.animate(withDuration: 0.3) {
            self.pageNavigatorView?.alpha = 0
            
            for cell in self.collectionView.visibleCells {
                if let thumbCell = cell as? PreviewThumbnailCollectionViewCell {
                    thumbCell.expandView.alpha = 0
                    thumbCell.deleteView?.alpha = 0
                    
                    // Explicitly fade out shadow using a layer animation
                    let shadowAnim = CABasicAnimation(keyPath: "shadowOpacity")
                    shadowAnim.fromValue = 0.10
                    shadowAnim.toValue = 0
                    shadowAnim.duration = 0.3
                    thumbCell.layer.add(shadowAnim, forKey: "shadowFade")
                    thumbCell.layer.shadowOpacity = 0
                }
            }
        }
        
        // 2. Show Processing Status
        statusView?.alpha = 0
        statusView?.isHidden = false
        UIView.animate(withDuration: 0.5, delay: 0.3, options: .curveEaseInOut) {
            self.statusView?.alpha = 1
        } completion: { _ in
            // Pulsate
            UIView.animate(withDuration: 1.0, delay: 0, options: [.autoreverse, .repeat, .allowUserInteraction]) {
                self.statusView?.alpha = 0.5
            }
        }
        
        // 3. Shrink Collection View Card and collapse others behind
        // Using `performBatchUpdates` forces UICollectionView to animate the physical geometry
        // (frames, scaling, sliding) instead of doing a default cross-fade between layout states.
        UIView.animate(withDuration: 1.0, delay: 0, options: .curveEaseInOut) {
            self.collectionView.performBatchUpdates({
                self.updateItemSize()
            }, completion: nil)
            
            self.layoutIfNeeded()
        }
    }
    
    func transitionToState3() {
        let preservedPage = preserveCurrentPageForAnimatedStateTransition()
        let targetOffsetX = targetContentOffsetX(for: preservedPage, state: .form)

        // Make the final page offset effective before expansion begins. In processing
        // every card is visually centered by the custom layout, so this offset change
        // is invisible here and prevents sideways drift while expanding.
        UIView.performWithoutAnimation {
            self.collectionView.contentOffset = CGPoint(x: targetOffsetX, y: 0)
            self.collectionView.layoutIfNeeded()
        }

        cardState = .form
        
        // 1. Fade out the pulsating processing status view completely over 0.3 seconds
        UIView.animate(withDuration: 0.3) {
            self.statusView?.alpha = 0
        }
        
        // 2. Elegantly expand the thumbnails back out from behind the stack over exactly 1.0 seconds
        UIView.animate(withDuration: 1.0, delay: 0, options: .curveEaseInOut) {
            // Re-enable scrolling capability so the user can swipe again
            self.collectionView.isScrollEnabled = true

            self.collectionView.performBatchUpdates({
                self.updateItemSize()
            }) { _ in
                self.scrollToPage(preservedPage, animated: false)
                self.collectionView.reloadData()
            }
            self.layoutIfNeeded()
        }
    }
}
