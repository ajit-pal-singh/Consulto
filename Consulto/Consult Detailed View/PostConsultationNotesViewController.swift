import UIKit

final class PostConsultationNotesViewController: UIViewController, UITextViewDelegate {

    var initialText: String?
    var onSave: ((String?) -> Void)?

    private let placeholderText = "Write post consultation notes..."

    private let textView: UITextView = {
        let view = UITextView()
        view.translatesAutoresizingMaskIntoConstraints = false
        view.backgroundColor = .white
        view.font = .systemFont(ofSize: 17)
        view.layer.cornerRadius = 24
        view.textContainerInset = UIEdgeInsets(top: 18, left: 16, bottom: 18, right: 16)
        return view
    }()

    private let placeholderLabel: UILabel = {
        let label = UILabel()
        label.translatesAutoresizingMaskIntoConstraints = false
        label.text = "Write post consultation notes..."
        label.font = .systemFont(ofSize: 17)
        label.textColor = .secondaryLabel
        label.numberOfLines = 0
        return label
    }()

    override func viewDidLoad() {
        super.viewDidLoad()
        view.backgroundColor = UIColor(hex: "F5F5F5")
        title = "Post Consultation Note"

        navigationItem.leftBarButtonItem = UIBarButtonItem(
            barButtonSystemItem: .cancel,
            target: self,
            action: #selector(cancelTapped)
        )

        navigationItem.rightBarButtonItem = UIBarButtonItem(
            barButtonSystemItem: .done,
            target: self,
            action: #selector(doneTapped)
        )

        textView.delegate = self
        textView.text = initialText

        view.addSubview(textView)
        textView.addSubview(placeholderLabel)

        NSLayoutConstraint.activate([
            textView.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor, constant: 20),
            textView.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 16),
            textView.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -16),
            textView.bottomAnchor.constraint(equalTo: view.safeAreaLayoutGuide.bottomAnchor, constant: -16),

            placeholderLabel.topAnchor.constraint(equalTo: textView.topAnchor, constant: 18),
            placeholderLabel.leadingAnchor.constraint(equalTo: textView.leadingAnchor, constant: 21),
            placeholderLabel.trailingAnchor.constraint(equalTo: textView.trailingAnchor, constant: -21)
        ])

        updatePlaceholderVisibility()
    }

    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
        textView.becomeFirstResponder()
    }

    func textViewDidChange(_ textView: UITextView) {
        updatePlaceholderVisibility()
    }

    @objc private func cancelTapped() {
        dismiss(animated: true)
    }

    @objc private func doneTapped() {
        let trimmed = textView.text.trimmingCharacters(in: .whitespacesAndNewlines)
        onSave?(trimmed.isEmpty ? nil : trimmed)
        dismiss(animated: true)
    }

    private func updatePlaceholderVisibility() {
        placeholderLabel.isHidden = !textView.text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }
}
