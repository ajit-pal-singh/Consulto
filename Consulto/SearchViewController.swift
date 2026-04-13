import UIKit

class SearchViewController: UIViewController {

    // MARK: - Properties
    private let searchController = UISearchController(searchResultsController: nil)
    private let tableView = UITableView()

    private var allSessions: [ConsultSession] = []
    private var allRecords: [HealthRecord] = []
    private var filteredSessions: [ConsultSession] = []
    private var filteredRecords: [HealthRecord] = []

    private var placeholderTimer: Timer?
    private var currentHintIndex = 0
    private let placeholderHints = [
        "Prescriptions",
        "Lab Reports",
        "Scans",
        "Discharge Summary",
        "Visits"
    ]

    // Segmented Control
    private let segmentedControl = UISegmentedControl(items: ["Records", "Visits"])

    // Empty State View
    private let emptyStateView = UIView()
    private let emptyStateIcon = UIImageView()
    private let emptyStateTitle = UILabel()
    private let emptyStateSubtitle = UILabel()

    // Custom Navigation
    private let customNavView = UIView()
    private let customNavTitle = UILabel()

    // Custom Placeholder UI
    private let placeholderStackView = UIStackView()
    private let staticLabel = UILabel()
    private let rotatingLabel = UILabel()

    // MARK: - Lifecycle

    override func viewDidLoad() {
        super.viewDidLoad()
        view.backgroundColor = UIColor(hex: "#F1F6FF")

        setupCustomNavigation()

        // When the search bar becomes active, the search results should appear only inside the current view controller
        definesPresentationContext = true

        // Control the table view data and interactions
        tableView.dataSource = self
        tableView.delegate = self
        searchController.searchBar.delegate = self

        // Register cell
        tableView.register(UITableViewCell.self, forCellReuseIdentifier: "SearchResultCell")

        // Search Bar Functionality
        searchController.searchResultsUpdater = self
        navigationItem.searchController = searchController

        // Disable the automatic cancel 'X' button so it doesn't shrink the field
        searchController.automaticallyShowsCancelButton = true
        // Ensures search bar always visible
        navigationItem.hidesSearchBarWhenScrolling = false

        setupEmptyStateView()
        setupTableView()
        startPlaceholderTimer()
    }

    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)

        // Ensure standard navigation bar is hidden so our custom one remains perfectly stable
        navigationController?.setNavigationBarHidden(true, animated: false)

        // This fetches sessions and records data
        loadData()
    }

    // MARK: - Custom Navigation Setup

    private func setupCustomNavigation() {
        customNavView.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(customNavView)

        let customFont = UIFont(name: "Montserrat-Bold", size: 34) ?? UIFont.systemFont(ofSize: 34, weight: .bold)
        customNavTitle.text = "Search"
        customNavTitle.font = customFont
        customNavTitle.textColor = .label
        customNavTitle.translatesAutoresizingMaskIntoConstraints = false
        customNavView.addSubview(customNavTitle)

        NSLayoutConstraint.activate([
            // Custom Navigation View Constraints (from storyboard: Top 65, Height 50)
            customNavView.topAnchor.constraint(equalTo: view.topAnchor, constant: 65),
            customNavView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            customNavView.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            customNavView.heightAnchor.constraint(equalToConstant: 50),

            // Title Label Constraints (Leading 16, Center Y)
            customNavTitle.leadingAnchor.constraint(equalTo: customNavView.leadingAnchor, constant: 16),
            customNavTitle.centerYAnchor.constraint(equalTo: customNavView.centerYAnchor)
        ])
    }

    // MARK: - Empty State Setup

    private func setupEmptyStateView() {
        emptyStateIcon.image = UIImage(systemName: "magnifyingglass")
        emptyStateIcon.tintColor = .systemGray
        emptyStateIcon.contentMode = .scaleAspectFit
        emptyStateIcon.translatesAutoresizingMaskIntoConstraints = false

        emptyStateTitle.font = UIFont.systemFont(ofSize: 20, weight: .bold)
        emptyStateTitle.textColor = .label
        emptyStateTitle.textAlignment = .center
        emptyStateTitle.translatesAutoresizingMaskIntoConstraints = false

        emptyStateSubtitle.text = "Check the spelling or try a new search."
        emptyStateSubtitle.font = UIFont.systemFont(ofSize: 15, weight: .regular)
        emptyStateSubtitle.textColor = .secondaryLabel
        emptyStateSubtitle.textAlignment = .center
        emptyStateSubtitle.translatesAutoresizingMaskIntoConstraints = false

        let stackView = UIStackView(arrangedSubviews: [emptyStateIcon, emptyStateTitle, emptyStateSubtitle])
        stackView.axis = .vertical
        stackView.alignment = .center
        stackView.spacing = 8
        stackView.setCustomSpacing(12, after: emptyStateIcon)
        stackView.translatesAutoresizingMaskIntoConstraints = false

        emptyStateView.addSubview(stackView)

        NSLayoutConstraint.activate([
            emptyStateIcon.widthAnchor.constraint(equalToConstant: 60),
            emptyStateIcon.heightAnchor.constraint(equalToConstant: 60),

            stackView.centerXAnchor.constraint(equalTo: emptyStateView.centerXAnchor),
            stackView.centerYAnchor.constraint(equalTo: emptyStateView.centerYAnchor, constant: -40)
        ])
    }

    deinit {
        placeholderTimer?.invalidate()
    }

    // MARK: - Custom Placeholder UI

    private func setupPlaceholderUI() {
        guard let textField = searchController.searchBar.searchTextField as UITextField? else { return }

        // Clear default placeholder
        textField.placeholder = ""

        placeholderStackView.axis = .horizontal
        placeholderStackView.alignment = .fill
        placeholderStackView.isUserInteractionEnabled = false

        // Explicitly set smaller font sizes using numbers
        let staticFont = UIFont.systemFont(ofSize: 15)
        let rotatingFont = UIFont.systemFont(ofSize: 15)

        staticLabel.text = "Search your "
        staticLabel.textColor = .systemGray
        staticLabel.font = staticFont

        rotatingLabel.textColor = .systemBlue
        rotatingLabel.font = rotatingFont
        rotatingLabel.text = "\(placeholderHints[currentHintIndex])"

        placeholderStackView.addArrangedSubview(staticLabel)
        placeholderStackView.addArrangedSubview(rotatingLabel)

        placeholderStackView.translatesAutoresizingMaskIntoConstraints = false
        textField.addSubview(placeholderStackView)

        if let leftView = textField.leftView {
            NSLayoutConstraint.activate([
                placeholderStackView.leadingAnchor.constraint(equalTo: leftView.trailingAnchor, constant: 9),
                placeholderStackView.centerYAnchor.constraint(equalTo: textField.centerYAnchor),
                placeholderStackView.trailingAnchor.constraint(lessThanOrEqualTo: textField.trailingAnchor, constant: -10)
            ])
        } else {
            NSLayoutConstraint.activate([
                placeholderStackView.leadingAnchor.constraint(equalTo: textField.leadingAnchor, constant: 40),
                placeholderStackView.centerYAnchor.constraint(equalTo: textField.centerYAnchor),
                placeholderStackView.trailingAnchor.constraint(lessThanOrEqualTo: textField.trailingAnchor, constant: -10)

            ])
        }
    }

    // MARK: - Table View Setup

    private func setupTableView() {
        // Setup Segmented Control
        segmentedControl.translatesAutoresizingMaskIntoConstraints = false
        segmentedControl.selectedSegmentIndex = 0
        segmentedControl.isHidden = true // hidden initially

        // Increase Text Size
        let font = UIFont.systemFont(ofSize: 17, weight: .medium)
        segmentedControl.setTitleTextAttributes([.font: font], for: .normal)
        segmentedControl.setTitleTextAttributes([.font: font], for: .selected)

        segmentedControl.addTarget(self, action: #selector(segmentChanged), for: .valueChanged)

        view.addSubview(segmentedControl)

        tableView.translatesAutoresizingMaskIntoConstraints = false
        tableView.backgroundColor = .clear
        tableView.layer.cornerRadius = 14
        tableView.clipsToBounds = true
        view.addSubview(tableView)

        NSLayoutConstraint.activate([
            segmentedControl.topAnchor.constraint(equalTo: customNavView.bottomAnchor, constant: 10),
            segmentedControl.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 16),
            segmentedControl.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -16),
            segmentedControl.heightAnchor.constraint(equalToConstant: 44), // Increase height

            tableView.topAnchor.constraint(equalTo: segmentedControl.bottomAnchor, constant: 15),
            tableView.bottomAnchor.constraint(equalTo: view.bottomAnchor),
            tableView.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 16),
            tableView.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -16)
        ])
    }

    @objc private func segmentChanged() {
        updateEmptyState()
        tableView.reloadData()
    }

    private func updateEmptyState() {
        let text = searchController.searchBar.text ?? ""
        if text.isEmpty {
            tableView.backgroundView = nil
            return
        }

        let hasResults = segmentedControl.selectedSegmentIndex == 0 ? !filteredRecords.isEmpty : !filteredSessions.isEmpty

        if !hasResults {
            emptyStateTitle.text = "No results for \"\(text)\""
            tableView.backgroundView = emptyStateView
        } else {
            tableView.backgroundView = nil
        }
    }

    // MARK: - Placeholder Timer

    private func startPlaceholderTimer() {
        // Wait for the search bar to render before adding placeholder
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
            self.setupPlaceholderUI()
        }

        placeholderTimer = Timer.scheduledTimer(withTimeInterval: 2.0, repeats: true) { [weak self] _ in
            guard let self = self else { return }
            self.currentHintIndex = (self.currentHintIndex + 1) % self.placeholderHints.count

            let transition = CATransition()
            transition.type = .push
            transition.subtype = .fromTop
            transition.duration = 0.4
            transition.timingFunction = CAMediaTimingFunction(name: .easeInEaseOut)

            self.rotatingLabel.layer.add(transition, forKey: "wheelRotation")
            self.rotatingLabel.text = "\(self.placeholderHints[self.currentHintIndex])"
        }
    }

    // MARK: - Data Loading

    private func loadData() {
        allSessions = ConsultSessionStore.shared.loadSessions()
        allRecords = (try? HealthRecordStore.shared.loadRecords()) ?? []
    }
}

// MARK: - UISearchResultsUpdating & UISearchBarDelegate

extension SearchViewController: UISearchResultsUpdating, UISearchBarDelegate {

    func updateSearchResults(for searchController: UISearchController) {
        let text = searchController.searchBar.text ?? ""

        // Hide custom placeholder when user types
        placeholderStackView.isHidden = !text.isEmpty
        // Show segmented control only when typing
        segmentedControl.isHidden = text.isEmpty

        if text.isEmpty {
            filteredSessions.removeAll()
            filteredRecords.removeAll()
        } else {
            filteredSessions = allSessions.filter {
                $0.title.lowercased().contains(text.lowercased()) ||
                $0.doctorName.lowercased().contains(text.lowercased())
            }

            filteredRecords = allRecords.filter {
                $0.title.lowercased().contains(text.lowercased()) ||
                ($0.healthFacilityName?.lowercased().contains(text.lowercased()) ?? false) ||
                ($0.summary?.lowercased().contains(text.lowercased()) ?? false)
            }
        }

        updateEmptyState()
        tableView.reloadData()
    }

    // Used to reload the data when the search bar is canceled
    func searchBarCancelButtonClicked(_ searchBar: UISearchBar) {
        filteredSessions.removeAll()
        filteredRecords.removeAll()
        segmentedControl.isHidden = true
        tableView.backgroundView = nil
        tableView.reloadData()
    }
}

// MARK: - Table View DataSource & Delegate

extension SearchViewController: UITableViewDataSource, UITableViewDelegate {

    func numberOfSections(in tableView: UITableView) -> Int {
        if searchController.isActive && !(searchController.searchBar.text ?? "").isEmpty {
            return 1
        }
        return 0
    }

    func tableView(_ tableView: UITableView, titleForHeaderInSection section: Int) -> String? {
        return nil
    }

    func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        if searchController.isActive && !(searchController.searchBar.text ?? "").isEmpty {
            return segmentedControl.selectedSegmentIndex == 0 ? filteredRecords.count : filteredSessions.count
        }
        return 0
    }

    func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let cell = UITableViewCell(style: .subtitle, reuseIdentifier: "SearchResultCell")
        cell.accessoryType = .disclosureIndicator

        let dateFormatter = DateFormatter()
        dateFormatter.dateStyle = .medium
        dateFormatter.timeStyle = .none

        if segmentedControl.selectedSegmentIndex == 1 {
            let session = filteredSessions[indexPath.row]
            cell.textLabel?.text = session.title
            let dateStr = dateFormatter.string(from: session.date)
            cell.detailTextLabel?.text = "\(session.doctorName) • \(dateStr)"
            cell.imageView?.image = UIImage(systemName: "stethoscope")
            cell.imageView?.tintColor = .systemBlue
        } else {
            let record = filteredRecords[indexPath.row]
            cell.textLabel?.text = record.title
            
            let dateToUse = record.documentDate ?? record.dateAdded
            let dateStr = dateFormatter.string(from: dateToUse)
            let detailTitle = record.healthFacilityName ?? record.recordType.displayName
            cell.detailTextLabel?.text = "\(detailTitle) • \(dateStr)"
            
            cell.imageView?.image = UIImage(systemName: "doc.text")
            cell.imageView?.tintColor = .systemGreen
        }

        cell.textLabel?.font = .systemFont(ofSize: 16, weight: .medium)
        cell.detailTextLabel?.font = .systemFont(ofSize: 13, weight: .regular)
        cell.detailTextLabel?.textColor = .secondaryLabel

        return cell
    }

    // Used to navigate to detail view when tapped
    func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        tableView.deselectRow(at: indexPath, animated: true)

        if segmentedControl.selectedSegmentIndex == 1 {
            let session = filteredSessions[indexPath.row]
            let storyboard = UIStoryboard(name: "ConsultDetailView", bundle: nil)
            if let detailVC = storyboard.instantiateViewController(withIdentifier: "ConsultDetailedView") as? ConsultDetailedViewController {
                detailVC.consultSession = session
                navigationController?.pushViewController(detailVC, animated: true)
            }
        } else {
            let record = filteredRecords[indexPath.row]
            let storyboard = UIStoryboard(name: "Main", bundle: nil)
            if let detailVC = storyboard.instantiateViewController(withIdentifier: "RecordDetailedViewController") as? RecordDetailedViewController {
                detailVC.record = record
                navigationController?.pushViewController(detailVC, animated: true)
            }
        }
    }
}
