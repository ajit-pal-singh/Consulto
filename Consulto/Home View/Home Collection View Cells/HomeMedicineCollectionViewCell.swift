import UIKit

struct HomeMedicine {
    let rowId: UUID
    let name: String
    let dosage: String?
    let time: String
    let mealTime: String
    var isDone: Bool
}

class HomeMedicineCollectionViewCell: UICollectionViewCell {
    
    @IBOutlet weak var cardView: UIView!
    @IBOutlet weak var view: UIView!
    @IBOutlet weak var nameLabel: UILabel!
    @IBOutlet weak var unitLabel: UILabel!
    @IBOutlet weak var timeLabel: UILabel!
    @IBOutlet weak var dotLabel: UILabel!
    @IBOutlet weak var mealTimeLabel: UILabel!
    @IBOutlet weak var statusImageView: UIImageView!
    
    var onStatusTapped: (() -> Void)?

    override func awakeFromNib() {
        super.awakeFromNib()
        
        cardView.layer.cornerRadius = 20
        view.layer.cornerRadius = 15
        
        self.layer.shadowColor = UIColor.black.cgColor
        self.layer.shadowOffset = CGSize(width: 0, height: 2)
        self.layer.shadowOpacity = 0.08
        self.layer.shadowRadius = 10
        self.layer.masksToBounds = false
        
        nameLabel.font = .systemFont(ofSize: nameLabel.font.pointSize, weight: .semibold).rounded
        unitLabel.font = .systemFont(ofSize: unitLabel.font.pointSize, weight: .medium).rounded
        timeLabel.font = .systemFont(ofSize: timeLabel.font.pointSize, weight: .medium).rounded
        mealTimeLabel.font = .systemFont(ofSize: mealTimeLabel.font.pointSize, weight: .medium).rounded
        
        statusImageView.isUserInteractionEnabled = true
        let tapGesture = UITapGestureRecognizer(target: self, action: #selector(statusTapped))
        statusImageView.addGestureRecognizer(tapGesture)
    }
    
    override func prepareForReuse() {
        super.prepareForReuse()
            
        statusImageView.image = nil
    }
    
    func configure(with item: HomeMedicine) {
        
        nameLabel.text = item.name
        let dosageText = dosageLabelText(for: item.dosage)
        unitLabel.text = dosageText
        unitLabel.isHidden = dosageText == nil
        timeLabel.text = item.time
        mealTimeLabel.text = item.mealTime
            
        updateStatus(isDone: item.isDone)
    }

    private func dosageLabelText(for dosage: String?) -> String? {
        guard let dosage,
              !dosage.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            return nil
        }

        return dosage
    }
    
    private func updateStatus(isDone: Bool) {
        let imageName = isDone ? "checkmark.circle.fill" : "circle"
        let color = isDone ? UIColor.systemGreen : UIColor(hex: "#59B9E4")
        
        UIView.transition(with: statusImageView, duration: 0.2, options: .transitionCrossDissolve, animations: {
            self.statusImageView.image = UIImage(systemName: imageName)
        })
        statusImageView.tintColor = color
    }
    
    @objc private func statusTapped() {
        onStatusTapped?()
    }
}
