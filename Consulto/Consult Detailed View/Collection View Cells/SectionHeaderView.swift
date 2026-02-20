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
        // Initialization code
    }
    
    func configure(title: String) {
        titleLabel.text = title
    }
}
