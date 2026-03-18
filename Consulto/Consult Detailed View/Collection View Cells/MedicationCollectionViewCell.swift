//
//  MedicationCollectionViewCell.swift
//  Consulto
//
//  Created by Tevika Kumbhawat on 16/03/26.
//

import UIKit

class MedicationCollectionViewCell: UICollectionViewCell {

    @IBOutlet weak var medicationCardView: UIView!
    @IBOutlet weak var iconImageView: UIImageView!
    @IBOutlet weak var nameLabel: UILabel!
    @IBOutlet weak var dosageLabel: UILabel!
    @IBOutlet weak var dotLabel: UILabel!
    @IBOutlet weak var frequencyLabel: UILabel!
    @IBOutlet weak var durationContainerView: UIView!
    @IBOutlet weak var durationLabel: UILabel!
    
    override func awakeFromNib() {
        super.awakeFromNib()
        setupUI()
    }
    
    private func setupUI() {
        medicationCardView.layer.cornerRadius = 12
        medicationCardView.backgroundColor = .white
        
        // Shadow for the cell
        self.layer.shadowColor = UIColor.black.cgColor
        self.layer.shadowOffset = CGSize(width: 0, height: 2)
        self.layer.shadowOpacity = 0.08
        self.layer.shadowRadius = 10
        self.layer.masksToBounds = false
        
        dotLabel.text = "•"
        dotLabel.textColor = .gray
        
        nameLabel.font = .systemFont(ofSize: nameLabel.font.pointSize, weight: .semibold).rounded
        dosageLabel.font = .systemFont(ofSize: dosageLabel.font.pointSize, weight: .medium).rounded
        frequencyLabel.font = .systemFont(ofSize: frequencyLabel.font.pointSize, weight: .medium).rounded
        durationLabel.font = .systemFont(ofSize: durationLabel.font.pointSize, weight: .medium).rounded

        durationContainerView.backgroundColor = UIColor(hex: "F0F9FF")
        durationLabel.textColor = UIColor(hex: "0679C6")
        durationContainerView.layer.cornerRadius = 4
        durationContainerView.clipsToBounds = true
    }

    func configure(name: String, dosage: String, frequency: String, duration: String) {
        nameLabel.text = name
        dosageLabel.text = dosage
        frequencyLabel.text = frequency
        durationLabel.text = duration

        // hide dot if any value missing
        dotLabel.isHidden = dosage.isEmpty || frequency.isEmpty
    }
}

