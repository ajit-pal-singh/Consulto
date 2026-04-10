import UIKit

class SymptomCollectionViewCell: UICollectionViewCell {

    protocol SymptomCollectionViewCellDelegate: AnyObject {
        func symptomCellDidTapChevron(_ cell: SymptomCollectionViewCell)
    }

    weak var delegate: SymptomCollectionViewCellDelegate?

    @IBOutlet weak var symptomCardView: UIView!
    @IBOutlet weak var symptomTitleLabel: UILabel!
    @IBOutlet weak var descriptionLabel: UILabel!
    @IBOutlet weak var chevronImageView: UIImageView!

    var onChevronTap: (() -> Void)?

    override func awakeFromNib() {
        super.awakeFromNib()
        symptomCardView.layer.cornerRadius = 20
        symptomCardView.clipsToBounds = true
        
        // Shadow for the cell
        self.layer.shadowColor = UIColor.black.cgColor
        self.layer.shadowOffset = CGSize(width: 0, height: 2)
        self.layer.shadowOpacity = 0.08
        self.layer.shadowRadius = 10
        self.layer.masksToBounds = false

        symptomTitleLabel.font =
            .systemFont(ofSize: symptomTitleLabel.font.pointSize, weight: .medium).rounded
        descriptionLabel.font =
            .systemFont(ofSize: descriptionLabel.font.pointSize, weight: .medium).rounded

        descriptionLabel.lineBreakMode = .byTruncatingTail

        let tap = UITapGestureRecognizer(target: self, action: #selector(didTapChevron))
        chevronImageView.addGestureRecognizer(tap)
    }

    override func prepareForReuse() {
        super.prepareForReuse()
        onChevronTap = nil
        chevronImageView.isHidden = false
    }

    override func layoutSubviews() {
        super.layoutSubviews()
        
        guard let text = descriptionLabel.text, !text.isEmpty else {
            chevronImageView.isHidden = true
            return
        }
        
        let width = descriptionLabel.bounds.width
        if width > 0 {
            let maxSize = CGSize(width: width, height: .greatestFiniteMagnitude)
            let exactSize = text.boundingRect(
                with: maxSize,
                options: .usesLineFragmentOrigin,
                attributes: [.font: descriptionLabel.font!],
                context: nil
            )
            
            let isMultiline = exactSize.height > descriptionLabel.font.lineHeight + 5
            chevronImageView.isHidden = !isMultiline
        }
    }

    func configure(title: String, description: String, isExpanded: Bool) {

        symptomTitleLabel.text = title
        descriptionLabel.text = description

        descriptionLabel.numberOfLines = isExpanded ? 0 : 1

        UIView.animate(withDuration: 0.25) {
            if self.chevronImageView.isHidden == false {
                self.chevronImageView.transform = isExpanded ? CGAffineTransform(rotationAngle: .pi) : .identity
            } else {
                self.chevronImageView.transform = .identity
            }
        }
    }

    @objc private func didTapChevron() {
        onChevronTap?()
    }
}
