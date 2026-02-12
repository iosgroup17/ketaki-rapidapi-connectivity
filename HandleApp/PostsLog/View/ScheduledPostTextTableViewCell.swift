//
//  ScheduledPostTextTableViewCell.swift
//  HandleApp
//
//  Created by SDC_USER on 11/02/26.
//

import UIKit

class ScheduledPostTextTableViewCell: UITableViewCell {

    @IBOutlet weak var containerView: UIView!
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
    
    private static let dateFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        formatter.timeStyle = .short
        return formatter
    }()
    func configure(with post: Post) {
        captionLabel.text = post.postText
        
        // 1. Handle Optional Platform Icon
        if let iconName = post.platformIconName {
            platformIconImageView.image = UIImage(named: iconName)
        } else {
            platformIconImageView.image = nil
        }
        
        
        // 3. Handle Schedule Date
        if let scheduledDate = post.scheduledAt {
            dateLabel.text = ScheduledPostTextTableViewCell.dateFormatter.string(from: scheduledDate)
        } else {
            dateLabel.text = "No Date"
        }
    }
    
}
