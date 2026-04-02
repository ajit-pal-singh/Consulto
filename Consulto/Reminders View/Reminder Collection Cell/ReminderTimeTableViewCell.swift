//
//  ReminderTimeTableViewCell.swift
//  Consulto
//
//  Created by Tevika Kumbhawat on 30/03/26.
//

import UIKit

class ReminderTimeTableViewCell: UITableViewCell {
    
    @IBOutlet weak var timeLabel: UILabel!
    @IBOutlet weak var toggleSwitch: UISwitch!
    
    var didTapDelete: (() -> Void)?
    var onToggleChanged: ((Bool) -> Void)?

    override func awakeFromNib() {
        super.awakeFromNib()
        // Initialization code
    }
    
    @IBAction func deleteTapped() {
        didTapDelete?()
    }

    @IBAction func switchChanged(_ sender: UISwitch) {
        onToggleChanged?(sender.isOn)
    }

    override func setSelected(_ selected: Bool, animated: Bool) {
        super.setSelected(selected, animated: animated)

        // Configure the view for the selected state
    }
    
}
