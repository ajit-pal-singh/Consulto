//
//  IconDetailsTableViewCell.swift
//  Consulto
//
//  Created by Tevika Kumbhawat on 13/04/26.
//

import UIKit

class IconDetailsTableViewCell: UITableViewCell {

    @IBOutlet weak var iconImageView: UIImageView!
    @IBOutlet weak var titleLabel: UILabel!
    @IBOutlet weak var chevronImageView: UIImageView!

    override func awakeFromNib() {
        super.awakeFromNib()
        // Initialization code
    }

    override func setSelected(_ selected: Bool, animated: Bool) {
        super.setSelected(selected, animated: animated)
    }
    
    func configure(title: String, icon: UIImage?, tintColor: UIColor) {
        titleLabel.text = title
        iconImageView.image = icon
        iconImageView.tintColor = tintColor
    }
}
