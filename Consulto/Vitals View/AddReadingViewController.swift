import UIKit

class AddReadingViewController: UIViewController {

    @IBOutlet weak var option1View: UIView! // Heart Rate
    @IBOutlet weak var option2View: UIView! // Blood Pressure
    @IBOutlet weak var option3View: UIView! // Blood Glucose
    @IBOutlet weak var option4View: UIView! // Body Weight
    
    @IBOutlet weak var handleView: UIView!

    override func viewDidLoad() {
        super.viewDidLoad()
        setupUI()
        setupGestures()
    }
    
    private func setupUI() {
        view.layer.cornerRadius = 0
        view.clipsToBounds = true
        
        if let handle = handleView {
            handle.layer.cornerRadius = handle.frame.height / 2
        }
    }
    
    override func viewDidLayoutSubviews() {
        super.viewDidLayoutSubviews()
        
        let path = UIBezierPath()
        let width = view.bounds.width
        let height = view.bounds.height
        
        let topRadius: CGFloat = 30
        let bottomRadius: CGFloat = 55
        
        // Start top left
        path.move(to: CGPoint(x: 0, y: topRadius))
        path.addArc(withCenter: CGPoint(x: topRadius, y: topRadius), radius: topRadius, startAngle: .pi, endAngle: 3 * .pi / 2, clockwise: true)
        
        // Top right
        path.addLine(to: CGPoint(x: width - topRadius, y: 0))
        path.addArc(withCenter: CGPoint(x: width - topRadius, y: topRadius), radius: topRadius, startAngle: 3 * .pi / 2, endAngle: 2 * .pi, clockwise: true)
        
        // Bottom right
        path.addLine(to: CGPoint(x: width, y: height - bottomRadius))
        path.addArc(withCenter: CGPoint(x: width - bottomRadius, y: height - bottomRadius), radius: bottomRadius, startAngle: 0, endAngle: .pi / 2, clockwise: true)
        
        // Bottom left
        path.addLine(to: CGPoint(x: bottomRadius, y: height))
        path.addArc(withCenter: CGPoint(x: bottomRadius, y: height - bottomRadius), radius: bottomRadius, startAngle: .pi / 2, endAngle: .pi, clockwise: true)
        
        path.close()
        
        let maskLayer = CAShapeLayer()
        maskLayer.path = path.cgPath
        view.layer.mask = maskLayer
    }
    
    private func setupGestures() {
        [option1View, option2View, option3View, option4View].compactMap { $0 }.forEach {
            $0.isUserInteractionEnabled = true
        }
        
        // Add programmatic tap handlers for each option View
        option1View?.addGestureRecognizer(UITapGestureRecognizer(target: self, action: #selector(didTapHeartRate)))
        option2View?.addGestureRecognizer(UITapGestureRecognizer(target: self, action: #selector(didTapBloodPressure)))
        option3View?.addGestureRecognizer(UITapGestureRecognizer(target: self, action: #selector(didTapBloodGlucose)))
        option4View?.addGestureRecognizer(UITapGestureRecognizer(target: self, action: #selector(didTapBodyWeight)))
    }

    var onHeartRateTap: (() -> Void)?
    var onBloodPressureTap: (() -> Void)?
    var onBloodGlucoseTap: (() -> Void)?
    var onBodyWeightTap: (() -> Void)?
    
    @objc @IBAction func didTapHeartRate() {
        print("Tapped Heart Rate")
        onHeartRateTap?()
    }
    
    @objc @IBAction func didTapBloodPressure() {
        print("Tapped Blood Pressure")
        onBloodPressureTap?()
    }
    
    @objc @IBAction func didTapBloodGlucose() {
        print("Tapped Blood Glucose")
        onBloodGlucoseTap?()
    }
    
    @objc @IBAction func didTapBodyWeight() {
        print("Tapped Body Weight")
        onBodyWeightTap?()
    }
}
