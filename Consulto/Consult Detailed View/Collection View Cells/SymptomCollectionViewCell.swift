//
//  SymptomCollectionViewCell.swift
//  ConsultSession
//
//  Created by geu on 04/02/26.
//

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
        symptomCardView.layer.cornerRadius = 12
        symptomCardView.clipsToBounds = true
        
        symptomTitleLabel.font = .systemFont(ofSize: symptomTitleLabel.font.pointSize, weight: .medium).rounded
        descriptionLabel.font = .systemFont(ofSize: descriptionLabel.font.pointSize, weight: .medium).rounded
        
        descriptionLabel.lineBreakMode = .byTruncatingTail
        
        let tap = UITapGestureRecognizer(target: self, action: #selector(didTapChevron))
        chevronImageView.isUserInteractionEnabled = true
        chevronImageView.addGestureRecognizer(tap)
    }
    
    override func prepareForReuse() {
        super.prepareForReuse()
        onChevronTap = nil
    }
    
    func configure(title: String, description: String, isExpanded: Bool) {

        symptomTitleLabel.text = title
        descriptionLabel.text = description

        descriptionLabel.numberOfLines = isExpanded ? 0 : 1

        UIView.animate(withDuration: 0.25) {
            self.chevronImageView.transform = isExpanded ? CGAffineTransform(rotationAngle: .pi) : .identity
        }
    }
    
    @objc private func didTapChevron() {
        onChevronTap?()
    }
}

