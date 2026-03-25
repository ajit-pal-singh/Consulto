import UIKit
import FoundationModels
import QuickLook
import Photos
import PhotosUI
import UniformTypeIdentifiers

class PreviewViewController: UIViewController, PHPickerViewControllerDelegate, UIDocumentPickerDelegate, UIImagePickerControllerDelegate, UINavigationControllerDelegate {

    // MARK: - Outlets
    // Connect the table view from storyboard
    @IBOutlet weak var tableView: UITableView!
    @IBOutlet weak var platterContainerView: UIView?
    @IBOutlet weak var dimmingOverlayView: UIView?

    // MARK: - Data
    private var isSyncingAttachments = false
    var images: [UIImage] = [] {
        didSet {
            guard !isSyncingAttachments else { return }
            attachments = images.map { RecordAttachmentDraft.image($0) }
        }
    }
    var attachments: [RecordAttachmentDraft] = [] {
        didSet {
            isSyncingAttachments = true
            images = attachments.map(\.thumbnail)
            isSyncingAttachments = false
        }
    }
    
    // MARK: - State
    enum PreviewState {
        case pending 
        case processing
        case form
    }
    var currentState: PreviewState = .pending
    
    // Form State Tracking
    private var summaryText: String = ""
    private var extractedTitle: String = ""
    private var facilityNameText: String = ""
    private var dateString: String = ""
    private var extractionRecordType: String = "" // Optionally mapping the enum to String
    private var quickLookPreviewURLs: [URL] = []
    
    // MARK: - Platter State
    private var platterViewController: AttachmentPlatterViewController?
    private var platterBottomConstraint: NSLayoutConstraint?
    private var platterHeightConstraint: NSLayoutConstraint?

    // MARK: - Lifecycle
    override func viewDidLoad() {
        super.viewDidLoad()
        title = "Preview"
        setupTableView()
        
        platterContainerView?.isUserInteractionEnabled = false
        dimmingOverlayView?.alpha = 0
        dimmingOverlayView?.isHidden = true
        dimmingOverlayView?.isUserInteractionEnabled = false
    }
    
    override func viewDidLayoutSubviews() {
        super.viewDidLayoutSubviews()
        centerRowVertically(animated: false)
    }

    // MARK: - Setup
    private func setupTableView() {
        tableView.delegate = self
        tableView.dataSource = self
        // The prototype cell class is set in Storyboard — no register call needed.
        // Make sure the cell's class is set to PreviewMediaTableViewCell
        // and its reuse identifier is "PreviewMediaCell" in Storyboard.
        tableView.separatorStyle = .none
        
        // Register State 3 Form Cells
        tableView.register(UINib(nibName: "InputTextFieldTableViewCell", bundle: nil), forCellReuseIdentifier: "InputTextFieldCell")
        tableView.register(UINib(nibName: "DateInputTableViewCell", bundle: nil), forCellReuseIdentifier: "DateInputCell")
        tableView.register(UINib(nibName: "DropdownTableViewCell", bundle: nil), forCellReuseIdentifier: "DropdownCell")
        tableView.register(UINib(nibName: "SymptomDescriptionTableViewCell", bundle: nil), forCellReuseIdentifier: "SymptomDescriptionCell")
        
        // Globally dismiss any active keyboards or picker wheels when the user taps outside!
        let tap = UITapGestureRecognizer(target: self.view, action: #selector(UIView.endEditing))
        tap.cancelsTouchesInView = false
        view.addGestureRecognizer(tap)
    }
    
    /// Vertically centers the single row by adding a top content inset.
    private func centerRowVertically(animated: Bool = false) {
        // Use the VISIBLE height (between nav bar and tab bar), not the full bounds height
        let visibleHeight = tableView.safeAreaLayoutGuide.layoutFrame.height
        guard visibleHeight > 0 else { return }
        // The grouped table margins are 20pt per side (User updated CV constraints to match)
        let insetGroupedMargins: CGFloat = 40 // 20 + 20
        let cardWidth = tableView.bounds.width - insetGroupedMargins - (2 * 20)
        var cardHeight = (cardWidth * 4 / 3).rounded()
        if currentState != .pending {
            cardHeight -= 150
        }
        let rowHeight = cardHeight + PreviewMediaTableViewCell.pageNavigatorHeight
        
        // If we are in state 3, reset to scrolling with a clean +20 top padding from the nav bar
        if currentState == .form {
            if tableView.contentInset.top != 20 {
                let formInsets = UIEdgeInsets(top: 20, left: 0, bottom: 0, right: 0)
                if animated {
                    UIView.animate(withDuration: 0.5, delay: 0, options: .curveEaseInOut) {
                        self.tableView.contentInset = formInsets
                    }
                } else {
                    tableView.contentInset = formInsets
                }
            }
            return
        }
        
        // Push the row down so it sits in the middle of the visible area, shifted up by 40pt
        let calculatedInset = (visibleHeight - rowHeight) / 2
        let topInset = max(0, calculatedInset - 40)
        
        // Avoid unnecessary layout cycles if the inset hasn't changed
        if tableView.contentInset.top != topInset {
            let newInsets = UIEdgeInsets(top: topInset, left: 0, bottom: 0, right: 0)
            if animated {
                // Must match the 0.5s duration from the cell's batch updates
                UIView.animate(withDuration: 0.5, delay: 0, options: .curveEaseInOut) {
                    self.tableView.contentInset = newInsets
                }
            } else {
                tableView.contentInset = newInsets
            }
        }
    }

    // MARK: - Navigation Bar Actions
    @IBAction func addButtonTapped(_ sender: UIBarButtonItem) {
        guard currentState == .pending else {
            showToast(message: "You can add files only before processing.")
            return
        }
        showAttachmentPlatter()
    }

    @IBAction func confirmButtonTapped(_ sender: UIBarButtonItem) {
        guard let cell = tableView.cellForRow(at: IndexPath(row: 0, section: 0)) as? PreviewMediaTableViewCell,
              currentState == .pending else { return }
        
        currentState = .processing
        
        // Hide Navigation Actions (Add and Confirm)
        navigationItem.setRightBarButtonItems([], animated: true)
        
        // Update inset so it stays perfectly centered as the cell shrinks
        centerRowVertically(animated: true)
        
        // Trigger table view height re-calculation and animate it
        tableView.beginUpdates()
        tableView.endUpdates()
        
        // Trigger the collection view stacking, zooming, and status label animation
        cell.startProcessingAnimation()
        
        let startTime = Date()
        
        Task {
            var extractedData: FormDataExtraction? = nil
            var errorMessage: String? = nil
            
            do {
                let imageUploads = self.attachments.compactMap { attachment -> UIImage? in
                    guard attachment.fileType == .image else { return nil }
                    return attachment.image ?? attachment.thumbnail
                }
                let pdfUploads = self.attachments.compactMap { attachment -> URL? in
                    guard attachment.fileType == .pdf else { return nil }
                    return attachment.fileURL
                }
                extractedData = try await MedicalIntelligenceService.shared.extractData(from: imageUploads, pdfUploads: pdfUploads)
                if extractedData == nil {
                    errorMessage = "Content doesn't appear to be a medical record."
                }
            } catch {
                let errorText = String(describing: error)
                
                if errorText.contains("exceededContextWindowSize") {
                    errorMessage = "Text too large."
                } else if errorText.contains("guardrailViolation") || errorText.contains("refusal") {
                    errorMessage = "Model refused request."
                } else if errorText.contains("assetsUnavailable") || errorText.contains("unsupportedLanguageOrLocale") {
                    errorMessage = "Apple Intelligence not fully available yet."
                } else if errorText.contains("concurrentRequests") || errorText.contains("rateLimited") {
                    errorMessage = "Device is currently busy."
                } else if errorText.contains("decodingFailure") || errorText.contains("unsupportedGuide") {
                    errorMessage = "Failed to map extracted schema natively."
                } else {
                    errorMessage = "An unexpected extraction error occurred."
                }
            }
            
            let elapsed = Date().timeIntervalSince(startTime)
            let remainingWait = max(0, 3.0 - elapsed)
            
            if remainingWait > 0 {
                try? await Task.sleep(nanoseconds: UInt64(remainingWait * 1_000_000_000))
            }
            
            await MainActor.run {
                if let data = extractedData {
                    self.extractedTitle = data.title ?? ""
                    self.facilityNameText = data.facilityName ?? ""
                    self.dateString = data.dateString ?? ""
                    self.summaryText = data.summary ?? ""
                    self.extractionRecordType = Self.displayRecordType(data.recordType)
                }
                
                self.transitionToFormState()
                
                if let msg = errorMessage {
                    self.showToast(message: msg)
                }
            }
        }
    }

    private static func displayRecordType(_ type: RecordType?) -> String {
        guard let type else { return "" }
        return type.displayName
    }
    
    @objc func submitFormTapped() {
        guard currentState == .form else { return }

        navigationItem.rightBarButtonItem?.isEnabled = false
        view.endEditing(true)
        syncFormValuesFromVisibleCells()

        let title = sanitizedText(extractedTitle, fallback: "Untitled Record")
        let facilityName = optionalSanitizedText(facilityNameText)
        let summary = optionalSanitizedText(summaryText)
        let recordType = RecordType.fromDisplayName(extractionRecordType) ?? .other
        let documentDate = parsedDocumentDate(from: dateString)
        let attachmentsToSave = attachments

        DispatchQueue.global(qos: .userInitiated).async {
            do {
                try HealthRecordStore.shared.addRecord(
                    title: title,
                    recordType: recordType,
                    healthFacilityName: facilityName,
                    summary: summary,
                    documentDate: documentDate,
                    attachments: attachmentsToSave
                )

                DispatchQueue.main.async {
                    self.navigationController?.popViewController(animated: true)
                }
            } catch {
                DispatchQueue.main.async {
                    self.navigationItem.rightBarButtonItem?.isEnabled = true
                    self.showToast(message: "Unable to save record.")
                }
            }
        }
    }

    private func syncFormValuesFromVisibleCells() {
        if let titleCell = tableView.cellForRow(at: IndexPath(row: 0, section: 2)) as? InputTextFieldTableViewCell {
            extractedTitle = titleCell.inputTextField.text ?? extractedTitle
        }
        if let facilityCell = tableView.cellForRow(at: IndexPath(row: 0, section: 3)) as? InputTextFieldTableViewCell {
            facilityNameText = facilityCell.inputTextField.text ?? facilityNameText
        }
        if let dateCell = tableView.cellForRow(at: IndexPath(row: 0, section: 4)) as? DateInputTableViewCell {
            dateString = dateCell.dateTextField.text ?? dateString
        }
        if let dropdownCell = tableView.cellForRow(at: IndexPath(row: 0, section: 5)) as? DropdownTableViewCell {
            extractionRecordType = dropdownCell.dropdownTextField.text ?? extractionRecordType
        }
        if let summaryCell = tableView.cellForRow(at: IndexPath(row: 0, section: 6)) as? SymptomDescriptionTableViewCell {
            let text = summaryCell.descriptionTextView.text ?? ""
            summaryText = text == summaryCell.placeholderText ? "" : text
        }
    }

    private func sanitizedText(_ value: String, fallback: String) -> String {
        let trimmed = value.trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmed.isEmpty ? fallback : trimmed
    }

    private func optionalSanitizedText(_ value: String) -> String? {
        let trimmed = value.trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmed.isEmpty ? nil : trimmed
    }

    private func parsedDocumentDate(from value: String) -> Date? {
        let trimmed = value.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return nil }

        let formatter = DateFormatter()
        formatter.calendar = Calendar(identifier: .gregorian)
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.dateFormat = "dd-MM-yyyy"
        return formatter.date(from: trimmed)
    }

    private func transitionToFormState() {
        guard currentState == .processing else { return }
        currentState = .form
        
        // 1. Tell the top card to quickly hide its pulsing label
        if let cell = tableView.cellForRow(at: IndexPath(row: 0, section: 0)) as? PreviewMediaTableViewCell {
            cell.transitionToState3()
        }
        
        // 2. Animate inset strictly to 0 so we can comfortably scroll down the forms
        centerRowVertically(animated: true)
        
        // 3. Restore JUST the Confirm button! We use a nice checkmark or "Save" button natively
        // Adjust the custom view or image as per your application's setup
        let confirmItem = UIBarButtonItem(image: UIImage(systemName: "checkmark"), style: .done, target: self, action: #selector(submitFormTapped))
        navigationItem.setRightBarButtonItems([confirmItem], animated: true)
        
        // 4. Elegantly animate the 6 new form sections sliding in
        tableView.beginUpdates()
        let sections = IndexSet(integersIn: 1...6)
        tableView.insertSections(sections, with: .fade)
        tableView.endUpdates()
        
        // Optionally scroll slightly to give a hint they appeared
        // tableView.scrollToRow(at: IndexPath(row: 0, section: 1), at: .top, animated: true)
    }
}

// MARK: - UITableViewDelegate & DataSource
extension PreviewViewController: UITableViewDelegate, UITableViewDataSource {

    func numberOfSections(in tableView: UITableView) -> Int { 
        return currentState == .form ? 7 : 1
    }

    func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int { 
        return 1
    }
    
    // MARK: - Section Spacing
    func tableView(_ tableView: UITableView, heightForHeaderInSection section: Int) -> CGFloat {
        if currentState != .form { return UITableView.automaticDimension }
        
        // No spacing above preview card, overview title, or the first form field (Doctor's Name)
        if section == 0 || section == 1 || section == 2 { return 0.01 } 
        return 7
    }

    func tableView(_ tableView: UITableView, heightForFooterInSection section: Int) -> CGFloat {
        if currentState != .form { return UITableView.automaticDimension }
        
        // No spacing below preview card or overview title
        if section == 0 || section == 1 { return 0.01 }
        return 7
    }

    func tableView(_ tableView: UITableView, heightForRowAt indexPath: IndexPath) -> CGFloat {
        if indexPath.section > 0 { return UITableView.automaticDimension }
        
        // The grouped table margins are 20pt per side (User updated CV constraints to match)
        let insetGroupedMargins: CGFloat = 40 // 20 + 20
        // Collection view is pinned edge-to-edge inside the cell,
        // card width = CV width - (peek × 2)
        let cardWidth = tableView.bounds.width - insetGroupedMargins - (2 * 20)
        // 4:3 ratio (portrait)
        var cardHeight = (cardWidth * 4 / 3).rounded()
        
        // State 2 & 3: Expand by shrinking 150
        if currentState != .pending {
            cardHeight -= 150
        }
        
        // In State 3, the status label and navigation dots are hidden, so we remove the 66pt vertical void!
        if currentState == .form {
            return cardHeight + 20
        }
        
        return cardHeight + PreviewMediaTableViewCell.pageNavigatorHeight
    }

    func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        if indexPath.section == 0 {
            guard let cell = tableView.dequeueReusableCell(
                withIdentifier: "PreviewMediaCell",
                for: indexPath
            ) as? PreviewMediaTableViewCell else { return UITableViewCell() }
            let cardState: PreviewMediaTableViewCell.CardState
            switch currentState {
            case .pending:
                cardState = .pending
            case .processing:
                cardState = .processing
            case .form:
                cardState = .form
            }
            cell.configure(with: images, state: cardState)
            cell.onExpandTapped = { [weak self] index in
                self?.presentNativePreview(forAttachmentAt: index)
            }
            return cell
        } 
        else if indexPath.section == 1 {
            let cell = tableView.dequeueReusableCell(withIdentifier: "OverviewHeaderCell", for: indexPath)
            cell.selectionStyle = .none
            return cell
        }
        else if indexPath.section == 2 {
            let cell = tableView.dequeueReusableCell(withIdentifier: "InputTextFieldCell", for: indexPath) as! InputTextFieldTableViewCell
            cell.selectionStyle = .none
            cell.inputTextField.placeholder = "Title"
            cell.inputTextField.text = self.extractedTitle
            cell.didChangeText = { [weak self] text in
                self?.extractedTitle = text
            }
            return cell
        }
        else if indexPath.section == 3 {
            let cell = tableView.dequeueReusableCell(withIdentifier: "InputTextFieldCell", for: indexPath) as! InputTextFieldTableViewCell
            cell.selectionStyle = .none
            cell.inputTextField.placeholder = "Facility Name"
            cell.inputTextField.text = self.facilityNameText
            cell.didChangeText = { [weak self] text in
                self?.facilityNameText = text
            }
            return cell
        }
        else if indexPath.section == 4 {
            let cell = tableView.dequeueReusableCell(withIdentifier: "DateInputCell", for: indexPath) as! DateInputTableViewCell
            cell.selectionStyle = .none
            cell.dateTextField.placeholder = "Select Date"
            if let date = parsedDocumentDate(from: self.dateString) {
                cell.setDate(date)
            } else if !self.dateString.isEmpty {
                cell.dateTextField.text = self.dateString
            } else {
                cell.dateTextField.text = nil
            }
            cell.didChangeDate = { [weak self] date in
                let formatter = DateFormatter()
                formatter.dateFormat = "dd-MM-yyyy"
                self?.dateString = formatter.string(from: date)
            }
            return cell
        }
        else if indexPath.section == 5 {
            let cell = tableView.dequeueReusableCell(withIdentifier: "DropdownCell", for: indexPath) as! DropdownTableViewCell
            cell.selectionStyle = .none
            cell.dropdownTextField?.placeholder = "Select Record Type"
            if !self.extractionRecordType.isEmpty {
                cell.setSelectedOption(self.extractionRecordType)
            } else {
                cell.dropdownTextField?.text = nil
                cell.pickerView.selectRow(0, inComponent: 0, animated: false)
            }
            cell.didChangeSelection = { [weak self] value in
                self?.extractionRecordType = value
            }
            return cell
        }
        else if indexPath.section == 6 {
            let cell = tableView.dequeueReusableCell(withIdentifier: "SymptomDescriptionCell", for: indexPath) as! SymptomDescriptionTableViewCell
            cell.selectionStyle = .none
            cell.placeholderText = "Summary"
            
            // Apply the user's typed text or the default placeholder
            cell.descriptionTextView.text = summaryText.isEmpty ? "Summary" : summaryText
            cell.descriptionTextView.textColor = summaryText.isEmpty ? .systemGray3 : .label
            
            // Constrain a minimum height, but allow it to gracefully expand past it!
            if cell.notesHeightConstraint == nil {
                let constraint = cell.descriptionTextView.heightAnchor.constraint(greaterThanOrEqualToConstant: 100)
                constraint.isActive = true
                cell.notesHeightConstraint = constraint
            }
            
            // Trigger native UICollectionView resizing organically as the user types
            cell.didChangeDescription = { [weak self] text in
                self?.summaryText = text
                self?.tableView.beginUpdates()
                self?.tableView.endUpdates()
            }
            
            return cell
        }
        
        return UITableViewCell()
    }
    
    // MARK: - Toast
    private func showToast(message: String) {
        let outerHorizontalPadding: CGFloat = 20
        let horizontalTextPadding: CGFloat = 28
        let verticalTextPadding: CGFloat = 14
        let toastLabel = UILabel()
        toastLabel.backgroundColor = UIColor.gray.withAlphaComponent(0.6)
        toastLabel.textColor = .white
        toastLabel.textAlignment = .center
        toastLabel.font = UIFont.systemFont(ofSize: 14, weight: .medium)
        toastLabel.text = message
        toastLabel.numberOfLines = 0
        toastLabel.alpha = 0.0
        toastLabel.clipsToBounds = true
        
        let maxSize = CGSize(width: self.view.bounds.width - (outerHorizontalPadding * 2) - (horizontalTextPadding * 2), height: 120)
        let expectedSize = toastLabel.sizeThatFits(maxSize)
        let labelHeight = max(expectedSize.height + (verticalTextPadding * 2), 50)
        let labelWidth = min(
            self.view.bounds.width - (outerHorizontalPadding * 2),
            expectedSize.width + (horizontalTextPadding * 2)
        )
        
        toastLabel.frame = CGRect(
            x: (self.view.bounds.width - labelWidth) / 2,
            y: self.view.bounds.height - labelHeight - 20 - self.view.safeAreaInsets.bottom,
            width: labelWidth,
            height: labelHeight
        )
        toastLabel.layer.cornerRadius = labelHeight / 2
        
        self.view.addSubview(toastLabel)
        
        UIView.animate(withDuration: 0.3, animations: {
            toastLabel.alpha = 1.0
        }) { _ in
            UIView.animate(withDuration: 0.5, delay: 4.0, options: .curveEaseOut, animations: {
                toastLabel.alpha = 0.0
            }) { _ in
                toastLabel.removeFromSuperview()
            }
        }
    }

    // MARK: - Native Preview (Quick Look)
    private func presentNativePreview(forAttachmentAt index: Int) {
        guard index >= 0, index < attachments.count else {
            showToast(message: "Unable to open preview.")
            return
        }
        presentNativePreview(for: attachments[index])
    }

    private func presentNativePreview(for attachment: RecordAttachmentDraft) {
        let fileURL: URL

        if let originalURL = attachment.fileURL {
            fileURL = originalURL
        } else {
            let image = attachment.image ?? attachment.thumbnail
            guard let data = image.pngData() else {
                showToast(message: "Unable to open preview.")
                return
            }
            fileURL = FileManager.default.temporaryDirectory
                .appendingPathComponent("consulto-preview-\(UUID().uuidString).png")
            do {
                try data.write(to: fileURL, options: .atomic)
            } catch {
                showToast(message: "Unable to open preview.")
                return
            }
        }

        quickLookPreviewURLs = [fileURL]
        let controller = QLPreviewController()
        controller.dataSource = self
        present(controller, animated: true)
    }
    
    // MARK: - Attachment Platter
    private func showAttachmentPlatter() {
        guard let container = platterContainerView else { return }
        guard platterViewController == nil else { return }
        
        container.isUserInteractionEnabled = true
        
        let storyboard = UIStoryboard(name: "Main", bundle: nil)
        guard let platterVC = storyboard.instantiateViewController(withIdentifier: "AttachmentPlatterVC") as? AttachmentPlatterViewController else {
            return
        }
        
        platterVC.onCameraTap = { [weak self] in
            self?.dismissPlatter()
            self?.openCamera()
        }
        platterVC.onGalleryTap = { [weak self] in
            self?.dismissPlatter()
            self?.openGallery()
        }
        platterVC.onDocumentTap = { [weak self] in
            self?.dismissPlatter()
            self?.openDocumentPicker()
        }
        platterVC.onDismiss = { [weak self] in
            self?.dismissPlatter()
        }
        platterVC.onAddPhotosTapped = { [weak self] assets in
            self?.dismissPlatter()
            self?.processPlatterAssets(assets)
        }
        platterVC.onSelectionChange = { [weak self] hasSelection in
            guard let self else { return }
            let targetHeight: CGFloat = hasSelection ? 310 : 280
            let duration: TimeInterval = 0.3
            self.platterViewController?.animateMaskPath(toHeight: targetHeight, duration: duration)
            self.platterHeightConstraint?.constant = targetHeight
            UIView.animate(withDuration: duration, delay: 0, options: .curveEaseInOut) {
                self.view.layoutIfNeeded()
            }
        }
        
        platterVC.view.translatesAutoresizingMaskIntoConstraints = false
        addChild(platterVC)
        container.addSubview(platterVC.view)
        platterVC.didMove(toParent: self)
        
        let panGesture = UIPanGestureRecognizer(target: self, action: #selector(handlePlatterPan(_:)))
        platterVC.view.addGestureRecognizer(panGesture)
        
        let containerTap = UITapGestureRecognizer(target: self, action: #selector(containerBackgroundTapped(_:)))
        containerTap.cancelsTouchesInView = false
        container.addGestureRecognizer(containerTap)
        
        self.platterViewController = platterVC
        
        let bottomConstraint = platterVC.view.bottomAnchor.constraint(equalTo: container.bottomAnchor, constant: 400)
        self.platterBottomConstraint = bottomConstraint
        
        let heightConstraint = platterVC.view.heightAnchor.constraint(equalToConstant: 280)
        self.platterHeightConstraint = heightConstraint
        
        NSLayoutConstraint.activate([
            platterVC.view.leadingAnchor.constraint(equalTo: container.leadingAnchor, constant: 5),
            platterVC.view.trailingAnchor.constraint(equalTo: container.trailingAnchor, constant: -5),
            bottomConstraint,
            heightConstraint
        ])
        
        container.layoutIfNeeded()
        
        self.platterBottomConstraint?.constant = -5
        dimmingOverlayView?.isHidden = false
        dimmingOverlayView?.isUserInteractionEnabled = true
        
        UIView.animate(withDuration: 0.5, delay: 0, usingSpringWithDamping: 0.8, initialSpringVelocity: 0.5, options: .curveEaseOut) {
            self.tabBarController?.tabBar.alpha = 0
            self.dimmingOverlayView?.alpha = 0.3
            self.view.layoutIfNeeded()
        }
    }
    
    @objc private func dismissPlatter() {
        guard let vc = platterViewController else { return }
        
        platterHeightConstraint?.constant = 280
        platterViewController?.animateMaskPath(toHeight: 280, duration: 0)
        view.layoutIfNeeded()
        
        self.platterBottomConstraint?.constant = 400
        
        UIView.animate(withDuration: 0.3, animations: {
            self.tabBarController?.tabBar.alpha = 1
            self.dimmingOverlayView?.alpha = 0
            self.view.layoutIfNeeded()
        }) { _ in
            self.dimmingOverlayView?.isHidden = true
            self.dimmingOverlayView?.isUserInteractionEnabled = false
            
            vc.willMove(toParent: nil)
            vc.view.removeFromSuperview()
            vc.removeFromParent()
            
            if let gestures = self.platterContainerView?.gestureRecognizers {
                gestures.forEach { self.platterContainerView?.removeGestureRecognizer($0) }
            }
            
            self.platterViewController = nil
            self.platterBottomConstraint = nil
            self.platterHeightConstraint = nil
            self.platterContainerView?.isUserInteractionEnabled = false
        }
    }
    
    @objc private func containerBackgroundTapped(_ gesture: UITapGestureRecognizer) {
        guard let platterView = platterViewController?.view else { return }
        let location = gesture.location(in: platterContainerView)
        if !platterView.frame.contains(location) {
            dismissPlatter()
        }
    }
    
    @objc private func handlePlatterPan(_ gesture: UIPanGestureRecognizer) {
        guard let view = gesture.view else { return }
        let translation = gesture.translation(in: view)
        let velocity = gesture.velocity(in: view)
        
        switch gesture.state {
        case .changed:
            if translation.y > 0 {
                self.platterBottomConstraint?.constant = translation.y - 5
                let progress = min(translation.y / 200, 1.0)
                self.dimmingOverlayView?.alpha = 0.3 * (1 - progress)
                self.view.layoutIfNeeded()
            }
        case .ended, .cancelled:
            if translation.y > 150 || velocity.y > 1000 {
                dismissPlatter()
            } else {
                self.platterBottomConstraint?.constant = -5
                UIView.animate(withDuration: 0.3, delay: 0, usingSpringWithDamping: 0.8, initialSpringVelocity: 0.5, options: .curveEaseOut) {
                    self.dimmingOverlayView?.alpha = 0.3
                    self.view.layoutIfNeeded()
                }
            }
        default:
            break
        }
    }
    
    // MARK: - Pickers
    private func openCamera() {
        guard UIImagePickerController.isSourceTypeAvailable(.camera) else {
            showToast(message: "Camera is not available on this device.")
            return
        }
        let picker = UIImagePickerController()
        picker.sourceType = .camera
        picker.delegate = self
        present(picker, animated: true)
    }
    
    private func openGallery() {
        var config = PHPickerConfiguration()
        config.selectionLimit = 0
        config.filter = .images
        let picker = PHPickerViewController(configuration: config)
        picker.delegate = self
        present(picker, animated: true)
    }
    
    private func openDocumentPicker() {
        let picker = UIDocumentPickerViewController(forOpeningContentTypes: [.pdf, .image, .plainText], asCopy: true)
        picker.delegate = self
        picker.allowsMultipleSelection = true
        present(picker, animated: true)
    }
    
    func picker(_ picker: PHPickerViewController, didFinishPicking results: [PHPickerResult]) {
        var fetchedAttachments: [RecordAttachmentDraft?] = Array(repeating: nil, count: results.count)
        let group = DispatchGroup()
        
        for (index, result) in results.enumerated() {
            group.enter()
            result.itemProvider.loadObject(ofClass: UIImage.self) { object, _ in
                if let image = object as? UIImage {
                    fetchedAttachments[index] = .image(image)
                }
                group.leave()
            }
        }
        
        picker.dismiss(animated: true) {
            group.notify(queue: .main) {
                self.appendNewAttachmentsToPreview(fetchedAttachments.compactMap { $0 })
            }
        }
    }
    
    func documentPicker(_ controller: UIDocumentPickerViewController, didPickDocumentsAt urls: [URL]) {
        var fetchedAttachments: [RecordAttachmentDraft] = []
        for url in urls {
            if url.pathExtension.lowercased() == "pdf" {
                if let pdfImage = self.pdfToImage(url: url) {
                    fetchedAttachments.append(.pdf(url: url, thumbnail: pdfImage))
                }
            } else if let data = try? Data(contentsOf: url), let img = UIImage(data: data) {
                fetchedAttachments.append(.image(img, fileURL: url))
            }
        }
        appendNewAttachmentsToPreview(fetchedAttachments)
    }
    
    func imagePickerController(_ picker: UIImagePickerController, didFinishPickingMediaWithInfo info: [UIImagePickerController.InfoKey : Any]) {
        if let image = info[.originalImage] as? UIImage {
            picker.dismiss(animated: true) {
                self.appendNewAttachmentsToPreview([.image(image)])
            }
        } else {
            picker.dismiss(animated: true)
        }
    }
    
    private func processPlatterAssets(_ assets: [PHAsset]) {
        let manager = PHImageManager.default()
        let options = PHImageRequestOptions()
        options.isSynchronous = false
        options.deliveryMode = .highQualityFormat
        options.isNetworkAccessAllowed = true
        
        var fetchedAttachments: [RecordAttachmentDraft?] = Array(repeating: nil, count: assets.count)
        let group = DispatchGroup()
        
        for (index, asset) in assets.enumerated() {
            group.enter()
            let targetSize = CGSize(width: 1500, height: 1500)
            manager.requestImage(for: asset, targetSize: targetSize, contentMode: .aspectFit, options: options) { image, _ in
                if let img = image {
                    fetchedAttachments[index] = .image(img)
                }
                group.leave()
            }
        }
        
        group.notify(queue: .main) {
            self.appendNewAttachmentsToPreview(fetchedAttachments.compactMap { $0 })
        }
    }
    
    private func appendNewAttachmentsToPreview(_ newAttachments: [RecordAttachmentDraft]) {
        guard !newAttachments.isEmpty else { return }
        guard currentState == .pending else {
            showToast(message: "You can add files only before processing.")
            return
        }
        attachments.append(contentsOf: newAttachments)
        tableView.reloadSections(IndexSet(integer: 0), with: .none)
        centerRowVertically(animated: false)
    }
    
    private func pdfToImage(url: URL) -> UIImage? {
        guard let document = CGPDFDocument(url as CFURL),
              let page = document.page(at: 1) else { return nil }
        
        let pageRect = page.getBoxRect(.mediaBox)
        let renderer = UIGraphicsImageRenderer(size: pageRect.size)
        
        return renderer.image { ctx in
            UIColor.white.set()
            ctx.fill(pageRect)
            ctx.cgContext.translateBy(x: 0.0, y: pageRect.size.height)
            ctx.cgContext.scaleBy(x: 1.0, y: -1.0)
            ctx.cgContext.drawPDFPage(page)
        }
    }
}

extension PreviewViewController: QLPreviewControllerDataSource {
    func numberOfPreviewItems(in controller: QLPreviewController) -> Int {
        quickLookPreviewURLs.count
    }

    func previewController(_ controller: QLPreviewController, previewItemAt index: Int) -> QLPreviewItem {
        quickLookPreviewURLs[index] as NSURL
    }
}
