
import UIKit

class RecordCardCollectionViewCell: UICollectionViewCell {
    
    @IBOutlet weak var dateLabel: UILabel!
    @IBOutlet weak var dateShape: UIImageView!
    @IBOutlet weak var typeLabel: UILabel!
    
    @IBOutlet weak var titleLabel: UILabel!
    @IBOutlet weak var facilityLabel: UILabel!
    @IBOutlet weak var summaryLabel: UILabel!

    override func awakeFromNib() {
        super.awakeFromNib()
        // Default styling setup
        self.backgroundColor = .clear
        
        // Shadow for the cell
        self.layer.shadowColor = UIColor.black.cgColor
        self.layer.shadowOffset = CGSize(width: 0, height: 2)
        self.layer.shadowOpacity = 0.08
        self.layer.shadowRadius = 10
        self.layer.masksToBounds = false
        
        // Font Application - SF Pro Rounded
        typeLabel.font = .systemFont(ofSize: typeLabel.font.pointSize, weight: .semibold).rounded
        titleLabel.font = .systemFont(ofSize: titleLabel.font.pointSize, weight: .semibold).rounded
        facilityLabel.font = .systemFont(ofSize: facilityLabel.font.pointSize, weight: .medium).rounded
        summaryLabel.font = .systemFont(ofSize: summaryLabel.font.pointSize, weight: .medium).rounded
        dateLabel.font = .systemFont(ofSize: dateLabel.font.pointSize, weight: .semibold).rounded
    }
    
    
    func configure(with record: HealthRecord) {
        // 1. Basic Text
        titleLabel.text = record.title
        facilityLabel.text = record.healthFacilityName
        summaryLabel.text = record.summary
        
        switch record.recordType {
        case .dischargeSummary:
            typeLabel.text = "Discharge"
        case .labReport:
            typeLabel.text = "Lab Report"
        default:
            typeLabel.text = record.recordType.rawValue.capitalized
        }
        
        // 2. Date Formatting
        let formatter = DateFormatter()
        formatter.dateFormat = "d MMM yyyy"
        if let date = record.documentDate ?? Optional(record.dateAdded) {
             dateLabel.text = formatter.string(from: date)
        }
        
        // 3. Record Type Color Assign
        let themeColor: UIColor
        switch record.recordType {
        case .prescription:
            themeColor = UIColor(named: "PrescriptionColor") ?? .systemBlue
        case .labReport:
            themeColor = UIColor(named: "ReportColor") ?? .systemRed
        case .dischargeSummary:
            themeColor = UIColor(named: "DischargeSummaryColor") ?? .systemYellow
        case .scan:
            themeColor = UIColor(named: "ScanColor") ?? .systemPurple
        default:
            themeColor = .darkGray
        }
        
        typeLabel.textColor = .white
        dateShape.tintColor = themeColor
    }
}

extension UIFont {
    var rounded: UIFont {
        guard let descriptor = fontDescriptor.withDesign(.rounded) else {
            return self
        }
        return UIFont(descriptor: descriptor, size: pointSize)
    }
}
