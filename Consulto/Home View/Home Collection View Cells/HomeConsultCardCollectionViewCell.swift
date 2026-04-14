//
//  HomeConsultCardCollectionViewCell.swift
//  Consulto
//
//  Created by Tevika Kumbhawat on 02/04/26.
//

import UIKit

class HomeConsultCardCollectionViewCell: UICollectionViewCell {

    @IBOutlet weak var cardView: UIView!
    @IBOutlet weak var nameLabel: UILabel!
    @IBOutlet weak var purposeLabel: UILabel!
    @IBOutlet weak var dateLabel: UILabel!
    @IBOutlet weak var timeLabel: UILabel!
    @IBOutlet weak var detailsContainerView: UIView!
    @IBOutlet weak var markDoneButton: UIButton!
    @IBOutlet weak var openSessionButton: UIButton!

    var onTapMarkDone: (() -> Void)?
    var onTapOpenSession: (() -> Void)?
    
    override func awakeFromNib() {
        super.awakeFromNib()
        backgroundColor = .clear
        contentView.backgroundColor = .clear
        
        cardView.layer.cornerRadius = 20
        
        nameLabel.font = .systemFont(ofSize: nameLabel.font.pointSize, weight: .semibold).rounded
        purposeLabel.font = .systemFont(ofSize: purposeLabel.font.pointSize, weight: .medium).rounded
        dateLabel.font = .systemFont(ofSize: dateLabel.font.pointSize, weight: .medium).rounded
        timeLabel.font = .systemFont(ofSize: timeLabel.font.pointSize, weight: .medium).rounded

        detailsContainerView.layer.cornerRadius = 16
        
        styleActionButton(markDoneButton,
                          backgroundColor: .white,
                          titleColor: .black)
        styleActionButton(openSessionButton,
                          backgroundColor: UIColor(hex: "6EBBE2"),
                          titleColor: .white)
        
        self.layer.shadowColor = UIColor.black.cgColor
        self.layer.shadowOffset = CGSize(width: 0, height: 2)
        self.layer.shadowOpacity = 0.08
        self.layer.shadowRadius = 10
        self.layer.masksToBounds = false
    }

    override func layoutSubviews() {
        super.layoutSubviews()
        cardView.layer.shadowPath = UIBezierPath(
            roundedRect: cardView.bounds,
            cornerRadius: cardView.layer.cornerRadius
        ).cgPath
    }

    override func prepareForReuse() {
        super.prepareForReuse()
        onTapMarkDone = nil
        onTapOpenSession = nil
    }

    private func styleActionButton(_ button: UIButton,
                                   backgroundColor: UIColor,
                                   titleColor: UIColor) {
        button.backgroundColor = backgroundColor
        button.setTitleColor(titleColor, for: .normal)
        button.titleLabel?.font = .systemFont(ofSize: 14, weight: .medium).rounded
        button.layer.cornerRadius = 18
        button.clipsToBounds = true
        button.contentEdgeInsets = UIEdgeInsets(top: 0, left: 12, bottom: 0, right: 12)
    }

    @IBAction func markDoneTapped(_ sender: Any) {
        onTapMarkDone?()
    }

    @IBAction func openSessionTapped(_ sender: Any) {
        onTapOpenSession?()
    }

}
