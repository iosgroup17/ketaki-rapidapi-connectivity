//
//  SavedPostImageTableViewCell.swift
//  HandleApp
//
//  Created by SDC_USER on 11/02/26.
//

import UIKit

class SavedPostImageTableViewCell: UITableViewCell {

    @IBOutlet weak var containerView: UIView!
    @IBOutlet weak var captionLabel: UILabel!
    @IBOutlet weak var thumbnailImageView: UIImageView!
    @IBOutlet weak var titleLabel: UILabel!
    @IBOutlet weak var platformIconImageView: UIImageView!
    override func awakeFromNib() {
        super.awakeFromNib()
        // Initialization code
        thumbnailImageView.layer.cornerRadius = 8
        thumbnailImageView.clipsToBounds = true
        self.selectionStyle = .none
        containerView.layer.borderWidth = 0.3
        containerView.layer.cornerRadius = 8
        containerView.layer.borderColor = UIColor.systemGray.cgColor
    }
    
    func configure(with post: Post) {
            // Fix: Use 'titleLabel' instead of 'platformLabel'
        self.titleLabel.text = post.postHeading
            
            // Fix: Use 'captionLabel' instead of 'postLabel'
        self.captionLabel.text = post.fullCaption
        
            
            // 1. Handle the Platform Icon (matches your other cell's logic)
        if let iconName = post.platformIconName {
            platformIconImageView.image = UIImage(named: iconName)
        } else {
            platformIconImageView.image = nil
        }
        if let images = post.imageNames, let firstImage = images.first {
            self.thumbnailImageView.image = UIImage(named: firstImage)
        } else {
            self.thumbnailImageView.image = nil // Or a placeholder image
        }
    }
    
}
