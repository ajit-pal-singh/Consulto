//
//  QuestionCollectionViewCell.swift
//  ConsultSession
//
//  Created by geu on 07/02/26.
//

import UIKit

class QuestionCollectionViewCell: UICollectionViewCell {

    @IBOutlet weak var questionCardView: UIView!
    @IBOutlet weak var questionLabel: UILabel!
    @IBOutlet weak var statusImageView: UIImageView!
    
    
    override func awakeFromNib() {
        super.awakeFromNib()
        
        questionCardView.layer.cornerRadius = 20
        questionCardView.backgroundColor = .white
    }
    
    func configure(with item: Question) {
        questionLabel.text = item.text

        if item.isSelected {
            statusImageView.image = UIImage(systemName: "checkmark.circle.fill")
            statusImageView.tintColor = UIColor.systemGreen
        } else {
            statusImageView.image = UIImage(systemName: "circle")
            statusImageView.tintColor = UIColor.systemBlue
        }
    }

}
