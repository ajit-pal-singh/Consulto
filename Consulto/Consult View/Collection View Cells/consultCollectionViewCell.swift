import UIKit

struct Consult {
    let title: String
    let date: String
    let symptoms: String
    let questions: String
}

class consultCollectionViewCell: UICollectionViewCell {
    
    @IBOutlet weak var chipsStackView: UIStackView!
    
    @IBOutlet weak var cardView: UIView?
    @IBOutlet weak var titleLabel: UILabel?
    @IBOutlet weak var dateLabel: UILabel?
    @IBOutlet weak var symptomsLabel: UILabel?
    @IBOutlet weak var questionsLabel: UILabel?
    
    override func awakeFromNib() {
        super.awakeFromNib()
        
        self.clipsToBounds = false
        self.contentView.clipsToBounds = false
        self.layer.masksToBounds = false
        
        titleLabel?.font = .systemFont(ofSize: titleLabel?.font.pointSize ?? 17, weight: .semibold).rounded
        dateLabel?.font = .systemFont(ofSize: dateLabel?.font.pointSize ?? 16, weight: .medium).rounded
        symptomsLabel?.font = .systemFont(ofSize: symptomsLabel?.font.pointSize ?? 16, weight: .medium).rounded
        questionsLabel?.font = .systemFont(ofSize: questionsLabel?.font.pointSize ?? 16, weight: .medium).rounded

        if let cardView = cardView {
            cardView.layer.shadowColor = UIColor.black.cgColor
            cardView.layer.shadowOpacity = 0.08
            cardView.layer.shadowOffset = CGSize(width: 0, height: 2)
            cardView.layer.shadowRadius = 10
            cardView.layer.masksToBounds = false
        }
    }

    func configure(with consult: ConsultSession) {

        titleLabel!.text = consult.title
        configureChips(symptoms: consult.symptoms)
           // Date formatting
           let formatter = DateFormatter()
           formatter.dateFormat = "dd MMM yyyy"
           let formattedDate = formatter.string(from: consult.date)

           let symptomsCount = consult.symptomsCount
           let questionsCount = consult.questionsCount

           // Middle line text
        dateLabel!.text = "\(formattedDate)"

        symptomsLabel!.text = "\(symptomsCount) Symptoms"
        questionsLabel!.text = "\(questionsCount) Questions"
    }
    
    func configureChips(symptoms: [Symptom]) {

        chipsStackView.arrangedSubviews.forEach { $0.removeFromSuperview() }
        
        guard !symptoms.isEmpty else { return }
        
        // Force layout to get accurate width
        self.layoutIfNeeded()
        var availableWidth = chipsStackView.frame.width
        if availableWidth == 0 {
            // Estimated width: Screen - Section Insets (32) - Cell Internal Padding (approx 32)
            availableWidth = UIScreen.main.bounds.width - 64
        }
        
        let spacing = chipsStackView.spacing
        
        func chipWidth(_ text: String) -> CGFloat {
            let font = UIFont.systemFont(ofSize: 14, weight: .medium)
            let size = (text as NSString).size(withAttributes: [.font: font])
            return ceil(size.width) + 24 // Padding
        }
        
        var chipsToDisplay: [(text: String, isMore: Bool)] = []
        
        // Check if all fit
        var totalW: CGFloat = 0
        var allFit = true
        for (i, symptom) in symptoms.enumerated() {
            let w = chipWidth(symptom.name)
            let gap = (i == 0) ? 0 : spacing
            if totalW + gap + w <= availableWidth {
                totalW += gap + w
            } else {
                allFit = false
                break
            }
        }
        
        if allFit {
            chipsToDisplay = symptoms.map { ($0.name, false) }
        } else {
            // Find max K that fits with adjustment for +N more chip
            var bestK = -1
            // Try k from count-1 down to 1
            for k in stride(from: symptoms.count - 1, through: 1, by: -1) {
                let remaining = symptoms.count - k
                let moreText = "+\(remaining) more"
                let moreW = chipWidth(moreText)
                
                var widthForK: CGFloat = 0
                for i in 0..<k {
                    widthForK += chipWidth(symptoms[i].name)
                    if i > 0 { widthForK += spacing }
                }
                
                if widthForK + spacing + moreW <= availableWidth {
                    bestK = k
                    break
                }
            }
            
            if bestK != -1 {
                for i in 0..<bestK {
                    chipsToDisplay.append((symptoms[i].name, false))
                }
                let remaining = symptoms.count - bestK
                chipsToDisplay.append(("+\(remaining) more", true))
            } else {
                // Fallback: Truncate first chip
                if symptoms.count > 1 {
                    let remaining = symptoms.count - 1
                    chipsToDisplay.append((symptoms[0].name, false))
                    chipsToDisplay.append(("+\(remaining) more", true))
                } else {
                    // Single item, just truncate it, no more chip
                    chipsToDisplay.append((symptoms[0].name, false))
                }
            }
        }
        
        for (text, isMore) in chipsToDisplay {
            let chip = makeChip(text: text, isMoreChip: isMore)
            
            chip.setContentHuggingPriority(.required, for: .horizontal)
            if isMore {
                chip.setContentCompressionResistancePriority(.required, for: .horizontal)
            } else {
                chip.setContentCompressionResistancePriority(.defaultHigh, for: .horizontal)
            }
            chipsStackView.addArrangedSubview(chip)
        }
        
        // Add Spacer
        let spacer = UIView()
        spacer.setContentHuggingPriority(.defaultLow, for: .horizontal)
        spacer.setContentCompressionResistancePriority(.defaultLow, for: .horizontal)
        spacer.translatesAutoresizingMaskIntoConstraints = false
        chipsStackView.addArrangedSubview(spacer)
    }

    private func makeChip(text: String, isMoreChip: Bool = false) -> UIView {

        let label = UILabel()
        label.text = text
        label.font = .systemFont(ofSize: 14, weight: .medium)
        label.textColor = isMoreChip ? .systemBlue : UIColor.systemBlue
        label.translatesAutoresizingMaskIntoConstraints = false

        let container = UIView()
        container.backgroundColor = isMoreChip
            ? UIColor.systemBlue.withAlphaComponent(0.1)
            : UIColor.systemBlue.withAlphaComponent(0.15)

        container.layer.cornerRadius = 16
        container.translatesAutoresizingMaskIntoConstraints = false

        container.addSubview(label)

        NSLayoutConstraint.activate([
            label.leadingAnchor.constraint(equalTo: container.leadingAnchor, constant: 12),
            label.trailingAnchor.constraint(equalTo: container.trailingAnchor, constant: -12),
            label.topAnchor.constraint(equalTo: container.topAnchor, constant: 8),
            label.bottomAnchor.constraint(equalTo: container.bottomAnchor, constant: -8)
        ])

        return container
    }

}
