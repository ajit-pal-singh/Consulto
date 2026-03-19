//
//  ViewController.swift
//  Vital_Screen
//
//  Created by GEU on 16/03/26.
//

import UIKit
import SwiftUI

class ViewController: UIViewController, UINavigationControllerDelegate {

    @IBOutlet weak var headerActionsContainerView: UIView!
    @IBOutlet weak var vitalsCollectionView: UICollectionView!
    
    var vitalsData: [VitalReading] = []
    
    // MARK: - Platter Properties
    var platterViewController: AddReadingViewController?
    var overlayDimmingView: UIView?
    var platterBottomConstraint: NSLayoutConstraint?

    required init?(coder: NSCoder) {
        super.init(coder: coder)
        
        tabBarItem = UITabBarItem(
            title: "Vitals",
            image: UIImage(named: "Vitals"),
            selectedImage: UIImage(named: "Vitals")
        )
    }

    override func viewDidLoad() {
        super.viewDidLoad()
        
        self.title = "Vitals"
        self.tabBarItem.title = "Vitals"
        self.navigationController?.tabBarItem.title = "Vitals"
        
        navigationController?.delegate = self
        
        vitalsData = VitalData.generateMockData()
        
        setupCollectionView()
        setupHeaderActions()
    }
    
    func setupCollectionView() {
        // Safe to check if it's connected first, in case you build before connecting the outlet!
        guard let cv = vitalsCollectionView else { return }
        
        let nib = UINib(nibName: "VitalCardCell", bundle: nil)
        cv.register(nib, forCellWithReuseIdentifier: "VitalCardCell")
        cv.delegate = self
        cv.dataSource = self
        cv.backgroundColor = .clear
        cv.showsVerticalScrollIndicator = false
    }

    func setupHeaderActions() {
        guard let container = headerActionsContainerView else { return }
        
        // Clear any existing subviews
        container.subviews.forEach { $0.removeFromSuperview() }
        container.backgroundColor = .clear
        container.clipsToBounds = false // Allow shadows to flow out
        
        let swiftUIView = VitalsHeaderActionsView(
            onAddAction: { [weak self] in
                self?.showAddReadingPlatter()
            }
        )
        
        let hostingController = UIHostingController(rootView: swiftUIView)
        hostingController.view.backgroundColor = .clear
        hostingController.view.clipsToBounds = false // Allow shadows to flow out
        hostingController.view.translatesAutoresizingMaskIntoConstraints = false
        
        addChild(hostingController)
        container.addSubview(hostingController.view)
        
        NSLayoutConstraint.activate([
            hostingController.view.topAnchor.constraint(equalTo: container.topAnchor),
            hostingController.view.bottomAnchor.constraint(equalTo: container.bottomAnchor),
            hostingController.view.leadingAnchor.constraint(equalTo: container.leadingAnchor),
            hostingController.view.trailingAnchor.constraint(equalTo: container.trailingAnchor)
        ])
        
        hostingController.didMove(toParent: self)
    }

    // MARK: - Platter Presentation
    
    func showAddReadingPlatter() {
        let container = self.view! // Attach directly to the main view so its full screen!
        
        // 1. Create Dimming View
        let dimmingView = UIView()
        dimmingView.backgroundColor = UIColor.black.withAlphaComponent(0.3)
        dimmingView.alpha = 0
        dimmingView.translatesAutoresizingMaskIntoConstraints = false
        
        // Add Tap Gesture to Dismiss
        let tap = UITapGestureRecognizer(target: self, action: #selector(dismissPlatter))
        dimmingView.addGestureRecognizer(tap)
        
        container.addSubview(dimmingView)
        NSLayoutConstraint.activate([
            dimmingView.topAnchor.constraint(equalTo: container.topAnchor),
            dimmingView.leadingAnchor.constraint(equalTo: container.leadingAnchor),
            dimmingView.trailingAnchor.constraint(equalTo: container.trailingAnchor),
            dimmingView.bottomAnchor.constraint(equalTo: container.bottomAnchor)
        ])
        self.overlayDimmingView = dimmingView
        
        // 2. Instantiate View Controller from Storyboard
        let storyboard = UIStoryboard(name: "Vital", bundle: nil) // Update "Main" if your storyboard has a different name
        guard let platterVC = storyboard.instantiateViewController(withIdentifier: "AddReadingViewController") as? AddReadingViewController else {
            print("Could not instantiate AddReadingViewController")
            return
        }
        
        // Handle Platter Clicks
        platterVC.onHeartRateTap = { [weak self] in
            self?.dismissPlatter()
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                self?.presentAddReadingAlert(
                    title: "Heart Rate",
                    message: "Enter your current heart rate\nMeasure after sitting calmly for 1-2 minutes.",
                    placeholders: ["78"],
                    units: ["BPM"]
                )
            }
        }
        
        platterVC.onBloodPressureTap = { [weak self] in
            self?.dismissPlatter()
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                self?.presentAddReadingAlert(
                    title: "Blood Pressure",
                    message: "Enter your current blood pressure\nMeasure while seated with your arm resting at heart level.",
                    placeholders: ["Systolic", "Diastolic"],
                    units: ["mmHg", "mmHg"]
                )
            }
        }
        
        platterVC.onBloodGlucoseTap = { [weak self] in
            self?.dismissPlatter()
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                self?.presentAddReadingAlert(
                    title: "Blood Glucose",
                    message: "Enter your blood glucose level\nBest measured either fasting (8+ hours) or 2 hours post-meal.",
                    placeholders: ["98"],
                    units: ["mg/dL"]
                )
            }
        }
        
        platterVC.onBodyWeightTap = { [weak self] in
            self?.dismissPlatter()
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                self?.presentAddReadingAlert(
                    title: "Body Weight",
                    message: "Enter your current body weight\nFor best consistency, weigh yourself at the same time every day.",
                    placeholders: ["80.6"],
                    units: ["kg"]
                )
            }
        }
        
        platterVC.view.translatesAutoresizingMaskIntoConstraints = false
        
        addChild(platterVC)
        container.addSubview(platterVC.view)
        platterVC.didMove(toParent: self)
        
        // Add Pan Gesture for Swipe Down to dismiss
        let panGesture = UIPanGestureRecognizer(target: self, action: #selector(handlePlatterPan(_:)))
        platterVC.view.addGestureRecognizer(panGesture)
        
        self.platterViewController = platterVC
        
        // 3. Constraints (Start Off-Screen)
        let bottomConstraint = platterVC.view.bottomAnchor.constraint(equalTo: container.bottomAnchor, constant: 500) // Start below screen
        self.platterBottomConstraint = bottomConstraint
        
        NSLayoutConstraint.activate([
            platterVC.view.leadingAnchor.constraint(equalTo: container.leadingAnchor, constant: 5),
            platterVC.view.trailingAnchor.constraint(equalTo: container.trailingAnchor, constant: -5),
            bottomConstraint,
            // Height logic: We let the storyboard components size it naturally, but ensure it doesn't compress
        ])
        
        container.layoutIfNeeded() // Set initial state
        
        // 4. Animate In
        self.platterBottomConstraint?.constant = -5 // Float 5pt from bottom
        
        UIView.animate(withDuration: 0.5, delay: 0, usingSpringWithDamping: 0.8, initialSpringVelocity: 0.5, options: .curveEaseOut) {
            dimmingView.alpha = 1
            self.tabBarController?.tabBar.alpha = 0 // Hide Tab Bar if exists
            self.view.layoutIfNeeded()
        }
    }
    
    @objc func dismissPlatter() {
        guard let vc = platterViewController else { return }
        
        // Animate Out
        self.platterBottomConstraint?.constant = 500 // Move down
        
        UIView.animate(withDuration: 0.3, animations: {
            self.overlayDimmingView?.alpha = 0
            self.tabBarController?.tabBar.alpha = 1 // Show Tab Bar
            self.view.layoutIfNeeded()
        }) { _ in
            // Clean up
            self.overlayDimmingView?.removeFromSuperview()
            vc.willMove(toParent: nil)
            vc.view.removeFromSuperview()
            vc.removeFromParent()
            
            self.overlayDimmingView = nil
            self.platterViewController = nil
            self.platterBottomConstraint = nil
        }
    }
    
    @objc func handlePlatterPan(_ gesture: UIPanGestureRecognizer) {
        guard let view = gesture.view else { return }
        let translation = gesture.translation(in: view)
        let velocity = gesture.velocity(in: view)
        
        switch gesture.state {
        case .changed:
            // Only allow dragging down
            if translation.y > 0 {
                // Adjust for start position (-5) so it doesn't jump
                self.platterBottomConstraint?.constant = translation.y - 5
                // Fade out dimming view slightly as we drag down
                let progress = min(translation.y / 200, 1.0)
                self.overlayDimmingView?.alpha = 1 - progress
            }
            
        case .ended, .cancelled:
            // Threshold to dismiss: dragged down 150pt OR fast velocity down
            if translation.y > 150 || velocity.y > 1000 {
                dismissPlatter()
            } else {
                // Snap back to floating position
                self.platterBottomConstraint?.constant = -5
                UIView.animate(withDuration: 0.3, delay: 0, usingSpringWithDamping: 0.8, initialSpringVelocity: 0.5, options: .curveEaseOut) {
                    self.overlayDimmingView?.alpha = 1
                    self.view.layoutIfNeeded()
                }
            }
            
        default:
            break
        }
    }
    
    // MARK: - Generic UIAlertController Generator
    
    private func presentAddReadingAlert(title: String, message: String, placeholders: [String], units: [String]) {
        let alertController = UIAlertController(title: title, message: message, preferredStyle: .alert)
        
        // Add text fields for values
        for (index, placeholder) in placeholders.enumerated() {
            alertController.addTextField { textField in
                textField.placeholder = placeholder
                // Set appropriate keyboard type
                if placeholder.contains("Systolic") || placeholder.contains("Diastolic") {
                    textField.keyboardType = .numberPad
                } else if title.contains("Heart Rate") {
                    textField.keyboardType = .numberPad
                } else {
                    textField.keyboardType = .decimalPad
                }
                
                // Add unit label to the right side if provided
                if index < units.count {
                    let unitLabel = UILabel()
                    unitLabel.text = units[index]
                    unitLabel.font = UIFont.systemFont(ofSize: 14, weight: .regular)
                    unitLabel.textColor = .black
                    
                    // Create padding view
                    unitLabel.sizeToFit()
                    let paddingView = UIView(frame: CGRect(x: 0, y: 0, width: unitLabel.frame.width + 10, height: unitLabel.frame.height))
                    unitLabel.center = CGPoint(x: paddingView.frame.width / 2 - 5, y: paddingView.frame.height / 2)
                    paddingView.addSubview(unitLabel)
                    
                    textField.rightView = paddingView
                    textField.rightViewMode = .always
                }
            }
        }
        
        // Add Date Picker Field
        alertController.addTextField { textField in
            let formatter = DateFormatter()
            formatter.dateFormat = "dd-MM-yyyy"
            textField.text = formatter.string(from: Date())
            
            // Add a calendar icon to the right side!
            let iconImage = UIImage(systemName: "calendar")
            let iconView = UIImageView(image: iconImage)
            iconView.tintColor = .black
            iconView.contentMode = .scaleAspectFit
            iconView.frame = CGRect(x: 0, y: 0, width: 20, height: 20)
            
            let paddingView = UIView(frame: CGRect(x: 0, y: 0, width: 30, height: 20))
            paddingView.addSubview(iconView)
            
            // Critical setup: Ignore touches so tapping the calendar image falls through to the text field underneath to open the DatePicker!
            paddingView.isUserInteractionEnabled = false
            iconView.isUserInteractionEnabled = false
            
            textField.rightView = paddingView
            textField.rightViewMode = .always
            
            let datePicker = UIDatePicker()
            datePicker.datePickerMode = .date
            datePicker.maximumDate = Date()
            if #available(iOS 14.0, *) {
                datePicker.preferredDatePickerStyle = .wheels
            }
            
            // Update text field when date changes!
            datePicker.addAction(UIAction { _ in
                textField.text = formatter.string(from: datePicker.date)
            }, for: .valueChanged)
            
            textField.inputView = datePicker
        }
        
        // Cancel Action
        let cancelAction = UIAlertAction(title: "Cancel", style: .cancel) { _ in
            print("Cancelled \(title)")
        }
        
        // Add Reading Action
        let addAction = UIAlertAction(title: "Add Reading", style: .default) { _ in
            var values = [String]()
            for i in 0..<placeholders.count {
                values.append(alertController.textFields?[i].text ?? "")
            }
            let dateText = alertController.textFields?.last?.text ?? ""
            print("Added \(title): \(values.joined(separator: " / ")) on \(dateText)")
        }
        
        alertController.addAction(cancelAction)
        alertController.addAction(addAction)
        
        self.present(alertController, animated: true)
    }
    
    // MARK: - Navigation Handler
    func navigationController(_ navigationController: UINavigationController, willShow viewController: UIViewController, animated: Bool) {
        let isVitalsScreen = (viewController === self)
        navigationController.setNavigationBarHidden(isVitalsScreen, animated: animated)
    }
}

// MARK: - Collection View Setup
extension ViewController: UICollectionViewDelegate, UICollectionViewDataSource, UICollectionViewDelegateFlowLayout {
    
    func collectionView(_ collectionView: UICollectionView, numberOfItemsInSection section: Int) -> Int {
        return vitalsData.count
    }
    
    func collectionView(_ collectionView: UICollectionView, cellForItemAt indexPath: IndexPath) -> UICollectionViewCell {
        guard let cell = collectionView.dequeueReusableCell(withReuseIdentifier: "VitalCardCell", for: indexPath) as? VitalCardCell else {
            return UICollectionViewCell()
        }
        
        // Pass data and host chart
        cell.configure(with: vitalsData[indexPath.item])
        
        return cell
    }
    
    func collectionView(_ collectionView: UICollectionView, layout collectionViewLayout: UICollectionViewLayout, sizeForItemAt indexPath: IndexPath) -> CGSize {
        // Full width minus 20 margin on both sides
        let width = collectionView.bounds.width - 40
        return CGSize(width: width, height: 160)
    }
    
    func collectionView(_ collectionView: UICollectionView, layout collectionViewLayout: UICollectionViewLayout, insetForSectionAt section: Int) -> UIEdgeInsets {
        return UIEdgeInsets(top: 10, left: 20, bottom: 90, right: 20) // Bottom inset clear for the tab bar
    }
    

}
