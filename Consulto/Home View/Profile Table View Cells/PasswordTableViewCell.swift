//
//  PasswordTableViewCell.swift
//  Consulto
//
//  Created by Tevika Kumbhawat on 14/04/26.
//

import UIKit

class PasswordTableViewCell: UITableViewCell {
    
    @IBOutlet weak var titleLabel: UILabel!
    @IBOutlet weak var chevronImageView: UIImageView!

    override func awakeFromNib() {
        super.awakeFromNib()
        // Initialization code
    }

    override func setSelected(_ selected: Bool, animated: Bool) {
        super.setSelected(selected, animated: animated)

        // Configure the view for the selected state
    }
    
    func configure(title: String) {
        titleLabel.text = title
    }
    
}
