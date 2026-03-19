import UIKit

class SymptomNameTableViewCell: UITableViewCell {

    @IBOutlet weak var deleteButton: UIButton!
    @IBOutlet weak var nameTextField: UITextField!
    
    var didChangeName: ((String) -> Void)?
    var didTapDelete: (() -> Void)?
    
    override func awakeFromNib() {
        super.awakeFromNib()
        
        nameTextField?.addTarget(self, action: #selector(textChanged), for: .editingChanged)
        deleteButton?.addTarget(self, action: #selector(deleteTapped), for: .touchUpInside)
    }
    
    @objc func textChanged(_ textField: UITextField) {
        didChangeName?(textField.text ?? "")
    }
    
    @objc func deleteTapped() {
        didTapDelete?()
    }

    override func setSelected(_ selected: Bool, animated: Bool) {
        super.setSelected(selected, animated: animated)

        // Configure the view for the selected state
    }
    
}
