import UIKit

class InfoTableViewCell: UITableViewCell {

    // MARK: - Outlets
    @IBOutlet weak var cardView: UIView!
    @IBOutlet weak var iconContainerView: UIView!
    @IBOutlet weak var iconImageView: UIImageView!
    @IBOutlet weak var topLabel: UILabel!
    @IBOutlet weak var bottomLabel: UILabel!

    override func awakeFromNib() {
        super.awakeFromNib()
        
        selectionStyle = .none
        self.backgroundColor = .clear
        contentView.backgroundColor = .clear

        
        // Setup font styles according to Figma (adjust weights visually)
        topLabel.font = .systemFont(ofSize: 12, weight: .regular).rounded
        bottomLabel.font = .systemFont(ofSize: 17, weight: .semibold).rounded
    }

    /// Call this from `tableView(_:cellForRowAt:)` to set all the data at once!
    func configure(topText: String, bottomText: String, iconName: String, themeColor: UIColor) {
        topLabel.text = topText
        bottomLabel.text = bottomText
        
        iconImageView.image = UIImage(systemName: iconName)
        iconImageView.tintColor = .white
        
        // Use a solid color for the background as shown in Figma
        iconContainerView.backgroundColor = themeColor
    }
}
