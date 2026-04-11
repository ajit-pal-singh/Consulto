import UIKit

final class PreviewProcessingStackFlowLayout: UICollectionViewFlowLayout {

    var isProcessingStackEnabled = false {
        didSet {
            guard oldValue != isProcessingStackEnabled else { return }
            invalidateLayout()
        }
    }

    var processingStackCurrentItem = 0 {
        didSet {
            guard oldValue != processingStackCurrentItem else { return }
            invalidateLayout()
        }
    }

    var processingStackBackgroundExtraHeightShrink: CGFloat = 0 {
        didSet {
            guard oldValue != processingStackBackgroundExtraHeightShrink else { return }
            invalidateLayout()
        }
    }

    override func shouldInvalidateLayout(forBoundsChange newBounds: CGRect) -> Bool {
        true
    }

    override var collectionViewContentSize: CGSize {
        guard isProcessingStackEnabled, let collectionView else {
            return super.collectionViewContentSize
        }

        let baseContentSize = super.collectionViewContentSize
        let height = max(
            collectionView.bounds.height,
            sectionInset.top + itemSize.height + sectionInset.bottom
        )

        // Preserve the paged content width while stacked so UIKit does not clamp the
        // current horizontal offset mid-animation when the user is on page 2+.
        let width = max(
            baseContentSize.width,
            collectionView.contentOffset.x + collectionView.bounds.width
        )
        return CGSize(width: width, height: height)
    }

    override func layoutAttributesForElements(in rect: CGRect) -> [UICollectionViewLayoutAttributes]? {
        guard isProcessingStackEnabled, let collectionView else {
            return super.layoutAttributesForElements(in: rect)
        }

        var attributes: [UICollectionViewLayoutAttributes] = []
        for section in 0..<collectionView.numberOfSections {
            for item in 0..<collectionView.numberOfItems(inSection: section) {
                let indexPath = IndexPath(item: item, section: section)
                if let itemAttributes = layoutAttributesForItem(at: indexPath) {
                    attributes.append(itemAttributes)
                }
            }
        }
        return attributes
    }

    override func layoutAttributesForItem(at indexPath: IndexPath) -> UICollectionViewLayoutAttributes? {
        guard let attributes = super.layoutAttributesForItem(at: indexPath)?.copy() as? UICollectionViewLayoutAttributes else {
            return nil
        }
        guard isProcessingStackEnabled, let collectionView else {
            return attributes
        }

        // Give every item the same centered frame in processing so the stack is explicit,
        // instead of relying on a zero-stride flow layout.
        let isCurrentItem = indexPath.item == processingStackCurrentItem
        let aspectRatio = itemSize.height > 0 ? (itemSize.width / itemSize.height) : 1

        let targetHeight: CGFloat
        if isCurrentItem {
            targetHeight = itemSize.height
        } else {
            targetHeight = max(1, itemSize.height - processingStackBackgroundExtraHeightShrink)
        }
        let targetWidth = max(1, targetHeight * aspectRatio)

        let originX = collectionView.contentOffset.x + ((collectionView.bounds.width - targetWidth) / 2)
        let originY = attributes.frame.origin.y + ((itemSize.height - targetHeight) / 2)
        attributes.frame = CGRect(
            x: originX,
            y: originY,
            width: targetWidth,
            height: targetHeight
        )
        attributes.zIndex = isCurrentItem ? 1000 : 0
        return attributes
    }
}
