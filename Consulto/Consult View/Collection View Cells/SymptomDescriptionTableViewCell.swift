import UIKit

class SymptomDescriptionTableViewCell: UITableViewCell, UITextViewDelegate {
    
    @IBOutlet weak var descriptionTextView: UITextView!
    
    var didChangeDescription: ((String) -> Void)?
    var placeholderText: String = "Description"
    var notesHeightConstraint: NSLayoutConstraint?
    
    override func awakeFromNib() {
        super.awakeFromNib()
        descriptionTextView?.delegate = self
        
        self.layer.shadowColor = UIColor.black.cgColor
        self.layer.shadowOffset = CGSize(width: 0, height: 2)
        self.layer.shadowOpacity = 0.08
        self.layer.shadowRadius = 10
        self.layer.masksToBounds = false
    }
    
    override func prepareForReuse() {
        super.prepareForReuse()
        placeholderText = "Description"
        notesHeightConstraint?.isActive = false
        notesHeightConstraint = nil
    }
    
    func textViewDidBeginEditing(_ textView: UITextView) {
        if textView.textColor == .systemGray3 && textView.text == placeholderText {
            textView.text = ""
            textView.textColor = .label
        }
    }
    
    func textViewDidChange(_ textView: UITextView) {
        didChangeDescription?(textView.text)
    }
    
    func textViewDidEndEditing(_ textView: UITextView) {
        if textView.text.isEmpty {
            textView.text = placeholderText
            textView.textColor = .systemGray3
        }
    }
}