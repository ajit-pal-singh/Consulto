//
//  OnboardingViewController.swift
//  Consulto
//
//  Created by Ajitpal Singh on 30/03/26.
//

import UIKit

class OnboardingViewController: UIViewController {
    
    // MARK: - Outlets
    @IBOutlet weak var nextButton: UIButton!
    @IBOutlet weak var collectionView: UICollectionView!
    
    // Dot indicators — connect these to your 4 dot UIViews in storyboard
    @IBOutlet weak var dot1: UIView!
    @IBOutlet weak var dot2: UIView!
    @IBOutlet weak var dot3: UIView!
    @IBOutlet weak var dot4: UIView!
    
    // MARK: - Properties
    private let activeColor = UIColor(red: 0x1A/255.0, green: 0x90/255.0, blue: 0xFF/255.0, alpha: 1.0) // #1A90FF
    private let inactiveColor = UIColor.lightGray
    
    private var currentPage = 0
    
    private struct Slide {
        let illustration: String
        let icon: String
        let title: String
        let body: String
    }
    
    private let slides: [Slide] = [
        Slide(
            illustration: "Record-illustration",
            icon: "Record-icon",
            title: "Instantly Organize Records",
            body: "Snap a photo or upload PDFs. Consulto automatically summarizes and structures your records, securely on your device with privacy and ease."
        ),
        Slide(
            illustration: "Prepare-illustration",
            icon: "Prepare-icon",
            title: "Walk Into Appointment Prepared",
            body: "Easily create personalized summaries for upcoming consultations. Define your symptoms, list questions, and select relevant records in advance."
        ),
        Slide(
            illustration: "Vitals-illustration",
            icon: "Vitals-icon",
            title: "Log Your Vitals",
            body: "Track important vitals to visualize your health trends over time, giving your doctor valuable context to make informed decisions during your visits."
        ),
        Slide(
            illustration: "Reminder-illustration",
            icon: "Reminder-icon",
            title: "Get Reminders",
            body: "Set up gentle reminders for your daily medications as needed and get notified when it's time for an upcoming consultation."
        )
    ]
    
    // MARK: - Lifecycle
    override func viewDidLoad() {
        super.viewDidLoad()
        
        // Hide navigation bar
        navigationController?.setNavigationBarHidden(true, animated: false)
        
        // Style next button as pill
        if nextButton.configuration != nil {
            nextButton.configuration?.cornerStyle = .capsule
        } else {
            nextButton.layer.cornerRadius = nextButton.bounds.height / 2
            nextButton.layer.masksToBounds = true
        }
        
        // Register XIB cell
        let nib = UINib(nibName: "OnboardingCollectionViewCell", bundle: nil)
        collectionView.register(nib, forCellWithReuseIdentifier: "OnboardingCell")
        
        collectionView.delegate = self
        collectionView.dataSource = self
        collectionView.isPagingEnabled = true
        collectionView.showsHorizontalScrollIndicator = false
        collectionView.backgroundColor = .clear
        
        // Set initial dot state
        updateDots(for: 0)
    }
    
    // MARK: - Dot Update
    private func updateDots(for page: Int) {
        let dots = [dot1, dot2, dot3, dot4]
        for (index, dot) in dots.enumerated() {
            dot?.backgroundColor = (index == page) ? activeColor : inactiveColor
        }
    }
    
    // MARK: - Actions
    @IBAction func nextButtonTapped(_ sender: UIButton) {
        if currentPage < slides.count - 1 {
            currentPage += 1
            let indexPath = IndexPath(item: currentPage, section: 0)
            collectionView.scrollToItem(at: indexPath, at: .centeredHorizontally, animated: true)
            updateDots(for: currentPage)
        } else {
            // Last page — navigate to login screen
            // performSegue(withIdentifier: "toLogin", sender: self)
            performSegue(withIdentifier: "LoginForm", sender: self)
        }
    }
}

// MARK: - UICollectionView DataSource & Delegate
extension OnboardingViewController: UICollectionViewDelegate, UICollectionViewDataSource, UICollectionViewDelegateFlowLayout {
    
    func collectionView(_ collectionView: UICollectionView, numberOfItemsInSection section: Int) -> Int {
        return slides.count
    }
    
    func collectionView(_ collectionView: UICollectionView, cellForItemAt indexPath: IndexPath) -> UICollectionViewCell {
        let cell = collectionView.dequeueReusableCell(withReuseIdentifier: "OnboardingCell", for: indexPath) as! OnboardingCollectionViewCell
        let slide = slides[indexPath.item]
        cell.setup(
            illustration: UIImage(named: slide.illustration),
            icon: UIImage(named: slide.icon),
            title: slide.title,
            body: slide.body
        )
        return cell
    }
    
    // Each cell fills the entire collection view
    func collectionView(_ collectionView: UICollectionView, layout collectionViewLayout: UICollectionViewLayout, sizeForItemAt indexPath: IndexPath) -> CGSize {
        return CGSize(width: collectionView.frame.width, height: collectionView.frame.height)
    }
    
    // No gap between cells
    func collectionView(_ collectionView: UICollectionView, layout collectionViewLayout: UICollectionViewLayout, minimumLineSpacingForSectionAt section: Int) -> CGFloat {
        return 0
    }
    
    // Update dots when user manually swipes
    func scrollViewDidEndDecelerating(_ scrollView: UIScrollView) {
        let page = Int(scrollView.contentOffset.x / scrollView.frame.width)
        currentPage = page
        updateDots(for: currentPage)
    }
}
