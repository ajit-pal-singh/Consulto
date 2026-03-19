import UIKit

class AddRecordCollectionViewCell: UICollectionViewCell {
    
    @IBOutlet weak var dateIconImageView: UIImageView!
    @IBOutlet weak var plusIcon: UIImageView!
    @IBOutlet weak var addRecordLabel: UILabel!
    
    override func awakeFromNib() {
        super.awakeFromNib()
        
        self.backgroundColor = .clear
        self.contentView.layer.cornerRadius = 12
        self.contentView.clipsToBounds = true
    }
}
