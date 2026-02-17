//
//  PublishedPostTextTableViewCell.swift
//  HandleApp
//
//  Created by SDC_USER on 17/02/26.
//

import UIKit

class PublishedPostTextTableViewCell: UITableViewCell {

    @IBOutlet weak var containerView: UIView!
    @IBOutlet weak var timeLabel: UILabel!
    @IBOutlet weak var dateLabel: UILabel!
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

    override func setSelected(_ selected: Bool, animated: Bool) {
        super.setSelected(selected, animated: animated)

        // Configure the view for the selected state
    }
    
    private static let dateFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateFormat = "MMM d"
        return formatter
    }()
    
    private static let timeFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateFormat = "h:mm a" // e.g., 6:49 AM
        return formatter
    }()
    
    func configure(with post: Post) {
        self.titleLabel.text = post.postHeading
            
            // Fix: Use 'captionLabel' instead of 'postLabel'
        self.captionLabel.text = post.fullCaption
        
        // 1. Handle Optional Platform Icon
        if let iconName = post.platformIconName {
            platformIconImageView.image = UIImage(named: iconName)
        } else {
            platformIconImageView.image = nil
        }
        
        
        // 3. Handle Schedule Date
        if let publishedDate = post.publishedAt {
            dateLabel.text = PublishedPostTextTableViewCell.dateFormatter.string(from: publishedDate)
            timeLabel.text = PublishedPostTextTableViewCell.timeFormatter.string(from: publishedDate)
        } else {
            dateLabel.text = "No Date"
            timeLabel.text = "--:--"
        }
    }
    
}
