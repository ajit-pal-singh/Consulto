//
//  OnboardingCollectionViewCell.swift
//  Consulto
//
//  Created by Ajitpal Singh on 30/03/26.
//

import UIKit

class OnboardingCollectionViewCell: UICollectionViewCell {

    @IBOutlet weak var illustrationImageView: UIImageView!
    @IBOutlet weak var flatIconImageView: UIImageView!
    @IBOutlet weak var titleLabel: UILabel!
    @IBOutlet weak var bodyLabel: UILabel!

    override func awakeFromNib() {
        super.awakeFromNib()
        bodyLabel.numberOfLines = 0
        titleLabel.numberOfLines = 0
        backgroundColor = .clear
        contentView.backgroundColor = .clear
    }
    
    // Use the size provided by sizeForItemAt, don't let auto layout resize the cell
    override func preferredLayoutAttributesFitting(_ layoutAttributes: UICollectionViewLayoutAttributes) -> UICollectionViewLayoutAttributes {
        return layoutAttributes
    }
    
    override func layoutSubviews() {
        super.layoutSubviews()
        // Tell the label the max width it can use, so it wraps text properly
        bodyLabel.preferredMaxLayoutWidth = contentView.bounds.width - 40 // 20pt margin each side
        titleLabel.preferredMaxLayoutWidth = contentView.bounds.width - 40
    }
    
    func setup(illustration: UIImage?, icon: UIImage?, title: String?, body: String?) {
        illustrationImageView.image = illustration
        flatIconImageView.image = icon
        titleLabel.text = title
        
        // Add line spacing for body text
        guard let bodyText = body else {
            bodyLabel.text = nil
            return
        }
        
        let paragraphStyle = NSMutableParagraphStyle()
        paragraphStyle.lineSpacing = 6 // Adjust this value to increase/decrease spacing
        
        let attributedString = NSMutableAttributedString(string: bodyText)
        attributedString.addAttribute(.paragraphStyle, value: paragraphStyle, range: NSRange(location: 0, length: attributedString.length))
        
        bodyLabel.attributedText = attributedString
    }
}
