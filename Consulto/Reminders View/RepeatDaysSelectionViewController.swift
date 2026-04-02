import UIKit

final class RepeatDaysSelectionViewController: UIViewController, UITableViewDataSource, UITableViewDelegate {
    private let allDays = ["Mon", "Tue", "Wed", "Thu", "Fri", "Sat", "Sun"]
    private var selectedDays: Set<String>

    var onDone: ((Set<String>) -> Void)?

    private let dimView = UIView()
    private let cardView = UIView()
    private let titleLabel = UILabel()
    private let tableView = UITableView(frame: .zero, style: .plain)
    private let cancelButton = UIButton(type: .system)
    private let doneButton = UIButton(type: .system)

    init(selectedDays: Set<String>) {
        self.selectedDays = selectedDays
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
        let dismissTap = UITapGestureRecognizer(target: self, action: #selector(cancelTapped))
        dimView.addGestureRecognizer(dismissTap)
        view.addSubview(dimView)

        cardView.translatesAutoresizingMaskIntoConstraints = false
        cardView.backgroundColor = .systemBackground
        cardView.layer.cornerRadius = 24
        cardView.clipsToBounds = true
        view.addSubview(cardView)

        titleLabel.translatesAutoresizingMaskIntoConstraints = false
        titleLabel.text = "Repeat"
        titleLabel.font = .systemFont(ofSize: 20, weight: .semibold)
        titleLabel.textAlignment = .center
        cardView.addSubview(titleLabel)

        tableView.translatesAutoresizingMaskIntoConstraints = false
        tableView.backgroundColor = .clear
        tableView.dataSource = self
        tableView.delegate = self
        tableView.allowsMultipleSelection = true
        tableView.rowHeight = 52
        tableView.isScrollEnabled = false
        tableView.tableFooterView = UIView()
        cardView.addSubview(tableView)

        cancelButton.translatesAutoresizingMaskIntoConstraints = false
        cancelButton.setTitle("Cancel", for: .normal)
        cancelButton.addTarget(self, action: #selector(cancelTapped), for: .touchUpInside)
        cardView.addSubview(cancelButton)

        doneButton.translatesAutoresizingMaskIntoConstraints = false
        doneButton.setTitle("Done", for: .normal)
        doneButton.titleLabel?.font = .systemFont(ofSize: 17, weight: .semibold)
        doneButton.addTarget(self, action: #selector(doneTapped), for: .touchUpInside)
        cardView.addSubview(doneButton)

        NSLayoutConstraint.activate([
            dimView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            dimView.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            dimView.topAnchor.constraint(equalTo: view.topAnchor),
            dimView.bottomAnchor.constraint(equalTo: view.bottomAnchor),

            cardView.centerYAnchor.constraint(equalTo: view.centerYAnchor),
            cardView.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 28),
            cardView.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -28),

            titleLabel.topAnchor.constraint(equalTo: cardView.topAnchor, constant: 20),
            titleLabel.leadingAnchor.constraint(equalTo: cardView.leadingAnchor, constant: 20),
            titleLabel.trailingAnchor.constraint(equalTo: cardView.trailingAnchor, constant: -20),

            tableView.topAnchor.constraint(equalTo: titleLabel.bottomAnchor, constant: 2),
            tableView.leadingAnchor.constraint(equalTo: cardView.leadingAnchor),
            tableView.trailingAnchor.constraint(equalTo: cardView.trailingAnchor),
            tableView.heightAnchor.constraint(equalToConstant: 372),

            cancelButton.topAnchor.constraint(equalTo: tableView.bottomAnchor, constant: 8),
            cancelButton.leadingAnchor.constraint(equalTo: cardView.leadingAnchor, constant: 20),
            cancelButton.bottomAnchor.constraint(equalTo: cardView.bottomAnchor, constant: -16),

            doneButton.topAnchor.constraint(equalTo: tableView.bottomAnchor, constant: 8),
            doneButton.trailingAnchor.constraint(equalTo: cardView.trailingAnchor, constant: -20),
            doneButton.bottomAnchor.constraint(equalTo: cardView.bottomAnchor, constant: -16)
        ])
    }

    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)

        for (index, day) in allDays.enumerated() where selectedDays.contains(day) {
            tableView.selectRow(at: IndexPath(row: index, section: 0), animated: false, scrollPosition: .none)
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
        allDays.count
    }

    func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let identifier = "RepeatDayCell"
        let cell = tableView.dequeueReusableCell(withIdentifier: identifier) ??
            UITableViewCell(style: .default, reuseIdentifier: identifier)
        let day = allDays[indexPath.row]
        cell.textLabel?.text = day
        cell.selectionStyle = .none
        cell.accessoryType = selectedDays.contains(day) ? .checkmark : .none
        return cell
    }

    func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        let day = allDays[indexPath.row]
        selectedDays.insert(day)
        tableView.cellForRow(at: indexPath)?.accessoryType = .checkmark
    }

    func tableView(_ tableView: UITableView, didDeselectRowAt indexPath: IndexPath) {
        let day = allDays[indexPath.row]
        selectedDays.remove(day)
        tableView.cellForRow(at: indexPath)?.accessoryType = .none
    }
}
