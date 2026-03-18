import UIKit

class RecordDetailedViewController: UIViewController {

    // MARK: - Outlets

    // Top 40% Area
    @IBOutlet weak var recordImageView: UIImageView!

    // Bottom Details Area
    @IBOutlet weak var titleLabel: UILabel!
    @IBOutlet weak var facilityLabel: UILabel!
    @IBOutlet weak var typeLabel: UILabel!
    @IBOutlet weak var dateLabel: UILabel!
    @IBOutlet weak var summaryLabel: UILabel!

    @IBOutlet weak var overviewLabel: UILabel!

    @IBOutlet weak var summaryHeadingLabel: UILabel!

    // MARK: - Properties
    var record: HealthRecord?

    // Constraints
    @IBOutlet weak var imageViewWidthConstraint: NSLayoutConstraint!
    @IBOutlet weak var imageViewHeightConstraint: NSLayoutConstraint!
    @IBOutlet weak var imageContainerHeightConstraint: NSLayoutConstraint!

    override func viewDidLoad() {
        super.viewDidLoad()
        navigationItem.largeTitleDisplayMode = .never
        setupUI()
        configureData()
    }

    private func setupUI() {
        guard let imageView = recordImageView else { return }

        // Image Styling
        imageView.image = UIImage(named: "sample")  // Default sample image
        imageView.contentMode = .scaleAspectFit
        imageView.layer.cornerRadius = 16
        imageView.clipsToBounds = true

        // Shadow Check: Verify if shadow view already exists to avoid duplicates
        if let superview = imageView.superview,
            superview.subviews.first(where: { $0.tag == 999 }) == nil
        {

            let shadowView = UIView()
            shadowView.tag = 999  // Mark it to avoid re-adding
            shadowView.translatesAutoresizingMaskIntoConstraints = false
            shadowView.backgroundColor = .white  // Needed for shadow
            shadowView.layer.cornerRadius = 16

            // Subtle Shadow Configuration
            shadowView.layer.shadowColor = UIColor.black.cgColor
            shadowView.layer.shadowOpacity = 0.1
            shadowView.layer.shadowOffset = CGSize(width: 0, height: 0)
            shadowView.layer.shadowRadius = 12

            // Insert below imageView
            superview.insertSubview(shadowView, belowSubview: imageView)

            // Pin to edges of image view
            NSLayoutConstraint.activate([
                shadowView.topAnchor.constraint(equalTo: imageView.topAnchor),
                shadowView.bottomAnchor.constraint(equalTo: imageView.bottomAnchor),
                shadowView.leadingAnchor.constraint(equalTo: imageView.leadingAnchor),
                shadowView.trailingAnchor.constraint(equalTo: imageView.trailingAnchor),
            ])
        }

        // Font Styling
        titleLabel.font = .systemFont(ofSize: titleLabel.font.pointSize, weight: .regular).rounded
        facilityLabel.font =
            .systemFont(ofSize: facilityLabel.font.pointSize, weight: .regular).rounded
        typeLabel.font = .systemFont(ofSize: typeLabel.font.pointSize, weight: .regular).rounded
        dateLabel.font = .systemFont(ofSize: dateLabel.font.pointSize, weight: .regular).rounded
        summaryLabel.font =
            .systemFont(ofSize: summaryLabel.font.pointSize, weight: .regular).rounded
        summaryHeadingLabel.font =
            .systemFont(ofSize: summaryHeadingLabel.font.pointSize, weight: .bold).rounded
        overviewLabel.font =
            .systemFont(ofSize: overviewLabel.font.pointSize, weight: .bold).rounded
    }

    private func updateImageConstraints() {
        // Safe unwrap to prevent crash if outlets are disconnected
        guard let imageView = recordImageView, let image = imageView.image else { return }

        // Calculate aspect ratio
        let aspectRatio = image.size.width / image.size.height

        // Desired fixed dimension anchors (same logic as before for height-first sizing)
        let fixedHeight: CGFloat = UIScreen.main.bounds.height * 0.6
        var newWidth = fixedHeight * aspectRatio
        var newHeight = fixedHeight

        // Cap to screen bounds with padding
        let horizontalPadding: CGFloat = 40
        let verticalPadding: CGFloat = 40
        let maxWidth = UIScreen.main.bounds.width - horizontalPadding
        let maxHeight = UIScreen.main.bounds.height * 0.55 - verticalPadding  // keep image within top area comfortably

        // If width exceeds available, scale down both maintaining aspect
        if newWidth > maxWidth {
            newWidth = maxWidth
            newHeight = newWidth / aspectRatio
        }

        // If height exceeds available, scale down both maintaining aspect
        if newHeight > maxHeight {
            newHeight = maxHeight
            newWidth = newHeight * aspectRatio
        }

        // Apply constraints safely
        if let widthConstraint = imageViewWidthConstraint {
            widthConstraint.constant = max(0, newWidth)
            widthConstraint.priority = .required
        } else {
            print(
                "Warning: imageViewWidthConstraint is disconnected. Please reconnect it in Storyboard."
            )
        }

        if let heightConstraint = imageViewHeightConstraint {
            heightConstraint.constant = max(0, newHeight)
            heightConstraint.priority = .required
        } else {
            print(
                "Warning: imageViewHeightConstraint is disconnected. Please connect it to the image view height."
            )
        }

        // Update container (wrapper) height to follow image height
        if let containerHeight = imageContainerHeightConstraint {
            containerHeight.constant = max(0, newHeight)
            containerHeight.priority = .required
        } else {
            print(
                "Warning: imageContainerHeightConstraint is disconnected. Please connect it to the container view height."
            )
        }

        self.view.layoutIfNeeded()
    }

    private func configureData() {
        // Ensure image is set before calculating constraints
        updateImageConstraints()

        guard let record = record else { return }

        // Populate Text
        titleLabel.text = record.title
        facilityLabel.text = record.healthFacilityName
        summaryLabel.text = record.summary

        // Date
        let formatter = DateFormatter()
        formatter.dateFormat = "d MMM yyyy"
        if let date = record.documentDate ?? Optional(record.dateAdded) {
            dateLabel.text = formatter.string(from: date)
        }

        // Record Type & Color
        let typeText: String
        let themeColor: UIColor

        switch record.recordType {
        case .dischargeSummary:
            typeText = "Discharge"
            themeColor = UIColor(named: "DischargeSummaryColor") ?? .systemYellow
        case .labReport:
            typeText = "Lab Report"
            themeColor = UIColor(named: "ReportColor") ?? .systemRed
        case .prescription:
            typeText = "Prescription"
            themeColor = UIColor(named: "PrescriptionColor") ?? .systemBlue
        case .scan:
            typeText = "Scan"
            themeColor = UIColor(named: "ScanColor") ?? .systemPurple
        default:
            typeText = record.recordType.rawValue.capitalized
            themeColor = .darkGray
        }

        typeLabel.text = typeText
        typeLabel.text = typeText
        typeLabel.textColor = themeColor
    }
}
