import UIKit

final class RepeatDaysSelectionViewController: UIViewController, UITableViewDataSource, UITableViewDelegate {
    private let dailyOption = "Every Day"
    private let allDays = ["Monday", "Tuesday", "Wednesday", "Thursday", "Friday", "Saturday", "Sunday"]
    private var selectedDays: Set<String>

    var onDone: ((Set<String>) -> Void)?

    private let dimView = UIView()
    private let cardView = UIView()
    private let headerView = UIView()
    private let titleLabel = UILabel()
    private let cancelButton = UIButton(type: .system)
    private let doneButton = UIButton(type: .system)
    private let headerSeparator = UIView()
    private let tableView = UITableView(frame: .zero, style: .plain)

    init(selectedDays: Set<String>) {
        self.selectedDays = RepeatDaysSelectionViewController.normalizedDays(from: selectedDays)
        super.init(nibName: nil, bundle: nil)
        modalPresentationStyle = .overFullScreen
        modalTransitionStyle = .crossDissolve
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    override func viewDidLoad() {
        super.viewDidLoad()
        setupUI()
    }

    private func setupUI() {
        view.backgroundColor = .clear

        dimView.translatesAutoresizingMaskIntoConstraints = false
        dimView.backgroundColor = UIColor.black.withAlphaComponent(0.18)
        dimView.addGestureRecognizer(UITapGestureRecognizer(target: self, action: #selector(cancelTapped)))
        view.addSubview(dimView)

        cardView.translatesAutoresizingMaskIntoConstraints = false
        cardView.backgroundColor = .systemBackground
        cardView.layer.cornerRadius = 28
        cardView.layer.cornerCurve = .continuous
        cardView.clipsToBounds = true
        view.addSubview(cardView)

        headerView.translatesAutoresizingMaskIntoConstraints = false
        headerView.backgroundColor = .clear
        cardView.addSubview(headerView)

        titleLabel.translatesAutoresizingMaskIntoConstraints = false
        titleLabel.text = "Repeat"
        titleLabel.font = .systemFont(ofSize: 17, weight: .semibold)
        titleLabel.textColor = .label
        headerView.addSubview(titleLabel)

        cancelButton.translatesAutoresizingMaskIntoConstraints = false
        cancelButton.setImage(UIImage(systemName: "xmark"), for: .normal)
        cancelButton.tintColor = .label
        cancelButton.backgroundColor = .systemBackground
        cancelButton.layer.cornerRadius = 22
        cancelButton.layer.cornerCurve = .continuous
        cancelButton.layer.shadowColor = UIColor.black.cgColor
        cancelButton.layer.shadowOpacity = 0.08
        cancelButton.layer.shadowRadius = 14
        cancelButton.layer.shadowOffset = CGSize(width: 0, height: 6)
        cancelButton.addTarget(self, action: #selector(cancelTapped), for: .touchUpInside)
        headerView.addSubview(cancelButton)

        doneButton.translatesAutoresizingMaskIntoConstraints = false
        doneButton.setImage(UIImage(systemName: "checkmark"), for: .normal)
        doneButton.tintColor = .white
        doneButton.backgroundColor = UIColor(hex: "3B82F6")
        doneButton.layer.cornerRadius = 22
        doneButton.layer.cornerCurve = .continuous
        doneButton.addTarget(self, action: #selector(doneTapped), for: .touchUpInside)
        headerView.addSubview(doneButton)

        headerSeparator.translatesAutoresizingMaskIntoConstraints = false
        headerSeparator.backgroundColor = UIColor.separator.withAlphaComponent(0.35)
        cardView.addSubview(headerSeparator)

        tableView.translatesAutoresizingMaskIntoConstraints = false
        tableView.backgroundColor = .systemBackground
        tableView.dataSource = self
        tableView.delegate = self
        tableView.allowsMultipleSelection = true
        tableView.rowHeight = 52
        tableView.isScrollEnabled = true
        tableView.separatorInset = UIEdgeInsets(top: 0, left: 20, bottom: 0, right: 20)
        tableView.tableFooterView = UIView()
        cardView.addSubview(tableView)

        NSLayoutConstraint.activate([
            dimView.topAnchor.constraint(equalTo: view.topAnchor),
            dimView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            dimView.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            dimView.bottomAnchor.constraint(equalTo: view.bottomAnchor),

            cardView.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 20),
            cardView.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -20),
            cardView.centerYAnchor.constraint(equalTo: view.centerYAnchor),
            cardView.heightAnchor.constraint(lessThanOrEqualTo: view.heightAnchor, multiplier: 0.72),

            headerView.topAnchor.constraint(equalTo: cardView.topAnchor, constant: 18),
            headerView.leadingAnchor.constraint(equalTo: cardView.leadingAnchor, constant: 16),
            headerView.trailingAnchor.constraint(equalTo: cardView.trailingAnchor, constant: -16),
            headerView.heightAnchor.constraint(equalToConstant: 52),

            cancelButton.leadingAnchor.constraint(equalTo: headerView.leadingAnchor),
            cancelButton.centerYAnchor.constraint(equalTo: headerView.centerYAnchor),
            cancelButton.widthAnchor.constraint(equalToConstant: 44),
            cancelButton.heightAnchor.constraint(equalToConstant: 44),

            doneButton.trailingAnchor.constraint(equalTo: headerView.trailingAnchor),
            doneButton.centerYAnchor.constraint(equalTo: headerView.centerYAnchor),
            doneButton.widthAnchor.constraint(equalToConstant: 44),
            doneButton.heightAnchor.constraint(equalToConstant: 44),

            titleLabel.centerXAnchor.constraint(equalTo: headerView.centerXAnchor),
            titleLabel.centerYAnchor.constraint(equalTo: headerView.centerYAnchor),

            headerSeparator.topAnchor.constraint(equalTo: headerView.bottomAnchor, constant: 12),
            headerSeparator.leadingAnchor.constraint(equalTo: cardView.leadingAnchor),
            headerSeparator.trailingAnchor.constraint(equalTo: cardView.trailingAnchor),
            headerSeparator.heightAnchor.constraint(equalToConstant: 0.5),

            tableView.topAnchor.constraint(equalTo: headerSeparator.bottomAnchor),
            tableView.leadingAnchor.constraint(equalTo: cardView.leadingAnchor),
            tableView.trailingAnchor.constraint(equalTo: cardView.trailingAnchor),
            tableView.bottomAnchor.constraint(equalTo: cardView.bottomAnchor, constant: -12),
            tableView.heightAnchor.constraint(equalToConstant: min(CGFloat(displayOptions.count) * 52.0, 420))
        ])
    }

    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)

        for row in 0..<displayOptions.count where isOptionSelected(displayOptions[row]) {
            tableView.selectRow(at: IndexPath(row: row, section: 0), animated: false, scrollPosition: .none)
        }
    }

    private var displayOptions: [String] {
        [dailyOption] + allDays
    }

    private func isOptionSelected(_ option: String) -> Bool {
        if option == dailyOption {
            return selectedDays.count == allDays.count
        }
        return selectedDays.contains(option)
    }

    private static func normalizedDays(from days: Set<String>) -> Set<String> {
        let map: [String: String] = [
            "Mon": "Monday",
            "Tue": "Tuesday",
            "Wed": "Wednesday",
            "Thu": "Thursday",
            "Fri": "Friday",
            "Sat": "Saturday",
            "Sun": "Sunday",
            "Daily": "Every Day",
            "Every Day": "Every Day"
        ]

        if days.contains("Daily") || days.contains("Every Day") || days.count == 7 {
            return Set(["Monday", "Tuesday", "Wednesday", "Thursday", "Friday", "Saturday", "Sunday"])
        }

        return Set(days.map { map[$0] ?? $0 })
    }

    private func updateSelectionState(for tableView: UITableView) {
        for (index, option) in displayOptions.enumerated() {
            let indexPath = IndexPath(row: index, section: 0)
            let shouldSelect = isOptionSelected(option)
            if shouldSelect {
                tableView.selectRow(at: indexPath, animated: false, scrollPosition: .none)
            } else {
                tableView.deselectRow(at: indexPath, animated: false)
            }
            tableView.cellForRow(at: indexPath)?.accessoryType = shouldSelect ? .checkmark : .none
        }
    }

    @objc private func cancelTapped() {
        dismiss(animated: true)
    }

    @objc private func doneTapped() {
        onDone?(selectedDays)
        dismiss(animated: true)
    }

    func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        displayOptions.count
    }

    func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let identifier = "RepeatDayCell"
        let cell = tableView.dequeueReusableCell(withIdentifier: identifier) ??
            UITableViewCell(style: .default, reuseIdentifier: identifier)
        let option = displayOptions[indexPath.row]
        cell.textLabel?.text = option
        cell.selectionStyle = .none
        cell.backgroundColor = .systemBackground
        let selectedBackgroundView = UIView()
        selectedBackgroundView.backgroundColor = .systemBackground
        cell.selectedBackgroundView = selectedBackgroundView
        cell.accessoryType = isOptionSelected(option) ? .checkmark : .none
        return cell
    }

    func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        let option = displayOptions[indexPath.row]
        if option == dailyOption {
            selectedDays = Set(allDays)
        } else {
            selectedDays.insert(option)
        }
        updateSelectionState(for: tableView)
    }

    func tableView(_ tableView: UITableView, didDeselectRowAt indexPath: IndexPath) {
        let option = displayOptions[indexPath.row]
        if option == dailyOption {
            selectedDays.removeAll()
        } else {
            selectedDays.remove(option)
        }
        updateSelectionState(for: tableView)
    }
}
