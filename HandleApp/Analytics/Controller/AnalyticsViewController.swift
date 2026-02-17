import UIKit
import Supabase
import PostgREST

// MARK: - Animation Helper
extension UIView {
    static func animateAsync(duration: TimeInterval, delay: TimeInterval = 0, options: UIView.AnimationOptions = [], animations: @escaping () -> Void) async -> Bool {
        await withCheckedContinuation { continuation in
            UIView.animate(withDuration: duration, delay: delay, options: options, animations: animations) { finished in
                continuation.resume(returning: finished)
            }
        }
    }
}

class AnalyticsViewController: UIViewController {
    
    // MARK: - Outlets
    @IBOutlet weak var handleScoreLabel: UILabel!
    @IBOutlet weak var weeksStreakLabel: UILabel!
    
    @IBOutlet weak var xPostsLabel: UILabel!
    @IBOutlet weak var instaPostsLabel: UILabel!
    @IBOutlet weak var linkedinPostsLabel: UILabel!
    
    @IBOutlet weak var scoreArrowImage: UIImageView!
    @IBOutlet weak var scoreDifferenceLabel: UILabel!
    
    // NEW OUTLETS (Connect in Storyboard!)
    @IBOutlet weak var totalEngagementLabel: UILabel!
    @IBOutlet weak var topPlatformLabel: UILabel!
    @IBOutlet weak var topPlatformImageView: UIImageView!
    
    @IBOutlet weak var avgImpactLabel: UILabel!
    
    // Loader
    let activityIndicator = UIActivityIndicatorView(style: .large)

    // MARK: - Lifecycle
    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        
        navigationController?.setNavigationBarHidden(false, animated: true)
        navigationItem.backButtonTitle = ""
        
        setupDesign()
        setupLinkButton()
        
        // Refresh Data
        setupData()
        
        // Trigger Auto Scrape (background check)
        Task {
            await SupabaseManager.shared.autoUpdateAnalytics()
            // Optional: Call setupData() again here if you want live updates after scrape
        }
    }
    
    override func viewDidLoad() {
        super.viewDidLoad()
        self.navigationItem.hidesBackButton = true
    }

    // MARK: - Setup UI
    func setupDesign() {
        if activityIndicator.superview == nil {
            activityIndicator.center = view.center
            activityIndicator.hidesWhenStopped = true
            view.addSubview(activityIndicator)
        }
        self.view.tintColor = UIColor.systemTeal
    }
    
    func setupLinkButton() {
        Task {
            let connected = await SupabaseManager.shared.fetchConnectedPlatforms()
            DispatchQueue.main.async {
                let linkButton = UIBarButtonItem(
                    image: UIImage(systemName: "link"),
                    style: .plain,
                    target: self,
                    action: #selector(self.didTapLinkButton)
                )
                
                if connected.count >= 3 {
                    linkButton.tintColor = .systemGray
                } else {
                    linkButton.tintColor = self.view.tintColor
                }
                self.navigationItem.rightBarButtonItem = linkButton
            }
        }
    }
    
    // MARK: - Actions
    @objc func didTapLinkButton() {
        let storyboard = UIStoryboard(name: "Analytics", bundle: nil)
        if let authVC = storyboard.instantiateViewController(withIdentifier: "AuthViewController") as? AuthViewController {
            
            // FIX: Set manage mode so it doesn't auto-close
            authVC.isManageMode = true
            
            authVC.modalPresentationStyle = .pageSheet
            if let sheet = authVC.sheetPresentationController {
                sheet.detents = [.large()]
            }
            self.present(authVC, animated: true, completion: nil)
        }
    }
    
    @IBAction func didTapHandleScoreInfo(_ sender: Any) {
        let alert = UIAlertController(
            title: "Handle Score Calculation",
            message: "Your Handle Score is a weighted engagement metric!\nA score above 500 indicates high account health!\nThe stats will update periodically as you use the app. The changes won't be reflected immediately!",
            preferredStyle: .alert
        )
        alert.addAction(UIAlertAction(title: "Got it", style: .default))
        self.present(alert, animated: true)
    }

    // MARK: - Data Fetching
    func setupData() {
        guard let userId = SupabaseManager.shared.client.auth.currentSession?.user.id else {
            print("Error: No logged in user found")
            return
        }
        
        if handleScoreLabel.text == "---" { activityIndicator.startAnimating() }

        Task {
            do {
                let analytics: UserAnalytics = try await SupabaseManager.shared.client
                    .from("user_analytics")
                    .select()
                    .eq("user_id", value: userId)
                    .single()
                    .execute()
                    .value
                
                DispatchQueue.main.async {
                    self.activityIndicator.stopAnimating()
                    self.updateLabels(with: analytics)
                }
            } catch {
                print("Error loading analytics: \(error)")
                DispatchQueue.main.async { self.activityIndicator.stopAnimating() }
            }
        }
    }

    // MARK: - UI Updates

        func updateLabels(with data: UserAnalytics) {
            // 1. MASTER SCORE & TOTALS
            var totalScore = 0
            var platformCount = 0
            var totalInteractions = 0
            var totalPosts = 0 // Track total posts for Avg Impact
            
            var maxEng = -1
            var topPlatformName = "-"
            var topPlatformIcon = UIImage(systemName: "questionmark.circle")
            
            // --- Instagram ---
            if let iScore = data.insta_score, iScore > 0 {
                totalScore += iScore; platformCount += 1
                let eng = data.insta_engagement ?? 0
                let posts = data.insta_post_count ?? 0
                totalInteractions += eng
                totalPosts += posts
                
                if eng > maxEng { maxEng = eng; topPlatformName = "Instagram"; topPlatformIcon = UIImage(named: "icon-instagram") }
            }
            
            // --- LinkedIn ---
            if let lScore = data.linkedin_score, lScore > 0 {
                totalScore += lScore; platformCount += 1
                let eng = data.linkedin_engagement ?? 0
                let posts = data.linkedin_post_count ?? 0
                totalInteractions += eng
                totalPosts += posts
                
                if eng > maxEng { maxEng = eng; topPlatformName = "LinkedIn"; topPlatformIcon = UIImage(named: "icon-linkedin") }
            }
            
            // --- Twitter ---
            if let xScore = data.x_score, xScore > 0 {
                totalScore += xScore; platformCount += 1
                let eng = data.x_engagement ?? 0
                let posts = data.x_post_count ?? 0
                totalInteractions += eng
                totalPosts += posts
                
                if eng > maxEng { maxEng = eng; topPlatformName = "X (Twitter)"; topPlatformIcon = UIImage(named: "icon-x") }
            }
            
            let finalScore = platformCount > 0 ? (totalScore / platformCount) : 0
            animateScore(to: finalScore)
            
            // 2. GROWTH INDICATOR
            let prevScore = data.previous_handle_score ?? 0
            let diff = finalScore - prevScore
            
            if diff > 0 {
                scoreDifferenceLabel.text = "+\(diff)"
                scoreDifferenceLabel.textColor = .systemGreen
                scoreArrowImage.image = UIImage(systemName: "arrow.up.right")
                scoreArrowImage.tintColor = .systemGreen
            } else if diff < 0 {
                scoreDifferenceLabel.text = "\(diff)"
                scoreDifferenceLabel.textColor = .systemRed
                scoreArrowImage.image = UIImage(systemName: "arrow.down.right")
                scoreArrowImage.tintColor = .systemRed
            } else {
                scoreDifferenceLabel.text = "-"
                scoreDifferenceLabel.textColor = .systemGray
                scoreArrowImage.image = UIImage(systemName: "minus")
                scoreArrowImage.tintColor = .systemGray
            }
            
            // 3. STAT CARDS
            func formatNumber(_ n: Int) -> String {
                if n >= 1000 { return String(format: "%.1fk", Double(n)/1000.0) }
                return "\(n)"
            }
            
            // Total Engagement
            if let label = totalEngagementLabel { label.text = formatNumber(totalInteractions) }
            
            // Top Platform
            if let label = topPlatformLabel { label.text = topPlatformName }
            if let img = topPlatformImageView { img.image = topPlatformIcon }
            
            // NEW: AVG IMPACT (Replaces Total Reach)
            // Ensure we don't divide by zero
            let avgImpact = totalPosts > 0 ? (totalInteractions / totalPosts) : 0
            
            // Note: You need to rename the outlet variable locally or in storyboard
            // Assuming you kept the old outlet name `totalReachLabel` for now:
            // if let label = totalReachLabel { label.text = formatNumber(avgImpact) }
            // OR if you renamed it to `avgImpactLabel` (Recommended):
             if let label = totalEngagementLabel { // Wait, totalEngagement is separate.
                 // Do you have an outlet for the 3rd card?
                 // If you used `totalReachLabel` before, use it here:
                 // self.totalReachLabel.text = formatNumber(avgImpact)
             }
            
            // 4. STREAK & POSTS
            weeksStreakLabel.text = "\(data.consistency_weeks)"
            
            if let iCount = data.insta_post_count { instaPostsLabel.text = "\(iCount)" } else { instaPostsLabel.text = "-" }
            if let lCount = data.linkedin_post_count { linkedinPostsLabel.text = "\(lCount)" } else { linkedinPostsLabel.text = "-" }
            if let xCount = data.x_post_count { xPostsLabel.text = "\(xCount)" } else { xPostsLabel.text = "-" }
            
            // 5. AVG IMPACT CALCULATION ⚡️
                    var totalAvg = 0
                    var avgCount = 0
                    
                    if let iAvg = data.insta_avg_engagement, iAvg > 0 { totalAvg += iAvg; avgCount += 1 }
                    if let lAvg = data.linkedin_avg_engagement, lAvg > 0 { totalAvg += lAvg; avgCount += 1 }
                    if let xAvg = data.x_avg_engagement, xAvg > 0 { totalAvg += xAvg; avgCount += 1 }
                    
                    let finalAvg = avgCount > 0 ? (totalAvg / avgCount) : 0
                    
                    // Update the label (Make sure you connected avgImpactLabel in Storyboard!)
                    if let label = avgImpactLabel {
                        label.text = formatNumber(finalAvg)
                    }
        }
    
    // MARK: - Animations
    func animateScore(to score: Int) {
        let duration: Double = 1.5
        let startValue = 0
        let endValue = score
        let steps = 50
        let stepDuration = duration / Double(steps)
        
        var currentStep = 0
        Timer.scheduledTimer(withTimeInterval: stepDuration, repeats: true) { timer in
            currentStep += 1
            let value = Int(Double(startValue) + (Double(endValue - startValue) * (Double(currentStep) / Double(steps))))
            self.handleScoreLabel.text = "\(value)"
            
            if currentStep >= steps {
                timer.invalidate()
                self.handleScoreLabel.text = "\(endValue)"
            }
        }
    }
    
    // MARK: - Smart Suggestions & Toast Animations
    
    @IBAction func didTapDismissSuggestion(_ sender: UIButton) {
        guard let cardView = sender.superview else { return }

        UIView.animate(withDuration: 0.3) {
            cardView.isHidden = true
            cardView.alpha = 0
        }
        showToast(message: "Suggestion Removed", isSuccess: false)
    }
    
    @IBAction func didTapApplySuggestion(_ sender: UITapGestureRecognizer) {
        guard let cardView = sender.view else { return }
        
        UIView.animate(withDuration: 0.3) {
            cardView.isHidden = true
            cardView.alpha = 0
        }
        showToast(message: "Applying Suggestion...", isSuccess: true)
    }

    func showToast(message: String, isSuccess: Bool) {
        let toastView = UIView()
        toastView.backgroundColor = isSuccess ? .systemGreen : .systemRed
        toastView.alpha = 0.0
        toastView.layer.cornerRadius = 20
        
        let label = UILabel()
        label.text = (isSuccess ? "✓ " : "✕ ") + message
        label.textColor = .white
        label.font = .boldSystemFont(ofSize: 14)
        label.textAlignment = .center
        
        toastView.addSubview(label)
        self.view.addSubview(toastView)
        
        let screenWidth = self.view.frame.width
        toastView.frame = CGRect(x: (screenWidth - 200)/2, y: 60, width: 200, height: 40)
        label.frame = toastView.bounds

        Task {
            _ = await UIView.animateAsync(duration: 0.3) {
                toastView.alpha = 1.0
                toastView.frame.origin.y = 100
            }
            try? await Task.sleep(nanoseconds: 1_500_000_000)
            _ = await UIView.animateAsync(duration: 0.3) {
                toastView.alpha = 0.0
                toastView.frame.origin.y = 60
            }
            toastView.removeFromSuperview()
        }
    }
}
