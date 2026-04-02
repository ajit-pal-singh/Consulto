import UIKit
class ConsultationTableViewCell: UITableViewCell {
    
    @IBOutlet weak var cardView: UIView!
    @IBOutlet weak var view: UIView!
    @IBOutlet weak var nameLabel: UILabel!
    @IBOutlet weak var dateLabel: UILabel!
    @IBOutlet weak var dotLabel: UILabel!
    @IBOutlet weak var timeLabel: UILabel!
    @IBOutlet weak var dot2Label: UILabel!
    @IBOutlet weak var purposeLabel: UILabel!
    @IBOutlet weak var toggleSwitch: UISwitch!
    
    var onToggleChanged: ((Bool) -> Void)?

    override func awakeFromNib() {
        super.awakeFromNib()
        
        contentView.backgroundColor = UIColor(hex: "F5F5F5")
        
        cardView.layer.cornerRadius = 20
        cardView.layer.shadowColor = UIColor.black.cgColor
        cardView.layer.shadowOffset = CGSize(width: 0, height: 4)
        cardView.layer.shadowOpacity = 0.04
        cardView.layer.shadowRadius = 10
        cardView.layer.masksToBounds = false
        view.layer.cornerRadius = 15
        
        nameLabel.font = .systemFont(ofSize: nameLabel.font.pointSize, weight: .semibold).rounded
        dateLabel.font = .systemFont(ofSize: dateLabel.font.pointSize, weight: .medium).rounded
        timeLabel.font = .systemFont(ofSize: timeLabel.font.pointSize, weight: .medium).rounded
        purposeLabel.font = .systemFont(ofSize: purposeLabel.font.pointSize, weight: .medium).rounded
    }
    
    @IBAction func switchChanged(_ sender: UISwitch) {
        onToggleChanged?(sender.isOn)
    }

    override func setSelected(_ selected: Bool, animated: Bool) {
        super.setSelected(selected, animated: animated)

        // Configure the view for the selected state
    }
    
}
