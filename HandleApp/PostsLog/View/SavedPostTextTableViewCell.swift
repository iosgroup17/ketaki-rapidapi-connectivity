//
//  SavedPostTextTableViewCell.swift
//  HandleApp
//
//  Created by SDC_USER on 11/02/26.
//

import UIKit

class SavedPostTextTableViewCell: UITableViewCell {

    @IBOutlet weak var containerView: UIView!
    @IBOutlet weak var captionLabel: UILabel!
    @IBOutlet weak var titleLabel: UILabel!
    @IBOutlet weak var platformIconImageView: UIImageView!
    override func awakeFromNib() {
        super.awakeFromNib()
        // Initialization code
        self.selectionStyle = .none
        containerView.layer.borderWidth = 0.3
        containerView.layer.cornerRadius = 8
        containerView.layer.borderColor = UIColor.systemGray.cgColor
    }

    
    func configure(with post: Post) {
            // Fix: Use 'titleLabel' instead of 'platformLabel'
            
            // Fix: Use 'captionLabel' instead of 'postLabel'
        self.captionLabel.text = post.postText
            
            // 1. Handle the Platform Icon (matches your other cell's logic)
        if let iconName = post.platformIconName {
            platformIconImageView.image = UIImage(named: iconName)
        } else {
            platformIconImageView.image = nil
        }
    }
}
