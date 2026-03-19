import UIKit

class HeaderCollectionViewCell: UICollectionViewCell {

    @IBOutlet weak var blueCardView: UIView!
    @IBOutlet weak var titleLabel: UILabel!

    private var gradientLayer: CAGradientLayer?

    override func awakeFromNib() {
        super.awakeFromNib()
        
        // Shadow for the cell
        self.layer.shadowColor = UIColor.black.cgColor
        self.layer.shadowOffset = CGSize(width: 0, height: 2)
        self.layer.shadowOpacity = 0.08
        self.layer.shadowRadius = 10
        self.layer.masksToBounds = false

        titleLabel.font = .systemFont(ofSize: titleLabel.font.pointSize, weight: .semibold).rounded
        blueCardView.layer.cornerRadius = 20
        blueCardView.clipsToBounds = true
    }

    override func layoutSubviews() {
        super.layoutSubviews()
        blueCardView.layoutIfNeeded()

        if let inner = blueCardView.layer.sublayers?.first(where: { $0.name == "InnerShadowLayer" })
        {
            inner.frame = blueCardView.bounds
            inner.cornerRadius = blueCardView.layer.cornerRadius
        }

        applyGradient()
    }

    override func prepareForReuse() {
        super.prepareForReuse()
        titleLabel.text = nil
    }

    func configure(title: String) {
        titleLabel.text = title
    }

    private func applyGradient() {
        guard blueCardView.bounds.width > 0,
            blueCardView.bounds.height > 0
        else { return }

        if gradientLayer == nil {
            let gradient = CAGradientLayer()
            gradient.colors = [
                UIColor(hex: "5AA9FF")!.cgColor,
                UIColor(hex: "236CBE")!.cgColor,
            ]
            gradient.startPoint = CGPoint(x: 0.5, y: 0.0)
            gradient.endPoint = CGPoint(x: 0.5, y: 1.0)
            gradient.locations = [0.0, 1.0]

            blueCardView.layer.insertSublayer(gradient, at: 0)
            gradientLayer = gradient
        }
        gradientLayer?.frame = blueCardView.bounds
    }

    private func applyInnerShadow() {
        if blueCardView.layer.sublayers?.contains(where: { $0.name == "InnerShadowLayer" }) == true
        {
            return
        }

        let shadowLayer = CALayer()
        shadowLayer.name = "InnerShadowLayer"
        shadowLayer.frame = blueCardView.bounds
        shadowLayer.cornerRadius = blueCardView.layer.cornerRadius
        shadowLayer.masksToBounds = true

        let spread: CGFloat = 2
        let path = UIBezierPath(rect: shadowLayer.bounds.insetBy(dx: -spread, dy: -spread))
        let innerPath = UIBezierPath(rect: shadowLayer.bounds).reversing()
        path.append(innerPath)

        shadowLayer.shadowPath = path.cgPath
        shadowLayer.shadowColor = UIColor.white.cgColor
        shadowLayer.shadowOpacity = 0.35
        shadowLayer.shadowRadius = 7
        shadowLayer.shadowOffset = .zero

        blueCardView.layer.addSublayer(shadowLayer)
    }
}

extension UIColor {
    convenience init?(hex: String) {
        var hex = hex.trimmingCharacters(in: .whitespacesAndNewlines)
        hex = hex.replacingOccurrences(of: "#", with: "")

        guard hex.count == 6 else { return nil }

        var rgb: UInt64 = 0
        Scanner(string: hex).scanHexInt64(&rgb)

        self.init(
            red: CGFloat((rgb >> 16) & 0xFF) / 255,
            green: CGFloat((rgb >> 8) & 0xFF) / 255,
            blue: CGFloat(rgb & 0xFF) / 255,
            alpha: 1)
    }
}
