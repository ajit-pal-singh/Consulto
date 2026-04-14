import UIKit

class HomeSectionHeaderCollectionReusableView: UICollectionReusableView {

    @IBOutlet weak var titleLabel: UILabel!
    @IBOutlet weak var viewAllButton: UIButton!

    var onViewAllTapped: (() -> Void)?

    override func awakeFromNib() {
        super.awakeFromNib()
        titleLabel.font = .systemFont(ofSize: titleLabel.font.pointSize, weight: .semibold).rounded
    }

    override func prepareForReuse() {
        super.prepareForReuse()
        onViewAllTapped = nil
    }

    func configure(title: String, showsViewAll: Bool) {
        titleLabel.text = title
        viewAllButton.isHidden = !showsViewAll
        viewAllButton.isUserInteractionEnabled = showsViewAll

        guard showsViewAll else { return }

        let font = UIFont.systemFont(ofSize: 13, weight: .medium).rounded
        let color = UIColor(white: 0.33, alpha: 1)
        let symbolConfig = UIImage.SymbolConfiguration(pointSize: 8, weight: .semibold)

        var config = UIButton.Configuration.plain()
        config.title = "View All"
        config.image = UIImage(systemName: "chevron.right", withConfiguration: symbolConfig)
        config.imagePlacement = .trailing
        config.imagePadding = 3
        config.baseForegroundColor = color
        config.contentInsets = NSDirectionalEdgeInsets(top: 0, leading: 8, bottom: 0, trailing: 0)
        config.titleTextAttributesTransformer = UIConfigurationTextAttributesTransformer { incoming in
            var outgoing = incoming
            outgoing.font = font
            return outgoing
        }

        viewAllButton.configuration = config

        viewAllButton.configurationUpdateHandler = { button in
            var c = button.configuration ?? .plain()
            c.title = "View All"
            c.baseForegroundColor = color
            c.image = UIImage(systemName: "chevron.right", withConfiguration: symbolConfig)
            c.titleTextAttributesTransformer = UIConfigurationTextAttributesTransformer { incoming in
                var outgoing = incoming
                outgoing.font = font
                return outgoing
            }
            button.configuration = c
        }
    }

    @IBAction private func viewAllTapped(_ sender: UIButton) {
        onViewAllTapped?()
    }
}
