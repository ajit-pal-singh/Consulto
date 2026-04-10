import UIKit

class MedicationCollectionViewCell: UICollectionViewCell {

    @IBOutlet weak var medicationCardView: UIView!
    @IBOutlet weak var view: UIView!
    @IBOutlet weak var nameLabel: UILabel!
    @IBOutlet weak var dosageLabel: UILabel!
    @IBOutlet weak var dotLabel: UILabel!
    @IBOutlet weak var frequencyLabel: UILabel!
    @IBOutlet weak var containerView: UIView!
    @IBOutlet weak var durationLabel: UILabel!

    override func awakeFromNib() {
        super.awakeFromNib()
        setupUI()
    }
    
    private func setupUI() {
        
        medicationCardView.layer.cornerRadius = 20
        view.layer.cornerRadius = 15
        
        self.layer.shadowColor = UIColor.black.cgColor
        self.layer.shadowOffset = CGSize(width: 0, height: 2)
        self.layer.shadowOpacity = 0.08
        self.layer.shadowRadius = 10
        self.layer.masksToBounds = false
        
        nameLabel.font = .systemFont(ofSize: nameLabel.font.pointSize, weight: .semibold).rounded
        dosageLabel.font = .systemFont(ofSize: dosageLabel.font.pointSize, weight: .medium).rounded
        frequencyLabel.font = .systemFont(ofSize: frequencyLabel.font.pointSize, weight: .medium).rounded
        durationLabel.font = .systemFont(ofSize: durationLabel.font.pointSize, weight: .medium).rounded

        containerView.backgroundColor = UIColor(hex: "F0F9FF")
        frequencyLabel.textColor = UIColor(hex: "0679C6")
        dotLabel.textColor = UIColor(hex: "0679C6")
        durationLabel.textColor = UIColor(hex: "0679C6")
        containerView.layer.cornerRadius = 4
        containerView.clipsToBounds = true
    }

    func configure(name: String, dosage: String, frequency: String, duration: String, isSelectable: Bool = false, isMarkedSelected: Bool = false) {
        nameLabel.text = name
        dosageLabel.text = dosage
        frequencyLabel.text = frequency
        durationLabel.text = duration

        dotLabel.isHidden = frequency.isEmpty || duration.isEmpty
        medicationCardView.layer.borderWidth = 0
        medicationCardView.layer.borderColor = UIColor.clear.cgColor
        medicationCardView.alpha = 1.0
    }
}
