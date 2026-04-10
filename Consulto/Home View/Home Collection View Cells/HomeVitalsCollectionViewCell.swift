import UIKit

class HomeVitalsCollectionViewCell: UICollectionViewCell {
    
    @IBOutlet weak var cardView: UIView!
    @IBOutlet weak var iconImageView: UIImageView!
    @IBOutlet weak var titleLabel: UILabel!
    @IBOutlet weak var valueLabel: UILabel!
    @IBOutlet weak var unitLabel: UILabel!

    override func awakeFromNib() {
        super.awakeFromNib()
        // Initialization code
        
        cardView.layer.cornerRadius = 16
        
        titleLabel.font = .systemFont(ofSize: titleLabel.font.pointSize, weight: .medium).rounded
        valueLabel.font = .systemFont(ofSize: valueLabel.font.pointSize, weight: .bold).rounded
        unitLabel.font = .systemFont(ofSize: unitLabel.font.pointSize, weight: .medium).rounded
        
        self.layer.shadowColor = UIColor.black.cgColor
        self.layer.shadowOffset = CGSize(width: 0, height: 2)
        self.layer.shadowOpacity = 0.08
        self.layer.shadowRadius = 10
        self.layer.masksToBounds = false
    }
    
    func configure(title: String, value: String, unit: String, imageName: String?) {
        
        titleLabel.text = title
        valueLabel.text = "\(value)"
        unitLabel.text = unit
        if let name = imageName {
            iconImageView.image = UIImage(named: name)
        }
    }
}
