//
//  TimeInputTableViewCell.swift
//  Consulto
//
//  Created by Tevika Kumbhawat on 01/04/26.
//

import UIKit

class TimeInputTableViewCell: UITableViewCell {

    @IBOutlet weak var timeTextField: UITextField!
    @IBOutlet weak var compactTimePicker: UIDatePicker!

    var didChangeTime: ((Date) -> Void)?
    private var displayFormat = "h:mm a"
    var showsShadow: Bool = true {
        didSet { updateShadowAppearance() }
    }

    override func awakeFromNib() {
        super.awakeFromNib()

        updateShadowAppearance()

        timeTextField.isUserInteractionEnabled = false
        timeTextField.isEnabled = false
        timeTextField.tintColor = .clear

        contentView.sendSubviewToBack(compactTimePicker)
        compactTimePicker.addTarget(self, action: #selector(timeChanged), for: .valueChanged)
        if #available(iOS 13.4, *) {
            compactTimePicker.preferredDatePickerStyle = .compact
        }
    }

    @objc private func timeChanged(_ sender: UIDatePicker) {
        didChangeTime?(sender.date)
        updateText(from: sender.date)
    }

    func configure(placeholder: String, time: Date? = nil, displayFormat: String = "h:mm a") {
        self.displayFormat = displayFormat
        timeTextField.placeholder = placeholder
        compactTimePicker.datePickerMode = .time

        if let time {
            setTime(time)
        } else {
            timeTextField.text = nil
        }
    }

    func setTime(_ time: Date) {
        compactTimePicker.date = time
        updateText(from: time)
    }

    private func updateText(from date: Date) {
        let formatter = DateFormatter()
        formatter.dateFormat = displayFormat
        timeTextField.text = formatter.string(from: date)
    }

    private func updateShadowAppearance() {
        layer.shadowColor = UIColor.black.cgColor
        layer.shadowOffset = CGSize(width: 0, height: 2)
        layer.shadowRadius = 10
        layer.masksToBounds = false
        layer.shadowOpacity = showsShadow ? 0.08 : 0
    }

    override func setSelected(_ selected: Bool, animated: Bool) {
        super.setSelected(selected, animated: animated)
    }
    
}
