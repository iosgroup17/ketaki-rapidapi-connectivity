//
//  ScheduledPostsTableViewCell.swift
//  OnboardingScreens
//
//  Created by SDC_USER on 27/11/25.
//

import UIKit

class ScheduledPostsTableViewCell: UITableViewCell {

    @IBOutlet weak var dateTimeLabel: UILabel!
    @IBOutlet weak var platformIconImageView: UIImageView!
    @IBOutlet weak var postsLabel: UILabel!
    @IBOutlet weak var thumbnailImageView: UIImageView!
    
    override func awakeFromNib() {
        super.awakeFromNib()
        thumbnailImageView.layer.cornerRadius = 8
        thumbnailImageView.clipsToBounds = true
        self.selectionStyle = .none
    }
    
    // Date and time formatter
    private static let dateFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        formatter.timeStyle = .short
        return formatter
    }()
    
    func configure(with post: Post) {
        postsLabel.text = post.postText
        
        // 1. Handle Optional Platform Icon
        if let iconName = post.platformIconName {
            platformIconImageView.image = UIImage(named: iconName)
        } else {
            platformIconImageView.image = nil
        }
        
        // 2. Handle Image Array (Fix: 'imageName' -> 'imageNames')
        if let images = post.imageNames, let firstImage = images.first {
            thumbnailImageView.image = UIImage(named: firstImage)
        } else {
            thumbnailImageView.image = nil
        }
        
        // 3. Handle Schedule Date
        if let scheduledDate = post.scheduledAt {
            dateTimeLabel.text = ScheduledPostsTableViewCell.dateFormatter.string(from: scheduledDate)
        } else {
            dateTimeLabel.text = "No Date"
        }
    }
}
