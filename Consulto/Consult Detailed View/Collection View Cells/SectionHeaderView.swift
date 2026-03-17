//
//  SectionHeaderView.swift
//  ConsultSession
//
//  Created by geu on 05/02/26.
//

import UIKit

class SectionHeaderView: UICollectionReusableView {

    @IBOutlet weak var titleLabel: UILabel!
    
    override func awakeFromNib() {
        super.awakeFromNib()
        titleLabel.font = .systemFont(ofSize: titleLabel.font.pointSize, weight: .semibold).rounded
    }
    
    func configure(title: String) {
        titleLabel.text = title
    }
}
