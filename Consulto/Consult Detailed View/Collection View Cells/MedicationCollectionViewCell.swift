//
//  MedicationCollectionViewCell.swift
//  ConsultSession
//
//  Created by geu on 06/02/26.
//

import UIKit

class MedicationCollectionViewCell: UICollectionViewCell {

//    @IBOutlet weak var medicationCardView: UIView!
//    @IBOutlet weak var iconImageView: UIImageView!
//    
//    @IBOutlet weak var nameLabel: UILabel!
//    @IBOutlet weak var doseLabel: UILabel!
//    @IBOutlet weak var dotLabel: UILabel!
//    @IBOutlet weak var frequencyLabel: UILabel!
//    @IBOutlet weak var durationContainerView: UIView!
//    @IBOutlet weak var durationLabel: UILabel!
    
    override func awakeFromNib() {
        super.awakeFromNib()
        setupUI()
    }
    
    private func setupUI() {
//        medicationCardView.layer.cornerRadius = 12
//        medicationCardView.backgroundColor = .white
        
//        dotLabel.text = "•"
//        dotLabel.textColor = .gray
//        
//        durationContainerView.backgroundColor = UIColor(hex: "F0F9FF")
//        durationLabel.textColor = UIColor(hex: "0679C6")
//        durationContainerView.layer.cornerRadius = 4
//        durationContainerView.clipsToBounds = true
    }

    func configure(name: String, dose: String, frequency: String, duration: String) {
//        nameLabel.text = name
//        doseLabel.text = dose
//        frequencyLabel.text = frequency
//        durationLabel.text = duration
//        
//        // hide dot if any value missing
//        dotLabel.isHidden = dose.isEmpty || frequency.isEmpty
    }
}
