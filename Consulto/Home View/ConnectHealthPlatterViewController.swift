import UIKit

class ConnectHealthPlatterViewController: UIViewController {

    var onConnectTap: (() -> Void)?
    var onDismiss: (() -> Void)?

    private let platterContainerView = UIView()
    private let grabberView = UIView()
    private let titleLabel = UILabel()
    private let descriptionLabel = UILabel()
    private let connectButton = UIButton(type: .system)
    private let healthImageView = UIImageView()

    override func viewDidLoad() {
        super.viewDidLoad()
        setupUI()
    }

    private func setupUI() {
        view.backgroundColor = .clear

        // Platter Container
        platterContainerView.backgroundColor = .clear
        platterContainerView.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(platterContainerView)

        // Glass Effect
        let blurEffect = UIBlurEffect(style: .systemUltraThinMaterial)
        let blurEffectView = UIVisualEffectView(effect: blurEffect)
        blurEffectView.frame = view.bounds
        blurEffectView.autoresizingMask = [.flexibleWidth, .flexibleHeight]
        blurEffectView.contentView.backgroundColor = UIColor(white: 1.0, alpha: 0.85)
        platterContainerView.insertSubview(blurEffectView, at: 0)

        // Grabber
        grabberView.backgroundColor = UIColor.secondaryLabel.withAlphaComponent(0.3)
        grabberView.layer.cornerRadius = 2.5
        grabberView.translatesAutoresizingMaskIntoConstraints = false
        platterContainerView.addSubview(grabberView)

        // Health Image
        let config = UIImage.SymbolConfiguration(pointSize: 60, weight: .regular)
        healthImageView.image = UIImage(systemName: "heart.text.square.fill", withConfiguration: config)
        healthImageView.tintColor = UIColor(hex: "#FF2D55")
        healthImageView.contentMode = .scaleAspectFit
        healthImageView.translatesAutoresizingMaskIntoConstraints = false
        platterContainerView.addSubview(healthImageView)

        // Title
        titleLabel.text = "Sync Your Health Data"
        titleLabel.font = UIFont.systemFont(ofSize: 22, weight: .bold)
        titleLabel.textColor = .label
        titleLabel.textAlignment = .center
        titleLabel.translatesAutoresizingMaskIntoConstraints = false
        platterContainerView.addSubview(titleLabel)

        // Description
        descriptionLabel.text = "Keep your vitals up to date by connecting Consulto with Apple Health. Easily track your Heart Rate and Resting Heart Rate."
        descriptionLabel.font = UIFont.systemFont(ofSize: 15, weight: .regular)
        descriptionLabel.textColor = .secondaryLabel
        descriptionLabel.textAlignment = .center
        descriptionLabel.numberOfLines = 0
        descriptionLabel.translatesAutoresizingMaskIntoConstraints = false
        platterContainerView.addSubview(descriptionLabel)

        // Connect Button
        var btnConfig = UIButton.Configuration.filled()
        btnConfig.title = "Connect to Apple Health"
        btnConfig.baseBackgroundColor = UIColor(hex: "#007AFF")
        btnConfig.baseForegroundColor = .white
        btnConfig.cornerStyle = .capsule
        btnConfig.contentInsets = NSDirectionalEdgeInsets(top: 14, leading: 20, bottom: 14, trailing: 20)
        connectButton.configuration = btnConfig
        connectButton.titleLabel?.font = UIFont.systemFont(ofSize: 17, weight: .semibold)
        connectButton.translatesAutoresizingMaskIntoConstraints = false
        connectButton.addTarget(self, action: #selector(connectTapped), for: .touchUpInside)
        platterContainerView.addSubview(connectButton)

        NSLayoutConstraint.activate([
            platterContainerView.topAnchor.constraint(equalTo: view.topAnchor),
            platterContainerView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            platterContainerView.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            platterContainerView.bottomAnchor.constraint(equalTo: view.bottomAnchor),

            grabberView.topAnchor.constraint(equalTo: platterContainerView.topAnchor, constant: 12),
            grabberView.centerXAnchor.constraint(equalTo: platterContainerView.centerXAnchor),
            grabberView.widthAnchor.constraint(equalToConstant: 36),
            grabberView.heightAnchor.constraint(equalToConstant: 5),

            healthImageView.topAnchor.constraint(equalTo: grabberView.bottomAnchor, constant: 30),
            healthImageView.centerXAnchor.constraint(equalTo: platterContainerView.centerXAnchor),
            healthImageView.widthAnchor.constraint(equalToConstant: 80),
            healthImageView.heightAnchor.constraint(equalToConstant: 80),

            titleLabel.topAnchor.constraint(equalTo: healthImageView.bottomAnchor, constant: 20),
            titleLabel.leadingAnchor.constraint(equalTo: platterContainerView.leadingAnchor, constant: 20),
            titleLabel.trailingAnchor.constraint(equalTo: platterContainerView.trailingAnchor, constant: -20),

            descriptionLabel.topAnchor.constraint(equalTo: titleLabel.bottomAnchor, constant: 12),
            descriptionLabel.leadingAnchor.constraint(equalTo: platterContainerView.leadingAnchor, constant: 24),
            descriptionLabel.trailingAnchor.constraint(equalTo: platterContainerView.trailingAnchor, constant: -24),

            connectButton.topAnchor.constraint(equalTo: descriptionLabel.bottomAnchor, constant: 30),
            connectButton.leadingAnchor.constraint(equalTo: platterContainerView.leadingAnchor, constant: 24),
            connectButton.trailingAnchor.constraint(equalTo: platterContainerView.trailingAnchor, constant: -24),
            connectButton.heightAnchor.constraint(equalToConstant: 52)
        ])
    }

    override func viewDidLayoutSubviews() {
        super.viewDidLayoutSubviews()
        let path = buildPlatterPath(for: platterContainerView.bounds)
        if let existingMask = platterContainerView.layer.mask as? CAShapeLayer {
            existingMask.path = path.cgPath
        } else {
            let maskLayer = CAShapeLayer()
            maskLayer.path = path.cgPath
            platterContainerView.layer.mask = maskLayer
        }
    }

    private func buildPlatterPath(for rect: CGRect) -> UIBezierPath {
        let topRadius: CGFloat = 24
        let bottomRadius: CGFloat = 55
        let width = rect.width
        let height = rect.height

        let path = UIBezierPath()
        path.move(to: CGPoint(x: 0, y: topRadius))
        path.addArc(withCenter: CGPoint(x: topRadius, y: topRadius), radius: topRadius, startAngle: .pi, endAngle: 3 * .pi / 2, clockwise: true)
        path.addLine(to: CGPoint(x: width - topRadius, y: 0))
        path.addArc(withCenter: CGPoint(x: width - topRadius, y: topRadius), radius: topRadius, startAngle: 3 * .pi / 2, endAngle: 0, clockwise: true)
        path.addLine(to: CGPoint(x: width, y: height - bottomRadius))
        path.addArc(withCenter: CGPoint(x: width - bottomRadius, y: height - bottomRadius), radius: bottomRadius, startAngle: 0, endAngle: .pi / 2, clockwise: true)
        path.addLine(to: CGPoint(x: bottomRadius, y: height))
        path.addArc(withCenter: CGPoint(x: bottomRadius, y: height - bottomRadius), radius: bottomRadius, startAngle: .pi / 2, endAngle: .pi, clockwise: true)
        path.close()
        return path
    }

    @objc private func connectTapped() {
        onConnectTap?()
    }
}
