//
//  AnalyticsViewController.swift
//  OnboardingScreens
//
//  Created by SDC_USER on 25/11/25.
//

import UIKit

class AnalyticsViewController: UIViewController {

    override func viewWillAppear(_ animated: Bool) {
            super.viewWillAppear(animated)
            // Bring back the Navigation Bar so we can see the Link Button!
            navigationController?.setNavigationBarHidden(false, animated: true)
            
            // Optional: Remove the text "Back" from the invisible back button so it doesn't mess up layout
            navigationItem.backButtonTitle = ""
        }
    
    override func viewDidLoad() {
        super.viewDidLoad()

        // Do any additional setup after loading the view.
        setupDesign()
        setupData()
            
            // Hides the back button so user can't go back to Login
        self.navigationItem.hidesBackButton = true
        
        let linkButton = UIBarButtonItem(image: UIImage(systemName: "link"), style: .plain, target: self, action: #selector(didTapManageConnections))
        self.navigationItem.rightBarButtonItem = linkButton
    }
    

    @objc func didTapManageConnections() {
        // We want to show the Auth Screen again, but as a "Popup" (Modal), not a push
        // We need to instantiate it from the Storyboard since it's not connected directly here
        let storyboard = UIStoryboard(name: "Analytics", bundle: nil)
        if let authVC = storyboard.instantiateViewController(withIdentifier: "AuthViewController") as? AuthViewController {
            
            // This makes it slide up from bottom
            authVC.modalPresentationStyle = .pageSheet
            
            // Present it
            self.present(authVC, animated: true, completion: nil)
        }
    }
    
    
    @IBAction func didTapHandleScoreInfo(_ sender: Any) {
        // Creates the popup
            let alert = UIAlertController(
                title: "What is Handle Score?",
                message: "Your Handle Score is calculated based on your posting consistency and growth.\n\nA score above 5% indicates healthy growth!\n\nIt’s calculated using the formula: Handle Rate (%) = ((Likes + 2 × Comments + 3 × Reposts) ÷ Impressions) × 100\n\nEach interaction type carries different weight to reflect its impact:\nLikes → quick appreciation\nComments → deeper engagement\nReposts/Shares → strong advocacy and content reach",
                preferredStyle: .alert
            )
            
            // Adds the "OK" button
            alert.addAction(UIAlertAction(title: "Got it", style: .default, handler: nil))
            
            // Shows it
            self.present(alert, animated: true, completion: nil)
    }
    
    
    
    @IBAction func didTapDismissSuggestion(_ sender: UIButton) {
        guard let cardView = sender.superview else { return }
                
                // 2. Animate it away
                UIView.animate(withDuration: 0.3) {
                    cardView.isHidden = true
                    cardView.alpha = 0
                }
                
                // 3. Show Red Toast
                showToast(message: "Suggestion Removed", isSuccess: false)
        
    }
    
    @IBAction func didTapApplySuggestion(_ sender: UITapGestureRecognizer) {
        guard let cardView = sender.view else { return }
                
                // 2. Animate it away
                UIView.animate(withDuration: 0.3) {
                    cardView.isHidden = true
                    cardView.alpha = 0
                }
                
                // 3. Show Green Toast
                showToast(message: "Applying Suggestion...", isSuccess: true)
    }
    
    // MARK: - Setup Functions
    func setupDesign() {
        // This ensures the styling is applied (if you aren't using the custom class)
        self.view.tintColor = UIColor.systemTeal
    }

    func setupData() {
        // This is a placeholder for where we will fetch API data later
        print("Data setup complete")
    }
    
    /*
    // MARK: - Navigation

    // In a storyboard-based application, you will often want to do a little preparation before navigation
    override func prepare(for segue: UIStoryboardSegue, sender: Any?) {
        // Get the new view controller using segue.destination.
        // Pass the selected object to the new view controller.
    }
     

     

     This helps you understand not just how many people saw your post, but how meaningfully they engaged with it.  (Note: Metrics may vary by platform — for example, LinkedIn doesn’t share engagement data for personal profiles.)
    */

    
    // MARK: - Toast Logic
    func showToast(message: String, isSuccess: Bool) {
        // 1. Create the container
        let toastView = UIView()
        toastView.backgroundColor = isSuccess ? UIColor.systemGreen : UIColor.systemRed
        toastView.alpha = 0.0
        toastView.layer.cornerRadius = 20
        toastView.clipsToBounds = true
        
        // 2. Create the label
        let label = UILabel()
        label.text = (isSuccess ? "✓ " : "✕ ") + message
        label.textColor = .white
        label.font = UIFont.boldSystemFont(ofSize: 14)
        label.textAlignment = .center
        
        // 3. Add to screen
        toastView.addSubview(label)
        self.view.addSubview(toastView) // Add to main view window
        
        // 4. Layout (Quick manual frames for animation simplicity)
        // Centered at top, width 200, height 40
        let screenWidth = self.view.frame.width
        toastView.frame = CGRect(x: (screenWidth - 200)/2, y: 60, width: 200, height: 40)
        label.frame = CGRect(x: 0, y: 0, width: 200, height: 40)
        
        // 5. Animate In & Out
        UIView.animate(withDuration: 0.3, animations: {
            toastView.alpha = 1.0
            toastView.frame.origin.y = 100 // Slide down slightly
        }) { _ in
            // Wait 2 seconds, then fade out
            UIView.animate(withDuration: 0.3, delay: 1.5, options: .curveEaseOut, animations: {
                toastView.alpha = 0.0
                toastView.frame.origin.y = 60 // Slide back up
            }) { _ in
                toastView.removeFromSuperview()
            }
        }
    }
    
    
    
    
    @IBAction func didTapInstagramScore(_ sender: UITapGestureRecognizer) {
        // Haptic feedback makes it feel "real"
                let generator = UIImpactFeedbackGenerator(style: .medium)
                generator.impactOccurred()

                // Create the popup
                let title = "Instagram Trend"
                let message = "Good job! Your score is 2.5% higher than last week! 🚀"
                    
                    // 3. Create the Popup (Action Sheet looks best for details)
                    let alert = UIAlertController(
                        title: title,
                        message: message,
                        preferredStyle: .actionSheet
                    )

                
                // Add "OK" button
                alert.addAction(UIAlertAction(title: "Awesome", style: .cancel))
        
        // 5. iPad Safety Fix (Prevents crashing on iPad)

        if let popover = alert.popoverPresentationController, let view = sender.view {
            popover.sourceView = view
            popover.sourceRect = view.bounds
        }
                
                // Present it
                self.present(alert, animated: true, completion: nil)
    }
    
    // MARK: - Posting Activity Actions
        
        @IBAction func didTapInstagramPosts(_ sender: UITapGestureRecognizer) {
            // 1. Haptic Feedback (Makes it feel responsive)
            let generator = UIImpactFeedbackGenerator(style: .medium)
            generator.impactOccurred()
            
            // 2. Define the message (Mock logic for the demo)
            // In the real app, you would check: if current > lastWeek { ... }
            let title = "Instagram Activity"
            let message = "You posted 5 more times than last week on Instagram! Consistency is key. 🚀"
            // Alternate message for testing:
            // "You posted 2 fewer times than last week. It's okay to take a break! 🌿"
            
            // 3. Create the Popup (Action Sheet looks best for details)
            let alert = UIAlertController(
                title: title,
                message: message,
                preferredStyle: .actionSheet
            )
            
            // 4. Add the "Close" button
            alert.addAction(UIAlertAction(title: "Keep it up", style: .cancel))
            
            // 5. iPad Safety Fix (Prevents crashing on iPad)
            if let popover = alert.popoverPresentationController, let view = sender.view {
                popover.sourceView = view
                popover.sourceRect = view.bounds
            }
            
            // 6. Show it
            self.present(alert, animated: true, completion: nil)
        }
    
}
