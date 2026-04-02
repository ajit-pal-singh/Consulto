//
//  SnoozeTableViewCell.swift
//  Consulto
//
//  Created by Tevika Kumbhawat on 30/03/26.
//

import UIKit

class SnoozeTableViewCell: UITableViewCell {
    
    @IBOutlet weak var titleLabel: UILabel!
    @IBOutlet weak var switchControl: UISwitch!
    
    var onSwitchChanged: ((Bool) -> Void)?

    override func awakeFromNib() {
        super.awakeFromNib()
        // Initialization code
    }
    
    @IBAction func switchChanged(_ sender: UISwitch) {
        onSwitchChanged?(sender.isOn)
    }

    override func setSelected(_ selected: Bool, animated: Bool) {
        super.setSelected(selected, animated: animated)

        // Configure the view for the selected state
    }
    
}
