import UIKit

class DateInputTableViewCell: UITableViewCell {

    @IBOutlet weak var dateTextField: UITextField!
    @IBOutlet weak var compactDatePicker: UIDatePicker!

    var didChangeDate: ((Date) -> Void)?
    private var displayFormat = "dd-MM-yyyy"
    var showsShadow: Bool = true {
        didSet { updateShadowAppearance() }
    }

    override func awakeFromNib() {
        super.awakeFromNib()

        updateShadowAppearance()

        dateTextField.isUserInteractionEnabled = false
        dateTextField.tintColor = .clear
        dateTextField.isEnabled = false
        contentView.sendSubviewToBack(compactDatePicker)
        compactDatePicker?.addTarget(self, action: #selector(dateChanged), for: .valueChanged)
    }

    @objc func dateChanged(_ sender: UIDatePicker) {
        didChangeDate?(sender.date)

        let formatter = DateFormatter()
        formatter.dateFormat = displayFormat
        dateTextField?.text = formatter.string(from: sender.date)
    }

    func setDate(_ date: Date) {
        compactDatePicker?.date = date
        let formatter = DateFormatter()
        formatter.dateFormat = displayFormat
        dateTextField?.text = formatter.string(from: date)
    }

    func clearDateText() {
        dateTextField?.text = nil
    }

    func configure(
        placeholder: String,
        date: Date? = nil,
        mode: UIDatePicker.Mode = .date,
        displayFormat: String = "dd-MM-yyyy"
    ) {
        self.displayFormat = displayFormat
        dateTextField.placeholder = placeholder
        compactDatePicker?.datePickerMode = mode

        if let date {
            setDate(date)
        } else {
            clearDateText()
        }
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

        // Configure the view for the selected state
    }

}
