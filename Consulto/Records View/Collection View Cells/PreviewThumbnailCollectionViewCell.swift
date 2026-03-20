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
    
    var onExpandTapped: (() -> Void)?

    override func awakeFromNib() {
        super.awakeFromNib()
    }
    
    func configure(with image: UIImage) {
        thumbnailImageView.image = image
    }

    @IBAction func expandButtonTapped(_ sender: UIButton) {
        onExpandTapped?()
    }
}
