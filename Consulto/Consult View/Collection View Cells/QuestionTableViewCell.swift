import UIKit

class QuestionTableViewCell: UITableViewCell, UITextViewDelegate {
    
    @IBOutlet weak var deleteButton: UIButton!
    @IBOutlet weak var questionTextView: UITextView!
    
    var didChangeText: ((String) -> Void)?
    var didTapDelete: (() -> Void)?
    
    override func awakeFromNib() {
        super.awakeFromNib()
        
        questionTextView?.delegate = self
        deleteButton?.addTarget(self, action: #selector(deleteTapped), for: .touchUpInside)
    }
    
    func textViewDidBeginEditing(_ textView: UITextView) {
        if textView.textColor == .systemGray3 && textView.text == "Question" {
            textView.text = ""
            textView.textColor = .label
        }
    }
    
    func textViewDidChange(_ textView: UITextView) {
        didChangeText?(textView.text)
    }
    
    func textViewDidEndEditing(_ textView: UITextView) {
        if textView.text.isEmpty {
            textView.text = "Question"
            textView.textColor = .systemGray3
        }
    }
    
    @objc func deleteTapped() {
        didTapDelete?()
    }
    
    override func setSelected(_ selected: Bool, animated: Bool) {
        super.setSelected(selected, animated: animated)
    }
}
