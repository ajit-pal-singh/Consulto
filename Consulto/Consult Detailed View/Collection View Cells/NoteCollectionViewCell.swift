import UIKit

class NoteCollectionViewCell: UICollectionViewCell {
    
    @IBOutlet weak var noteLabel: UILabel!
    @IBOutlet weak var noteCardView: UIView!
    
    override func awakeFromNib() {
        super.awakeFromNib()
        
        // Clear cell backgrounds so noteCardView's rounded corners show through
        self.backgroundColor = .clear
        contentView.backgroundColor = .clear
        
        // Multiline text support
        noteLabel.numberOfLines = 0
        noteLabel.lineBreakMode = .byWordWrapping
        
        // Setup card view with corner radius — clipsToBounds is REQUIRED to show corners visually
        noteCardView.backgroundColor = .white
        noteCardView.layer.cornerRadius = 20
        noteCardView.clipsToBounds = true
        
        // Add subtle shadow on the outer cell layer (not the card view, which has clipsToBounds)
        self.layer.shadowColor = UIColor.black.cgColor
        self.layer.shadowOpacity = 0.05
        self.layer.shadowOffset = CGSize(width: 0, height: 2)
        self.layer.shadowRadius = 8
        self.layer.masksToBounds = false
        
        noteLabel.font = .systemFont(ofSize: noteLabel.font.pointSize, weight: .medium).rounded
    }
    
    func configure(with text: String) {
        noteLabel.text = text
    }
}
