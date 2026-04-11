import UIKit
import QuickLook

class RecordDetailedViewController: UIViewController {

    // MARK: - Outlets
    @IBOutlet weak var tableView: UITableView!

    // MARK: - Properties
    var record: HealthRecord?
    private var quickLookPreviewURLs: [URL] = []
    
    // MARK: - Lifecycle
    override func viewDidLoad() {
        super.viewDidLoad()
        setupUI()
        configureTableView()
    }

    private func setupUI() {
        // Set dynamic navigation bar title based on record type
        if let type = record?.recordType {
            switch type {
            case .dischargeSummary: self.title = "Discharge"
            case .labReport: self.title = "Lab Report"
            case .prescription: self.title = "Prescription"
            case .scan: self.title = "Scan"
            default: self.title = "Record"
            }
        } else {
            self.title = "Record"
        }
        
        // Hide large titles for this view to match Figma
        navigationItem.largeTitleDisplayMode = .never
    }

    private func configureTableView() {
        // Safe check in case you haven't connected the outlet yet
        guard let tableView = tableView else { return }
        
        tableView.delegate = self
        tableView.dataSource = self
        
        // Remove empty cell separators
        tableView.separatorStyle = .none
        tableView.backgroundColor = UIColor(hex: "F5F5F5")
        view.backgroundColor = UIColor(hex: "F5F5F5")
        
        // Remove default grouped table head/foot spacing
        tableView.tableHeaderView = UIView(frame: CGRect(x: 0, y: 0, width: 0, height: 0.01))
        tableView.sectionFooterHeight = 0.01
        
        if #available(iOS 15.0, *) {
            tableView.sectionHeaderTopPadding = 0
        }
        
        // Automatic sizing for dynamic cells (crucial for PreviewMediaTableViewCell)
        tableView.rowHeight = UITableView.automaticDimension
        tableView.estimatedRowHeight = 200
        
        // Register Custom XIB Cells Here
        // (PreviewMediaTableViewCell will be designed as a prototype cell directly in the storyboard)
        tableView.register(UINib(nibName: "InfoTableViewCell", bundle: nil), forCellReuseIdentifier: "InfoTableViewCell")
        tableView.register(UINib(nibName: "SummaryTableViewCell", bundle: nil), forCellReuseIdentifier: "SummaryTableViewCell")
    }
    
    // Helper to get Theme Color
    private var themeColor: UIColor {
        guard let type = record?.recordType else { return .systemBlue }
        switch type {
        case .dischargeSummary: return UIColor(named: "DischargeSummaryColor") ?? .systemYellow
        case .labReport: return UIColor(named: "ReportColor") ?? .systemRed
        case .prescription: return UIColor(named: "PrescriptionColor") ?? .systemBlue
        case .scan: return UIColor(named: "ScanColor") ?? .systemPurple
        default: return .darkGray
        }
    }
}

// MARK: - UITableView DataSource & Delegate
extension RecordDetailedViewController: UITableViewDataSource, UITableViewDelegate {
    
    func numberOfSections(in tableView: UITableView) -> Int {
        return 3 // 0: Images, 1: Overview, 2: Summary
    }
    
    func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        switch section {
        case 0: return 1 // Image Carousel
        case 1: return 3 // Doctor/Report Name, Facility, Date Added
        case 2: return 1 // Summary Text
        default: return 0
        }
    }
    
    // Explicitly set the height for the Image Carousel to fix the layout overlap!
    func tableView(_ tableView: UITableView, heightForRowAt indexPath: IndexPath) -> CGFloat {
        if indexPath.section == 0 {
            // Replicate the aspect ratio math from PreviewMediaTableViewCell to give it the exact height
            let screenWidth = UIScreen.main.bounds.width
            let itemWidth = screenWidth - 40 - (2 * 20) // screen margins (40) + peeks (40)
            let cardHeight = (itemWidth * 4 / 3).rounded() // 3:4 portrait aspect ratio
            let pageNavigatorHeight: CGFloat = 66
            
            // 🛠️ TO CONTROL THE GAP BELOW IMAGE CELL: Change the "+ 20" here!
            // This adds extra vertical space to the bottom of the entire Image cell.
            return cardHeight + 26
        }
        
        // Let the other cells size automatically
        return UITableView.automaticDimension
    }
    
    
    func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        guard let record = record else { return UITableViewCell() }
        
        switch indexPath.section {
        case 0:
            guard let cell = tableView.dequeueReusableCell(withIdentifier: "PreviewMediaTableViewCell", for: indexPath) as? PreviewMediaTableViewCell else {
                return UITableViewCell()
            }
            
            // Fetch all uploaded images for the carousel
            var imagesToDisplay = HealthRecordStore.shared.allImages(for: record)
            
            // Fallback to sample image if no images exist
            if imagesToDisplay.isEmpty, let fallback = UIImage(named: "sample") {
                imagesToDisplay.append(fallback)
            }
            
            cell.configure(with: imagesToDisplay, state: .pending)
            
            // Hide the delete button — this is a read-only view
            cell.hideDeleteButton = true
            
            // Wire up the expand button
            cell.onExpandTapped = { [weak self] index in
                self?.presentNativePreview(for: index)
            }
            
            return cell
            
        case 1:
            guard let cell = tableView.dequeueReusableCell(withIdentifier: "InfoTableViewCell", for: indexPath) as? InfoTableViewCell else {
                return UITableViewCell()
            }
            
            if indexPath.row == 0 {
                let bottomText = record.title ?? "Unknown"
                
                let iconName: String
                let topText: String
                
                switch record.recordType {
                case .dischargeSummary:
                    iconName = "bed.double.fill"
                    topText = "Discharge From"
                case .scan:
                    iconName = "viewfinder"
                    topText = "Scan Name"
                case .labReport:
                    iconName = "flask"
                    topText = "Report Name"
                case .prescription:
                    iconName = "stethoscope"
                    topText = "Doctor Name"
                default:
                    iconName = "doc.fill"
                    topText = "Title"
                }
                
                cell.configure(topText: topText, bottomText: bottomText, iconName: iconName, themeColor: themeColor)
                
            } else if indexPath.row == 1 {
                cell.configure(topText: "Facility Name", bottomText: record.healthFacilityName ?? "Unknown", iconName: "building.2.fill", themeColor: themeColor)
                
            } else if indexPath.row == 2 {
                let formatter = DateFormatter()
                formatter.dateFormat = "dd MMMM yyyy"
                let dateStr = formatter.string(from: record.documentDate ?? record.dateAdded)
                cell.configure(topText: "Date Added", bottomText: dateStr, iconName: "calendar", themeColor: themeColor)
            }
            
            return cell
            
        case 2:
            guard let cell = tableView.dequeueReusableCell(withIdentifier: "SummaryTableViewCell", for: indexPath) as? SummaryTableViewCell else {
                return UITableViewCell()
            }
            // Use the true summary text or a fallback if empty
            let summaryText = (record.summary?.isEmpty == false) ? record.summary! : "No summary available for this record."
            cell.configure(with: summaryText)
            return cell
            
        default:
            return UITableViewCell()
        }
    }
    
    // Custom Section Headers
    func tableView(_ tableView: UITableView, viewForHeaderInSection section: Int) -> UIView? {
        if section == 0 { return nil }
        
        let headerView = UIView()
        headerView.backgroundColor = .clear // Let table background show
        
        let label = UILabel()
        label.translatesAutoresizingMaskIntoConstraints = false
        label.font = .systemFont(ofSize: 20, weight: .bold).rounded
        label.textColor = .label
        
        if section == 1 {
            label.text = "Overview"
        } else if section == 2 {
            label.text = "Summary"
        }
        
        headerView.addSubview(label)
        NSLayoutConstraint.activate([
            label.leadingAnchor.constraint(equalTo: headerView.leadingAnchor, constant: 20),
            label.trailingAnchor.constraint(equalTo: headerView.trailingAnchor, constant: -20),
            label.bottomAnchor.constraint(equalTo: headerView.bottomAnchor, constant: -8) // Anchor to bottom to push text closer to the cells below
        ])
        
        return headerView
    }
    
    // Provide a concrete height so the headers actually show up without clipping!
    func tableView(_ tableView: UITableView, heightForHeaderInSection section: Int) -> CGFloat {
        if section == 0 { return 0.01 }
        
        // 🛠️ TO CONTROL GAP ABOVE 'OVERVIEW' / 'SUMMARY' TEXT:
        // Increase or decrease this '45'. It pushes the text further down from the previous cell.
        return 45 
    }

    // Force footers to 0 to remove the massive default gaps below sections
    func tableView(_ tableView: UITableView, heightForFooterInSection section: Int) -> CGFloat {
        return 0.01
    }
    
    // Removes the view for footers so it doesn't default
    func tableView(_ tableView: UITableView, viewForFooterInSection section: Int) -> UIView? {
        return nil
    }
    
    // MARK: - Actions
    @IBAction func deleteRecordTapped(_ sender: Any) {
        let alert = UIAlertController(title: "Delete Record", message: "Are you sure you want to delete this permanently? This action cannot be undone.", preferredStyle: .alert)
        
        alert.addAction(UIAlertAction(title: "Cancel", style: .cancel, handler: nil))
        alert.addAction(UIAlertAction(title: "Delete", style: .destructive, handler: { [weak self] _ in
            guard let self = self, let recordID = self.record?.id else { return }
            do {
                try HealthRecordStore.shared.deleteRecord(id: recordID)
                self.navigationController?.popViewController(animated: true)
            } catch {
                let errorAlert = UIAlertController(title: "Error", message: "Failed to delete record.", preferredStyle: .alert)
                errorAlert.addAction(UIAlertAction(title: "OK", style: .default))
                self.present(errorAlert, animated: true)
            }
        }))
        
        present(alert, animated: true)
    }
    
    // MARK: - Native Preview (Quick Look)
    private func presentNativePreview(for index: Int) {
        guard let record = record, index >= 0, index < record.files.count else { return }
        
        if let url = HealthRecordStore.shared.url(for: record.files[index]) {
            quickLookPreviewURLs = [url]
            let controller = QLPreviewController()
            controller.dataSource = self
            present(controller, animated: true)
        }
    }
}

// MARK: - QLPreviewControllerDataSource
extension RecordDetailedViewController: QLPreviewControllerDataSource {
    func numberOfPreviewItems(in controller: QLPreviewController) -> Int {
        return quickLookPreviewURLs.count
    }
    
    func previewController(_ controller: QLPreviewController, previewItemAt index: Int) -> QLPreviewItem {
        return quickLookPreviewURLs[index] as QLPreviewItem
    }
}

// MARK: - Navigation
extension RecordDetailedViewController {
    override func prepare(for segue: UIStoryboardSegue, sender: Any?) {
        if segue.identifier == "EditForm" {
            if let nav = segue.destination as? UINavigationController,
               let editVC = nav.topViewController as? RecordEditFormViewController {
                editVC.record = self.record
                
                // Immediately refresh native UI properties when changes occur!
                editVC.onRecordUpdated = { [weak self] updatedRecord in
                    self?.record = updatedRecord
                    self?.setupUI()
                    self?.tableView.reloadData()
                }
            } 
        }
    }
}
