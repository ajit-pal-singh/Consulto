//
//  ScheduleOptionsTableViewCell.swift
//  Consulto
//
//  Created by Tevika Kumbhawat on 30/03/26.
//

import UIKit

class ScheduleOptionsTableViewCell: UITableViewCell {

    @IBOutlet weak var titleLabel: UILabel!
    @IBOutlet weak var valueLabel: UILabel!
    @IBOutlet weak var chevronImageView: UIImageView!
    
    private let menuButton = UIButton(type: .system)
    var onTap: (() -> Void)?
    
    override func awakeFromNib() {
        super.awakeFromNib()
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

    override func setSelected(_ selected: Bool, animated: Bool) {
        super.setSelected(selected, animated: animated)

        // Configure the view for the selected state
    }

    func configure(title: String, value: String, actions: [UIAction]) {
        titleLabel.text = title
        valueLabel.text = value
        chevronImageView.isHidden = false
        menuButton.removeTarget(self, action: #selector(handleTap), for: .touchUpInside)
        menuButton.showsMenuAsPrimaryAction = true
        menuButton.menu = UIMenu(title: "", options: .displayInline, children: actions)
        menuButton.isUserInteractionEnabled = true
    }

    func configureStatic(title: String, value: String) {
        titleLabel.text = title
        valueLabel.text = value
        chevronImageView.isHidden = false
        menuButton.menu = nil
        menuButton.isUserInteractionEnabled = true
        menuButton.showsMenuAsPrimaryAction = false
        menuButton.removeTarget(self, action: #selector(handleTap), for: .touchUpInside)
        menuButton.addTarget(self, action: #selector(handleTap), for: .touchUpInside)
    }

    @objc private func handleTap() {
        onTap?()
    }
    
}
