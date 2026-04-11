import UIKit

class SummaryTableViewCell: UITableViewCell {

    @IBOutlet weak var cardView: UIView!
    @IBOutlet weak var summaryLabel: UILabel!

    override func awakeFromNib() {
        super.awakeFromNib()
        
        selectionStyle = .none
        self.backgroundColor = .clear
        contentView.backgroundColor = .clear
        
        summaryLabel.font = .systemFont(ofSize: 17, weight: .semibold).rounded
        summaryLabel.textColor = .darkGray
    }

    func configure(with text: String?) {
        summaryLabel.text = text
    }
}
