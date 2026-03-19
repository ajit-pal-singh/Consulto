import UIKit

struct Consult {
    let title: String
    let date: String
    let symptoms: String
    let questions: String
}

class consultCollectionViewCell: UICollectionViewCell {
    
    @IBOutlet weak var cardView: UIView?
    @IBOutlet weak var doctorNameLabel: UILabel?
    @IBOutlet weak var titleLabel: UILabel?
    @IBOutlet weak var dateLabel: UILabel?
    @IBOutlet weak var symptomsLabel: UILabel?
    @IBOutlet weak var questionsLabel: UILabel?
    @IBOutlet weak var bottomBarView: UIView?
    
    override func awakeFromNib() {
        super.awakeFromNib()
        
        self.clipsToBounds = false
        self.contentView.clipsToBounds = false
        self.layer.masksToBounds = false
        
        doctorNameLabel?.font = .systemFont(ofSize: doctorNameLabel?.font.pointSize ?? 20, weight: .semibold).rounded
        titleLabel?.font = .systemFont(ofSize: titleLabel?.font.pointSize ?? 16, weight: .medium).rounded
        dateLabel?.font = .systemFont(ofSize: dateLabel?.font.pointSize ?? 13, weight: .medium).rounded
        symptomsLabel?.font = .systemFont(ofSize: symptomsLabel?.font.pointSize ?? 15, weight: .medium).rounded
        questionsLabel?.font = .systemFont(ofSize: questionsLabel?.font.pointSize ?? 15, weight: .medium).rounded

        if let cardView = cardView {
            cardView.layer.shadowColor = UIColor.black.cgColor
            cardView.layer.shadowOpacity = 0.08
            cardView.layer.shadowOffset = CGSize(width: 0, height: 2)
            cardView.layer.shadowRadius = 10
            cardView.layer.masksToBounds = false
        }
        
        bottomBarView?.layer.cornerRadius = 20
        bottomBarView?.layer.maskedCorners = [.layerMinXMaxYCorner, .layerMaxXMaxYCorner]
        bottomBarView?.clipsToBounds = true
    }

    func configure(with consult: ConsultSession) {

        doctorNameLabel!.text = consult.doctorName
        titleLabel!.text = consult.title
           let formatter = DateFormatter()
           formatter.dateFormat = "dd MMM yyyy"
           let formattedDate = formatter.string(from: consult.date)

           let symptomsCount = consult.symptomsCount
           let questionsCount = consult.questionsCount

        dateLabel!.text = "\(formattedDate)"

        symptomsLabel!.text = "\(symptomsCount) Symptoms"
        questionsLabel!.text = "\(questionsCount) Questions"
    }
    

}
