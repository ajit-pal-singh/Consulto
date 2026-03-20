import UIKit

class DateInputTableViewCell: UITableViewCell {

    @IBOutlet weak var dateTextField: UITextField!
    @IBOutlet weak var compactDatePicker: UIDatePicker!

    var didChangeDate: ((Date) -> Void)?

    override func awakeFromNib() {
        super.awakeFromNib()

        self.layer.shadowColor = UIColor.black.cgColor
        self.layer.shadowOffset = CGSize(width: 0, height: 2)
        self.layer.shadowOpacity = 0.08
        self.layer.shadowRadius = 10
        self.layer.masksToBounds = false

        dateTextField.keyboardType = .numbersAndPunctuation

        compactDatePicker?.addTarget(self, action: #selector(dateChanged), for: .valueChanged)
        
        // Prevent selecting past dates
        compactDatePicker?.minimumDate = Calendar.current.startOfDay(for: Date())
    }

    @objc func dateChanged(_ sender: UIDatePicker) {
        didChangeDate?(sender.date)

        let formatter = DateFormatter()
        formatter.dateFormat = "dd-MM-yyyy"
        dateTextField?.text = formatter.string(from: sender.date)
    }

    func setDate(_ date: Date) {
        compactDatePicker?.date = date
        let formatter = DateFormatter()
        formatter.dateFormat = "dd-MM-yyyy"
        dateTextField?.text = formatter.string(from: date)
    }

    override func setSelected(_ selected: Bool, animated: Bool) {
        super.setSelected(selected, animated: animated)

        // Configure the view for the selected state
    }

}
