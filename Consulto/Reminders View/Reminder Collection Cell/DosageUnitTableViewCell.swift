import UIKit

class DosageUnitTableViewCell: UITableViewCell {
    
    @IBOutlet weak var dosageUnitField: UITextField!
    @IBOutlet weak var chevronImageView: UIImageView!
    
    let units = ["mg", "mcg", "g", "ml"]
    private let menuButton = UIButton(type: .system)

    override func awakeFromNib() {
        super.awakeFromNib()

        dosageUnitField.tintColor = .clear
        dosageUnitField.isUserInteractionEnabled = false
        setupMenuButton()
    }

    override func setSelected(_ selected: Bool, animated: Bool) {
        super.setSelected(selected, animated: animated)
        // Configure the view for the selected state
    }

    func configure(unit: String?, onSelect: @escaping (String) -> Void) {
        dosageUnitField.text = unit

        let actions = units.map { unit in
            UIAction(
                title: unit,
                state: dosageUnitField.text == unit ? .on : .off
            ) { _ in
                onSelect(unit)
            }
        }

        menuButton.menu = UIMenu(title: "", options: .displayInline, children: actions)
    }

    private func setupMenuButton() {
        menuButton.translatesAutoresizingMaskIntoConstraints = false
        menuButton.backgroundColor = .clear
        menuButton.showsMenuAsPrimaryAction = true

        contentView.addSubview(menuButton)

        NSLayoutConstraint.activate([
            menuButton.leadingAnchor.constraint(equalTo: contentView.leadingAnchor),
            menuButton.trailingAnchor.constraint(equalTo: contentView.trailingAnchor),
            menuButton.topAnchor.constraint(equalTo: contentView.topAnchor),
            menuButton.bottomAnchor.constraint(equalTo: contentView.bottomAnchor)
        ])
    }
}
