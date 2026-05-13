import UIKit

class EmptyHomeConsultCollectionViewCell: UICollectionViewCell {

    @IBOutlet weak var prepareConsultationView: UIView!
    @IBOutlet weak var createVisitView: UIView!
    @IBOutlet weak var cardView: UIView!
    @IBOutlet weak var headingLabel: UILabel!
    @IBOutlet weak var subheadingLabel: UILabel!
    @IBOutlet weak var prepareConsultationLabel: UILabel!
    @IBOutlet weak var createVisitLabel: UILabel!

    var onCreateVisitTapped: (() -> Void)?

    override func awakeFromNib() {
        super.awakeFromNib()
        backgroundColor = .clear
        contentView.backgroundColor = .clear
        
        cardView.layer.cornerRadius = 20
        cardView.clipsToBounds = true
        
        cardView.layer.shadowColor = UIColor.black.cgColor
        cardView.layer.shadowOffset = CGSize(width: 0, height: 2)
        cardView.layer.shadowOpacity = 0.08
        cardView.layer.shadowRadius = 10
        cardView.layer.masksToBounds = true
        
        headingLabel.font = .systemFont(ofSize: headingLabel.font.pointSize, weight: .bold).rounded
        subheadingLabel.font = .systemFont(ofSize: subheadingLabel.font.pointSize, weight: .medium).rounded
        prepareConsultationLabel.font = .systemFont(ofSize: prepareConsultationLabel.font.pointSize, weight: .medium).rounded
        createVisitLabel.font = .systemFont(ofSize: createVisitLabel.font.pointSize, weight: .medium).rounded
        
        setupViews()
    }
    
    override func layoutSubviews() {
        super.layoutSubviews()
        
        prepareConsultationView.layer.cornerRadius = prepareConsultationView.frame.height / 2
        createVisitView.layer.cornerRadius = createVisitView.frame.height / 2
        
        prepareConsultationView.clipsToBounds = true
        createVisitView.clipsToBounds = true
        
        // Find existing dashed border and update its frame
        if let dashedLayer = prepareConsultationView.layer.sublayers?.first(where: { $0.name == "dashedBorder" }) as? CAShapeLayer {
            dashedLayer.frame = prepareConsultationView.bounds
            dashedLayer.path = UIBezierPath(roundedRect: prepareConsultationView.bounds, cornerRadius: prepareConsultationView.frame.height / 2).cgPath
        }
        
        self.layer.shadowPath = UIBezierPath(
            roundedRect: bounds,
            cornerRadius: 20
        ).cgPath
    }

    private func setupViews() {
        
        prepareConsultationView.backgroundColor = .clear
        
        let dashedLayer = CAShapeLayer()
        dashedLayer.name = "dashedBorder"
        dashedLayer.strokeColor = UIColor.black.withAlphaComponent(0.5).cgColor
        dashedLayer.lineDashPattern = [4, 4]
        dashedLayer.fillColor = nil
        dashedLayer.lineWidth = 1
        prepareConsultationView.layer.addSublayer(dashedLayer)
        
        let tapGesture = UITapGestureRecognizer(target: self, action: #selector(createVisitAction))
        createVisitView.addGestureRecognizer(tapGesture)
        createVisitView.isUserInteractionEnabled = true
    }
    
    @objc private func createVisitAction() {
        onCreateVisitTapped?()
    }
}
