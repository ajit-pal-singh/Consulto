import UIKit

class AddRecordTableViewCell: UITableViewCell, UICollectionViewDelegate, UICollectionViewDataSource, UICollectionViewDelegateFlowLayout {
    
    @IBOutlet weak var recordsCollectionView: UICollectionView!
    @IBOutlet weak var collectionViewHeightConstraint: NSLayoutConstraint!
    
    var records: [HealthRecord] = []
    var didTapAddRecord: (() -> Void)?
    
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
}
