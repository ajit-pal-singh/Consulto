
import UIKit

class VitalMetricCollectionViewCell: UICollectionViewCell {
    
    @IBOutlet weak var titleLabel: UILabel!
    @IBOutlet weak var valueLabel: UILabel!
    @IBOutlet weak var unitLabel: UILabel!
    @IBOutlet weak var iconImageView: UIImageView!
    @IBOutlet weak var subtitleLabel: UILabel!

    override func awakeFromNib() {
        super.awakeFromNib()
        setupUI()
    }
    
    private func setupUI() {
        contentView.backgroundColor = .white
        contentView.layer.cornerRadius = 12
        
        layer.shadowColor = UIColor.black.cgColor
        layer.shadowOpacity = 0.05
        layer.shadowOffset = CGSize(width: 0, height: 2)
        layer.shadowRadius = 8
        layer.masksToBounds = false
        
        if let titleFont = titleLabel.font.fontDescriptor.withDesign(.rounded) {
            titleLabel.font = UIFont(descriptor: titleFont, size: titleLabel.font.pointSize)
        }
        if let valFont = valueLabel.font.fontDescriptor.withDesign(.rounded) {
            valueLabel.font = UIFont(descriptor: valFont, size: valueLabel.font.pointSize)
        }
        if let unitFont = unitLabel.font.fontDescriptor.withDesign(.rounded) {
            unitLabel.font = UIFont(descriptor: unitFont, size: unitLabel.font.pointSize)
        }
        if let subFont = subtitleLabel.font.fontDescriptor.withDesign(.rounded) {
            subtitleLabel.font = UIFont(descriptor: subFont, size: subtitleLabel.font.pointSize)
        }
        
        if let superview = iconImageView.superview {
            for constraint in superview.constraints {
                if let first = constraint.firstItem as? UIImageView, first == iconImageView, constraint.firstAttribute == .top {
                    constraint.isActive = false
                }
            }
            iconImageView.translatesAutoresizingMaskIntoConstraints = false
            iconImageView.centerYAnchor.constraint(equalTo: valueLabel.centerYAnchor).isActive = true
        }
    }

    func configure(title: String, value: String, unit: String, subtitle: String, icon: UIImage? = nil, isTextValue: Bool = false) {
        titleLabel.text = title
        valueLabel.text = value
        unitLabel.text = unit
        subtitleLabel.text = subtitle
        
        if let icon = icon {
            iconImageView.image = icon
            iconImageView.isHidden = false
        } else {
            iconImageView.isHidden = true
        }
        
        
        if isTextValue {
            if let valFont = UIFont.systemFont(ofSize: 20, weight: .semibold).fontDescriptor.withDesign(.rounded) {
                valueLabel.font = UIFont(descriptor: valFont, size: 20)
            }
            valueLabel.adjustsFontSizeToFitWidth = false
            unitLabel.adjustsFontSizeToFitWidth = false
        } else {
            let isBloodPressure = (title.contains("BP") || unit == "mmHg") && title != "Variability"
            
            let valueFontSize: CGFloat = isBloodPressure ? 29 : 30
            let unitFontSize: CGFloat  = isBloodPressure ? 19 : 20
            
            if let valFont = UIFont.systemFont(ofSize: valueFontSize, weight: .bold).fontDescriptor.withDesign(.rounded) {
                valueLabel.font = UIFont(descriptor: valFont, size: valueFontSize)
            }
            if let unitFnt = UIFont.systemFont(ofSize: unitFontSize, weight: .medium).fontDescriptor.withDesign(.rounded) {
                unitLabel.font = UIFont(descriptor: unitFnt, size: unitFontSize)
            }
            
            valueLabel.adjustsFontSizeToFitWidth = isBloodPressure
            valueLabel.minimumScaleFactor = 0.45
            
            unitLabel.adjustsFontSizeToFitWidth = isBloodPressure
            unitLabel.minimumScaleFactor = 0.55
        }
    }
}
