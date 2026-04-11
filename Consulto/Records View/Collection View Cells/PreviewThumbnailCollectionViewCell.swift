//
//  PreviewThumbnailCollectionViewCell.swift
//  Consulto
//
//  Created by Ajitpal Singh on 19/03/26.
//

import UIKit

class PreviewThumbnailCollectionViewCell: UICollectionViewCell {
    @IBOutlet weak var thumbnailImageView: UIImageView!
    @IBOutlet weak var expandView: UIView!
    @IBOutlet weak var deleteView: UIView!
    
    var onExpandTapped: (() -> Void)?
    var onDeleteTapped: (() -> Void)?

    override func awakeFromNib() {
        super.awakeFromNib()
        
        // The base cell layer handles the shadow
        self.layer.masksToBounds = false
        self.layer.shadowColor = UIColor.black.cgColor
        self.layer.shadowOpacity = 0.10
        self.layer.shadowOffset = CGSize(width: 0, height: 4)
        self.layer.shadowRadius = 6
        
        // The contentView handles the clipping (so the image gets rounded corners)
        self.contentView.layer.cornerRadius = 16
        self.contentView.layer.masksToBounds = true
        
        thumbnailImageView.layer.cornerRadius = 16
        thumbnailImageView.contentMode = .scaleAspectFill
        thumbnailImageView.clipsToBounds = true
    }

    override func prepareForReuse() {
        super.prepareForReuse()
        alpha = 1
        transform = .identity
        layer.zPosition = 0
        thumbnailImageView.image = nil
    }
    
    func configure(with image: UIImage, isProcessing: Bool = false) {
        alpha = 1
        transform = .identity
        layer.zPosition = 0
        thumbnailImageView.image = image
        // Hide the expand button, delete button, and drop shadow cleanly if processing
        expandView.alpha = isProcessing ? 0 : 1
        deleteView?.alpha = isProcessing ? 0 : 1
        self.layer.shadowOpacity = isProcessing ? 0 : 0.10
    }

    @IBAction func expandButtonTapped(_ sender: UIButton) {
        onExpandTapped?()
    }
    
    @IBAction func deleteButtonTapped(_ sender: UIButton) {
        onDeleteTapped?()
    }
}
