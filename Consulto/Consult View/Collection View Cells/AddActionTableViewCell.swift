//
//  AddActionTableViewCell.swift
//  Consulto
//
//  Created by Tevika Kumbhawat on 18/03/26.
//

import UIKit

class AddActionTableViewCell: UITableViewCell {
    
    @IBOutlet weak var actionImageView: UIImageView!
    @IBOutlet weak var actionLabel: UILabel!
    
    var didTapAction: (() -> Void)?

    override func awakeFromNib() {
        super.awakeFromNib()

        isUserInteractionEnabled = true
        contentView.isUserInteractionEnabled = true
        
        self.layer.shadowColor = UIColor.black.cgColor
        self.layer.shadowOffset = CGSize(width: 0, height: 2)
        self.layer.shadowOpacity = 0.08
        self.layer.shadowRadius = 10
        self.layer.masksToBounds = false

        let tapGesture = UITapGestureRecognizer(target: self, action: #selector(handleTap))
        contentView.addGestureRecognizer(tapGesture)
        
    }

    @objc private func handleTap() {
        didTapAction?()
    }

    override func setSelected(_ selected: Bool, animated: Bool) {
        super.setSelected(selected, animated: animated)

        // Configure the view for the selected state
    }
    
}
