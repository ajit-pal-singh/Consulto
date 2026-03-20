import UIKit

class AddRecordTableViewCell: UITableViewCell, UICollectionViewDelegate, UICollectionViewDataSource, UICollectionViewDelegateFlowLayout {
    
    @IBOutlet weak var recordsCollectionView: UICollectionView!
    @IBOutlet weak var collectionViewHeightConstraint: NSLayoutConstraint!
    
    var records: [HealthRecord] = []
    var didTapAddRecord: (() -> Void)?
    var didDeleteRecord: ((Int) -> Void)?   // for deleting the selected record from prepare sheet
    
    override func awakeFromNib() {
        super.awakeFromNib()
        
        recordsCollectionView?.delegate = self
        recordsCollectionView?.dataSource = self
        recordsCollectionView?.backgroundColor = .clear
        recordsCollectionView?.isScrollEnabled = false
        self.backgroundColor = .clear
        self.contentView.backgroundColor = .clear
        
        let recordNib = UINib(nibName: "RecordCardCollectionViewCell", bundle: nil)
        recordsCollectionView?.register(recordNib, forCellWithReuseIdentifier: "RecordCardCollectionViewCell")
        
        let addNib = UINib(nibName: "AddRecordCollectionViewCell", bundle: nil)
        recordsCollectionView?.register(addNib, forCellWithReuseIdentifier: "AddCardCell")
        
        if let layout = recordsCollectionView?.collectionViewLayout as? UICollectionViewFlowLayout {
            layout.estimatedItemSize = .zero
            layout.minimumInteritemSpacing = 12
            layout.minimumLineSpacing = 12
        }
    }
    
    //To make the added records corner radius as rounded by removing the table cell corner radius that is applying on record.(36 to 63)
    override func updateConfiguration(using state: UICellConfigurationState) {
        super.updateConfiguration(using: state)
        
        if #available(iOS 14.0, *) {
            var bgConfig = UIBackgroundConfiguration.clear()
            bgConfig.cornerRadius = 0
            bgConfig.backgroundColor = .clear
            self.backgroundConfiguration = bgConfig
        }
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
        self.recordsCollectionView?.clipsToBounds = false
        
        self.layer.mask = nil
        self.contentView.layer.mask = nil
    }
    
    func reloadRecords() {
        recordsCollectionView?.reloadData()
        recordsCollectionView?.layoutIfNeeded()
        let contentHeight = recordsCollectionView?.collectionViewLayout.collectionViewContentSize.height ?? 150
        collectionViewHeightConstraint?.constant = contentHeight
    }
    
    // MARK: - Collection View DataSource
    
    func collectionView(_ collectionView: UICollectionView, numberOfItemsInSection section: Int) -> Int {
        return records.count + 1  
    }
    
    func collectionView(_ collectionView: UICollectionView, cellForItemAt indexPath: IndexPath) -> UICollectionViewCell {
        if indexPath.item < records.count {
            let cell = collectionView.dequeueReusableCell(withReuseIdentifier: "RecordCardCollectionViewCell", for: indexPath) as! RecordCardCollectionViewCell
            cell.configure(with: records[indexPath.item])
            return cell
        } else {
            let cell = collectionView.dequeueReusableCell(withReuseIdentifier: "AddCardCell", for: indexPath) as! AddRecordCollectionViewCell
            return cell
        }
    }
    
    func collectionView(_ collectionView: UICollectionView, didSelectItemAt indexPath: IndexPath) {
        if indexPath.item == records.count {
            didTapAddRecord?()
        }
    }
    
    func collectionView(_ collectionView: UICollectionView, layout collectionViewLayout: UICollectionViewLayout, sizeForItemAt indexPath: IndexPath) -> CGSize {
        let interItemSpacing: CGFloat = 12
        let availableWidth = collectionView.frame.width - interItemSpacing
        let width = floor(availableWidth / 2)
        return CGSize(width: width, height: 140)
    }
    
    func collectionView(_ collectionView: UICollectionView, layout collectionViewLayout: UICollectionViewLayout, insetForSectionAt section: Int) -> UIEdgeInsets {
        return .zero
    }
    
    // Context Menu to delete the selected record from prepare sheet
    func collectionView(_ collectionView: UICollectionView, contextMenuConfigurationForItemAt indexPath: IndexPath, point: CGPoint) -> UIContextMenuConfiguration? {
        guard indexPath.item < records.count else { return nil }
        
        let identifier = NSNumber(value: indexPath.item)
        return UIContextMenuConfiguration(identifier: identifier, previewProvider: nil) { [weak self] _ in
            let deleteAction = UIAction(title: "Delete", image: UIImage(systemName: "trash"), attributes: .destructive) { _ in
                self?.didDeleteRecord?(indexPath.item)
            }
            return UIMenu(title: "", children: [deleteAction])
        }
    }
    
    // To make the preview for highlighting the context menu corner radius same as selected record.
    func collectionView(_ collectionView: UICollectionView, previewForHighlightingContextMenuWithConfiguration configuration: UIContextMenuConfiguration) -> UITargetedPreview? {
        guard let item = configuration.identifier as? NSNumber else { return nil }
        let indexPath = IndexPath(item: item.intValue, section: 0)
        
        guard let cell = collectionView.cellForItem(at: indexPath) else { return nil }
        
        let parameters = UIPreviewParameters()
        parameters.backgroundColor = .clear
        parameters.visiblePath = UIBezierPath(roundedRect: cell.bounds, cornerRadius: 12)
        
        return UITargetedPreview(view: cell, parameters: parameters)
    }
    
}
