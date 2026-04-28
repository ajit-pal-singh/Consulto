import UIKit

class ViewController: UIViewController, UINavigationControllerDelegate {

    @IBOutlet weak var vitalsCollectionView: UICollectionView!
    @IBOutlet weak var blurEffectView: UIVisualEffectView!
    
    var vitalsData: [VitalReading] = []
    var shouldShowAddReadingPlatterOnAppear = false
    private let glucoseTypeOptions = ["Fasting", "Random", "After meal"]
    private weak var activeGlucoseTypeField: UITextField?
    var activeGlucoseFilterType: String = "Fasting"
    
    var platterViewController: AddReadingViewController?
    var overlayDimmingView: UIView?
    var platterBottomConstraint: NSLayoutConstraint?

    // MARK: - Actions
    @IBAction func addReadingButtonTapped(_ sender: Any) {
        showAddReadingPlatter()
    }

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
        
        vitalsData = VitalDataStore.shared.loadReadings()
        
        setupCollectionView()

        navigationItem.largeTitleDisplayMode = .never
        
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(handleGlucoseFilterChange(_:)),
            name: .glucoseFilterTypeDidChange,
            object: nil
        )
    }

    @objc private func handleGlucoseFilterChange(_ notification: Notification) {
        guard let type = notification.userInfo?["glucoseFilterType"] as? String else { return }
        activeGlucoseFilterType = type
        if let idx = vitalsData.firstIndex(where: { $0.title == "Blood Glucose" }) {
            let ip = IndexPath(item: idx, section: 0)
            vitalsCollectionView?.reloadItems(at: [ip])
        }
    }
    
    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        navigationController?.delegate = self
        navigationController?.setNavigationBarHidden(false, animated: animated)
        vitalsData = VitalDataStore.shared.loadReadings()
        vitalsCollectionView?.reloadData()
    }

    override func viewWillDisappear(_ animated: Bool) {
        super.viewWillDisappear(animated)
        if navigationController?.delegate === self {
            navigationController?.delegate = nil
        }
    }
    
    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)

        if shouldShowAddReadingPlatterOnAppear {
            shouldShowAddReadingPlatterOnAppear = false
            showAddReadingPlatter()
        }
    }

    func setupCollectionView() {
        guard let cv = vitalsCollectionView else { return }
        
        let nib = UINib(nibName: "VitalCardCell", bundle: nil)
        cv.register(nib, forCellWithReuseIdentifier: "VitalCardCell")
        cv.delegate = self
        cv.dataSource = self
        cv.backgroundColor = .clear
        cv.showsVerticalScrollIndicator = false
    }

    
    func showAddReadingPlatter() {
        let container = self.view! 
        
        let dimmingView = UIView()
        dimmingView.backgroundColor = UIColor.black.withAlphaComponent(0.3)
        dimmingView.alpha = 0
        dimmingView.translatesAutoresizingMaskIntoConstraints = false
        
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
        
        let storyboard = UIStoryboard(name: "Vital", bundle: nil) 
        guard let platterVC = storyboard.instantiateViewController(withIdentifier: "AddReadingViewController") as? AddReadingViewController else {
            print("Could not instantiate AddReadingViewController")
            return
        }
        
        platterVC.onHeartRateTap = { [weak self] in
            self?.dismissPlatter()
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                self?.presentAddReadingAlert(
                    title: "Heart Rate",
                    message: "Enter your current heart rate\nMeasure after sitting calmly for 1-2 minutes.",
                    placeholders: ["Enter Value"],
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
                    placeholders: ["Enter Systolic", "Enter Diastolic"],
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
                    placeholders: ["Enter Value"],
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
                    placeholders: ["Enter Value"],
                    units: ["kg"]
                )
            }
        }
        
        platterVC.view.translatesAutoresizingMaskIntoConstraints = false
        
        addChild(platterVC)
        container.addSubview(platterVC.view)
        platterVC.didMove(toParent: self)
        
        let panGesture = UIPanGestureRecognizer(target: self, action: #selector(handlePlatterPan(_:)))
        platterVC.view.addGestureRecognizer(panGesture)
        
        self.platterViewController = platterVC
        
        let bottomConstraint = platterVC.view.bottomAnchor.constraint(equalTo: container.bottomAnchor, constant: 500) 
        self.platterBottomConstraint = bottomConstraint
        
        NSLayoutConstraint.activate([
            platterVC.view.leadingAnchor.constraint(equalTo: container.leadingAnchor, constant: 5),
            platterVC.view.trailingAnchor.constraint(equalTo: container.trailingAnchor, constant: -5),
            bottomConstraint,
        ])
        
        container.layoutIfNeeded() 
        
        self.platterBottomConstraint?.constant = -5
        
        UIView.animate(withDuration: 0.5, delay: 0, usingSpringWithDamping: 0.8, initialSpringVelocity: 0.5, options: .curveEaseOut) {
            dimmingView.alpha = 1
            self.tabBarController?.tabBar.alpha = 0 
            self.view.layoutIfNeeded()
        }
    }
    
    @objc func dismissPlatter() {
        guard let vc = platterViewController else { return }
        
        self.platterBottomConstraint?.constant = 500 
        
        UIView.animate(withDuration: 0.3, animations: {
            self.overlayDimmingView?.alpha = 0
            self.tabBarController?.tabBar.alpha = 1 
            self.view.layoutIfNeeded()
        }) { _ in
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
            if translation.y > 0 {
                self.platterBottomConstraint?.constant = translation.y - 5
                let progress = min(translation.y / 200, 1.0)
                self.overlayDimmingView?.alpha = 1 - progress
            }
            
        case .ended, .cancelled:
            if translation.y > 150 || velocity.y > 1000 {
                dismissPlatter()
            } else {
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
    
    private func presentAddReadingAlert(title: String, message: String, placeholders: [String], units: [String]) {
        let alertController = UIAlertController(title: title, message: message, preferredStyle: .alert)
        let isBloodGlucose = title == "Blood Glucose"
        
        for (index, placeholder) in placeholders.enumerated() {
            alertController.addTextField { textField in
                textField.placeholder = placeholder
                textField.keyboardType = (title.contains("Heart Rate") || placeholder.contains("Systolic") || placeholder.contains("Diastolic")) ? .numberPad : .decimalPad
                
                if index < units.count {
                    let unitLabel = UILabel()
                    unitLabel.text = units[index]
                    unitLabel.font = .systemFont(ofSize: 14)
                    unitLabel.textColor = .label
                    unitLabel.sizeToFit()
                    let padding = UIView(frame: CGRect(x: 0, y: 0, width: unitLabel.frame.width + 10, height: unitLabel.frame.height))
                    unitLabel.center = CGPoint(x: padding.frame.width/2 - 5, y: padding.frame.height/2)
                    padding.addSubview(unitLabel)
                    textField.rightView = padding
                    textField.rightViewMode = .always
                }
            }
        }

        if isBloodGlucose {
            let typePicker = UIPickerView()
            typePicker.dataSource = self
            typePicker.delegate = self

            alertController.addTextField { [weak self] textField in
                guard let self = self else { return }
                textField.text = self.glucoseTypeOptions[0]
                textField.placeholder = "Select type"
                textField.tintColor = .clear
                self.activeGlucoseTypeField = textField

                let icon = UIImageView(image: UIImage(systemName: "chevron.down"))
                icon.tintColor = .secondaryLabel
                icon.contentMode = .scaleAspectFit
                icon.frame = CGRect(x: 0, y: 0, width: 20, height: 20)
                let pad = UIView(frame: CGRect(x: 0, y: 0, width: 28, height: 20))
                pad.addSubview(icon)
                textField.rightView = pad
                textField.rightViewMode = .always
                textField.inputView = typePicker
            }

            typePicker.selectRow(0, inComponent: 0, animated: false)
        }
        
        let datePicker = UIDatePicker()
        let timePicker = UIDatePicker()
        let dFormatter = DateFormatter(); dFormatter.dateFormat = "dd-MM-yyyy"
        let tFormatter = DateFormatter(); tFormatter.dateFormat = "hh:mm a"

        alertController.addTextField { textField in
            textField.text = dFormatter.string(from: Date())
            textField.tintColor = .clear
            
            textField.addAction(UIAction { [weak textField] _ in
                textField?.text = dFormatter.string(from: datePicker.date)
            }, for: .editingChanged)
            
            let icon = UIImageView(image: UIImage(systemName: "calendar"))
            icon.tintColor = .secondaryLabel; icon.contentMode = .scaleAspectFit
            icon.frame = CGRect(x: 0, y: 0, width: 20, height: 20)
            let pad = UIView(frame: CGRect(x: 0, y: 0, width: 28, height: 20)); pad.addSubview(icon)
            textField.rightView = pad; textField.rightViewMode = .always
            
            datePicker.datePickerMode = .date; datePicker.maximumDate = Date(); datePicker.preferredDatePickerStyle = .wheels
            datePicker.addAction(UIAction { _ in
                textField.text = dFormatter.string(from: datePicker.date)
                let isToday = Calendar.current.isDateInToday(datePicker.date)
                timePicker.maximumDate = isToday ? Date() : nil
                if isToday && timePicker.date > Date() { timePicker.setDate(Date(), animated: true) }
                let tIdx = placeholders.count + (isBloodGlucose ? 2 : 1)
                alertController.textFields?[tIdx].text = tFormatter.string(from: timePicker.date)
            }, for: .valueChanged)
            textField.inputView = datePicker
        }
        
        alertController.addTextField { textField in
            textField.text = tFormatter.string(from: Date())
            textField.tintColor = .clear
            textField.addAction(UIAction { [weak textField] _ in
                textField?.text = tFormatter.string(from: timePicker.date)
            }, for: .editingChanged)
            
            let icon = UIImageView(image: UIImage(systemName: "clock"))
            icon.tintColor = .secondaryLabel; icon.contentMode = .scaleAspectFit
            icon.frame = CGRect(x: 0, y: 0, width: 20, height: 20)
            let pad = UIView(frame: CGRect(x: 0, y: 0, width: 28, height: 20)); pad.addSubview(icon)
            textField.rightView = pad; textField.rightViewMode = .always
            
            timePicker.datePickerMode = .time; timePicker.preferredDatePickerStyle = .wheels
            timePicker.maximumDate = Date() 
            timePicker.addAction(UIAction { _ in
                textField.text = tFormatter.string(from: timePicker.date)
            }, for: .valueChanged)
            textField.inputView = timePicker
        }
        
        let cancelAction = UIAlertAction(title: "Cancel", style: .cancel)
        let addAction = UIAlertAction(title: "Add Reading", style: .default) { [weak self] _ in
            guard let self = self else { return }

            var vals = [String]()
            for i in 0..<placeholders.count { vals.append(alertController.textFields?[i].text ?? "") }

            let fields = alertController.textFields ?? []
            let glucoseTypeIndex = placeholders.count
            let dateFieldIndex = placeholders.count + (isBloodGlucose ? 1 : 0)
            let timeFieldIndex = dateFieldIndex + 1
            let glucoseType = isBloodGlucose ? (fields.count > glucoseTypeIndex ? fields[glucoseTypeIndex].text ?? self.glucoseTypeOptions[0] : self.glucoseTypeOptions[0]) : nil
            let dText = fields.count > dateFieldIndex ? fields[dateFieldIndex].text ?? "" : ""
            let tText = fields.count > timeFieldIndex ? fields[timeFieldIndex].text ?? "" : ""

            let dayLetter: String = {
                let df = DateFormatter()
                df.dateFormat = "dd-MM-yyyy"
                if let date = df.date(from: dText) {
                    let cal = Calendar.current
                    let weekdaySymbols = ["S", "M", "T", "W", "T", "F", "S"]
                    let idx = cal.component(.weekday, from: date) - 1
                    return weekdaySymbols[idx]
                }
                return "?"
            }()

            let recordedDate: Date = {
                let dateFmt = DateFormatter(); dateFmt.dateFormat = "dd-MM-yyyy"
                let timeFmt = DateFormatter(); timeFmt.dateFormat = "hh:mm a"
                timeFmt.locale = Locale(identifier: "en_US_POSIX")
                guard let d = dateFmt.date(from: dText),
                      let t = timeFmt.date(from: tText) else { return Date() }
                let cal = Calendar.current
                let tc = cal.dateComponents([.hour, .minute], from: t)
                return cal.date(bySettingHour: tc.hour ?? 0, minute: tc.minute ?? 0, second: 0, of: d) ?? Date()
            }()

            switch title {
            case "Heart Rate":
                let bpm = vals.first ?? ""
                VitalDataStore.shared.saveNewPoint(forTitle: title, value: bpm, day: dayLetter, recordedAt: recordedDate)

            case "Blood Pressure":
                let sys = vals.first ?? ""
                let dia = vals.count > 1 ? vals[1] : ""
                let combined = "\(sys)/\(dia)"
                let sysD = Double(sys) ?? 0
                let diaD = Double(dia) ?? 0
                VitalDataStore.shared.saveNewPoint(
                    forTitle: title, value: combined, day: dayLetter,
                    minValue: diaD, maxValue: sysD, recordedAt: recordedDate
                )

            case "Blood Glucose":
                let mg = vals.first ?? ""
                let subtitle = "\(glucoseType ?? self.glucoseTypeOptions[0]) Glucose"
                VitalDataStore.shared.saveNewPoint(
                    forTitle: title,
                    value: mg,
                    day: dayLetter,
                    recordedAt: recordedDate,
                    subtitleOverride: subtitle,
                    glucoseType: glucoseType
                )

            case "Body Weight":
                let kg = vals.first ?? ""
                VitalDataStore.shared.saveNewPoint(forTitle: title, value: kg, day: dayLetter, recordedAt: recordedDate)

            default:
                break
            }

            self.vitalsData = VitalDataStore.shared.loadReadings()
            self.vitalsCollectionView.reloadData()

            NotificationCenter.default.post(
                name: .vitalDataDidUpdate,
                object: nil,
                userInfo: [
                    "title": title,
                    "recordedAt": recordedDate
                ]
            )
        }
        
        alertController.addAction(cancelAction)
        alertController.addAction(addAction)
        
        alertController.preferredAction = addAction
        alertController.view.tintColor  = .systemBlue
        
        self.present(alertController, animated: true)
    }
    
    override func viewDidLayoutSubviews() {
        super.viewDidLayoutSubviews()
        
        if blurEffectView != nil {
           setupBlurGradientMask()
        }
    }
    
    func setupBlurGradientMask() {
        let gradientMask = CAGradientLayer()
        gradientMask.frame = blurEffectView.bounds
        
        gradientMask.colors = [
            UIColor.black.cgColor,      
            UIColor.black.cgColor,     
            UIColor.clear.cgColor      
        ]
        
        gradientMask.locations = [0.0, 0.8, 1.0] 
        
        blurEffectView.layer.mask = gradientMask
        
        if let existingOverlay = blurEffectView.layer.sublayers?.first(where: { $0.name == "SolidOverlay" }) {
            existingOverlay.frame = blurEffectView.bounds
        } else {
            let overlayLayer = CALayer()
            overlayLayer.name = "SolidOverlay"
            overlayLayer.frame = blurEffectView.bounds
            overlayLayer.backgroundColor = UIColor(hex: "#f5f5f5").withAlphaComponent(0.5).cgColor
            
            let overlayMask = CAGradientLayer()
            overlayMask.frame = overlayLayer.bounds
            overlayMask.colors = gradientMask.colors
            overlayMask.locations = gradientMask.locations
            overlayLayer.mask = overlayMask
            
            blurEffectView.layer.addSublayer(overlayLayer)
        }
    }
    
    func navigationController(_ navigationController: UINavigationController, willShow viewController: UIViewController, animated: Bool) {
        navigationController.setNavigationBarHidden(false, animated: animated)
    }
}

extension ViewController: UIPickerViewDataSource, UIPickerViewDelegate {
    func numberOfComponents(in pickerView: UIPickerView) -> Int {
        1
    }

    func pickerView(_ pickerView: UIPickerView, numberOfRowsInComponent component: Int) -> Int {
        glucoseTypeOptions.count
    }

    func pickerView(_ pickerView: UIPickerView, titleForRow row: Int, forComponent component: Int) -> String? {
        glucoseTypeOptions[row]
    }

    func pickerView(_ pickerView: UIPickerView, didSelectRow row: Int, inComponent component: Int) {
        activeGlucoseTypeField?.text = glucoseTypeOptions[row]
    }
}

extension ViewController: UICollectionViewDelegate, UICollectionViewDataSource, UICollectionViewDelegateFlowLayout {
    
    func collectionView(_ collectionView: UICollectionView, numberOfItemsInSection section: Int) -> Int {
        return vitalsData.count
    }
    
    func collectionView(_ collectionView: UICollectionView, cellForItemAt indexPath: IndexPath) -> UICollectionViewCell {
        guard let cell = collectionView.dequeueReusableCell(withReuseIdentifier: "VitalCardCell", for: indexPath) as? VitalCardCell else {
            return UICollectionViewCell()
        }
        
        let reading = vitalsData[indexPath.item]
        let filterType = reading.title == "Blood Glucose" ? activeGlucoseFilterType : nil
        cell.configure(with: reading, glucoseFilterType: filterType)
        
        return cell
    }
    
    func collectionView(_ collectionView: UICollectionView, layout collectionViewLayout: UICollectionViewLayout, sizeForItemAt indexPath: IndexPath) -> CGSize {
        let width = collectionView.bounds.width - 40
        return CGSize(width: width, height: 160)
    }
    
    func collectionView(_ collectionView: UICollectionView, layout collectionViewLayout: UICollectionViewLayout, insetForSectionAt section: Int) -> UIEdgeInsets {
        return UIEdgeInsets(top: 16, left: 20, bottom: 20, right: 20)
    }
    
    func collectionView(_ collectionView: UICollectionView, didSelectItemAt indexPath: IndexPath) {
        let selectedVital = vitalsData[indexPath.item]
        
        let storyboard = UIStoryboard(name: "Vital", bundle: nil)
        guard let detailVC = storyboard.instantiateViewController(withIdentifier: "VitalDetailViewController") as? VitalDetailViewController else {
            print("Could not instantiate VitalDetailViewController")
            return
        }
        
        detailVC.reading = selectedVital
        if selectedVital.title == "Blood Glucose" {
            detailVC.initialGlucoseFilterType = activeGlucoseFilterType
        }
        navigationController?.pushViewController(detailVC, animated: true)
    }
}
