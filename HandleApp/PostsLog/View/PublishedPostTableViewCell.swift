//
//  PublishedPostTableViewCell.swift
//  OnboardingScreens
//
//  Created by SDC_USER on 27/11/25.
//

import UIKit

class PublishedPostTableViewCell: UITableViewCell {

    @IBOutlet weak var platformIconImageView: UIImageView!
    @IBOutlet weak var analyticsContainerView: UIView!
    @IBOutlet weak var engagementLabel: UILabel!
    @IBOutlet weak var viewsLabel: UILabel!
    @IBOutlet weak var repostsLabel: UILabel!
    @IBOutlet weak var sharesLabel: UILabel!
    @IBOutlet weak var commentsLabel: UILabel!
    @IBOutlet weak var likesLabel: UILabel!
    @IBOutlet weak var dateTimeLabel: UILabel!
    
    @IBOutlet weak var thumbnailImageView: UIImageView!
    @IBOutlet weak var postLabel: UILabel!
    @IBOutlet weak var analyticsHeightConstraint: NSLayoutConstraint!
    
    private let expandedHeight: CGFloat = 100
    
    override func awakeFromNib() {
        super.awakeFromNib()
        thumbnailImageView.layer.cornerRadius = 8
        thumbnailImageView.clipsToBounds = true
        self.selectionStyle = .none
    }
    
    // Date and Time Formatter
    private static let dateFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        formatter.timeStyle = .short
        return formatter
    }()
    
    func configure(with post: Post, isExpanded: Bool) {
        postLabel.text = post.postText
        
        // 1. Handle Optional Icon
        if let iconName = post.platformIconName {
            platformIconImageView.image = UIImage(named: iconName)
        } else {
            platformIconImageView.image = nil
        }
        
        // 2. Handle Image Array (Take the first image)
        if let images = post.imageNames, let firstImage = images.first {
            thumbnailImageView.image = UIImage(named: firstImage)
        } else {
            thumbnailImageView.image = nil
        }
        
        // 3. Handle Date
        if let publishDate = post.publishedAt {
            dateTimeLabel.text = PublishedPostTableViewCell.dateFormatter.string(from: publishDate)
        } else {
            dateTimeLabel.text = "Just now"
        }
        
        // 4. Metrics
        // Note: The unified 'Post' struct currently only has 'likes' and 'engagementScore'.
        // I have defaulted the others to "0" to prevent compiler errors.
        // If you want these back, add them to the Post struct in Post_Log_Model.swift.
        
        likesLabel.text = "\(post.likes ?? 0)"
        engagementLabel.text = String(format: "%.1f", post.engagementScore ?? 0.0)
        
        // Placeholders for missing struct properties
        commentsLabel.text = "0"
        sharesLabel.text = "0"
        repostsLabel.text = "0"
        viewsLabel.text = "0"
        
        // 5. Expansion Logic
        analyticsHeightConstraint.constant = isExpanded ? expandedHeight : 0
        analyticsContainerView.alpha = isExpanded ? 1.0 : 0.0
        
        // Update layout
        contentView.layoutIfNeeded()
    }

}
