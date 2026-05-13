import UIKit

class EmptyHomeMedicineCollectionViewCell: UICollectionViewCell {

    @IBOutlet weak var cardView: UIView!
    @IBOutlet weak var bannerImageView: UIImageView!
    @IBOutlet weak var addMedicineView: UIView!
    @IBOutlet weak var headingLabel: UILabel!
    @IBOutlet weak var subHeadingLabel: UILabel!
    @IBOutlet weak var captionLabel: UILabel!
    @IBOutlet weak var addMedicineLabel: UILabel!

    var onAddMedicineTapped: (() -> Void)?

    override func awakeFromNib() {
        super.awakeFromNib()
        backgroundColor = .clear
        contentView.backgroundColor = .clear

        cardView.layer.cornerRadius = 20
        cardView.clipsToBounds = true

        bannerImageView.layer.cornerRadius = 16
        bannerImageView.clipsToBounds = true

        self.layer.shadowColor = UIColor.black.cgColor
        self.layer.shadowOffset = CGSize(width: 0, height: 2)
        self.layer.shadowOpacity = 0.08
        self.layer.shadowRadius = 10
        self.layer.masksToBounds = false
        
        headingLabel.font = .systemFont(ofSize: headingLabel.font.pointSize, weight: .bold).rounded
        subHeadingLabel.font = .systemFont(ofSize: subHeadingLabel.font.pointSize, weight: .medium).rounded
        captionLabel.font = .systemFont(ofSize: captionLabel.font.pointSize, weight: .medium).rounded
        addMedicineLabel.font = .systemFont(ofSize: addMedicineLabel.font.pointSize, weight: .medium).rounded

        let tap = UITapGestureRecognizer(target: self, action: #selector(addMedicineTapped))
        addMedicineView.addGestureRecognizer(tap)
        addMedicineView.isUserInteractionEnabled = true
    }

    override func layoutSubviews() {
        super.layoutSubviews()
        self.layer.shadowPath = UIBezierPath(
            roundedRect: bounds,
            cornerRadius: 16
        ).cgPath
    }

    @objc private func addMedicineTapped() {
        onAddMedicineTapped?()
    }
}
