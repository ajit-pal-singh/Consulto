//
//  PhotoCollectionViewCell.swift
//  Consulto
//
//  Created by Ajitpal Singh on 17/03/26.
//

import UIKit

class PhotoCollectionViewCell: UICollectionViewCell {
    
    @IBOutlet weak var photoImageView: UIImageView!
    @IBOutlet weak var selectionIndicatorView: UIView!
    @IBOutlet weak var selectionNumberLabel: UILabel!
    @IBOutlet weak var borderContainerView: UIView!

    override func awakeFromNib() {
        super.awakeFromNib()
        
        // Initial setup for the selection indicator circle
        selectionIndicatorView.layer.cornerRadius = 9 // Half of 18 to make it a circle
        selectionIndicatorView.layer.borderWidth = 1.5
        selectionIndicatorView.layer.borderColor = UIColor.white.cgColor
        
        // Hide label by default
        selectionNumberLabel.isHidden = true
    }
    
    // Configure cell state
    func configure(isSelected: Bool, selectionOrder: Int?) {
        if isSelected {
            // Selected state
            selectionIndicatorView.backgroundColor = .white
            selectionIndicatorView.alpha = 1.0
            
            selectionNumberLabel.isHidden = false
            if let order = selectionOrder {
                selectionNumberLabel.text = "\(order)"
            }
            
            // Show Blue Stroke
            borderContainerView.layer.borderWidth = 3
            borderContainerView.layer.borderColor = UIColor.systemBlue.cgColor
        } else {
            // Unselected state
            selectionIndicatorView.backgroundColor = .black
            selectionIndicatorView.alpha = 0.5
            selectionNumberLabel.isHidden = true
            
            // Hide Stroke
            borderContainerView.layer.borderWidth = 0
        }
    }

}
