//
//  PostTableViewCell.swift
//  OnboardingScreens
//
//  Created by SDC_USER on 25/11/25.
//

import UIKit
class PostTableViewCell: UITableViewCell {

    @IBOutlet weak var timeLabel: UILabel!
    @IBOutlet weak var postTextLabel: UILabel!
    @IBOutlet weak var platformIconImageView: UIImageView!
    @IBOutlet weak var thumbnailImageView: UIImageView!
    
    //Date and Time Formatter
    private static let timeFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateFormat = "h:mm a" 
        return formatter
    }()

    override func awakeFromNib() {
        super.awakeFromNib()
        thumbnailImageView.layer.cornerRadius = 8
        thumbnailImageView.clipsToBounds = true
        self.selectionStyle = .none
    }

    func configure(with post: Post) {
            // 1. Set Text
            postTextLabel.text = post.postText
            
            // 2. Set Time (Unwrap Optional Date)
            if let scheduleDate = post.scheduledAt {
                timeLabel.text = PostTableViewCell.timeFormatter.string(from: scheduleDate)
            } else {
                timeLabel.text = "" // or "Draft"
            }
            
            // 3. Set Platform Icon (Unwrap Optional String)
            if let iconName = post.platformIconName {
                platformIconImageView.image = UIImage(named: iconName)
            } else {
                platformIconImageView.image = nil
            }
            
            // 4. Set Image (Handle Array [String]?)
            // We take the FIRST image in the array for the thumbnail
            if let images = post.imageNames, let firstImage = images.first {
                thumbnailImageView.image = UIImage(named: firstImage)
            } else {
                // Optional: Set a placeholder if no image exists
                thumbnailImageView.image = nil
            }
        }
}
