//
//  QuestionCollectionViewCell.swift
//  Consulto
//
//  Created by Tevika Kumbhawat on 16/03/26.
//

import UIKit

class QuestionCollectionViewCell: UICollectionViewCell {

    @IBOutlet weak var questionCardView: UIView!
    @IBOutlet weak var statusImageView: UIImageView!
    @IBOutlet weak var questionLabel: UILabel!
    
    
    override func awakeFromNib() {
        super.awakeFromNib()
        
        // Shadow for the cell
        self.layer.shadowColor = UIColor.black.cgColor
        self.layer.shadowOffset = CGSize(width: 0, height: 2)
        self.layer.shadowOpacity = 0.08
        self.layer.shadowRadius = 10
        self.layer.masksToBounds = false
        
        questionLabel.font = .systemFont(ofSize: questionLabel.font.pointSize, weight: .medium).rounded
        
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

