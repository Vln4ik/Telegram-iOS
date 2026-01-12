import UIKit
import Display
import TelegramPresentationData

final class BackendLoginController: ViewController {
    private enum State {
        case phone
        case code(phone: String)
    }

    private let presentationData: PresentationData
    private let api: BackendAPI
    private let session: BackendSession

    private let stackView = UIStackView()
    private let phoneField = UITextField()
    private let codeField = UITextField()
    private let nameField = UITextField()
    private let actionButton = UIButton(type: .system)
    private let errorLabel = UILabel()

    private var state: State = .phone

    var onAuthorized: (() -> Void)?

    init(presentationData: PresentationData) {
        self.presentationData = presentationData
        self.api = BackendAPI.shared
        self.session = BackendSession.shared
        super.init(navigationBarPresentationData: nil)
        self.title = "Log In"
    }

    required init(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    override func viewDidLoad() {
        super.viewDidLoad()

        view.backgroundColor = presentationData.theme.list.plainBackgroundColor

        stackView.axis = .vertical
        stackView.spacing = 12
        stackView.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(stackView)

        configureTextField(phoneField, placeholder: "+79990001122", keyboard: .phonePad)
        configureTextField(codeField, placeholder: "000000", keyboard: .numberPad)
        configureTextField(nameField, placeholder: "Name", keyboard: .default)

        actionButton.setTitle("Send Code", for: .normal)
        actionButton.titleLabel?.font = Font.medium(17)
        actionButton.tintColor = presentationData.theme.rootController.navigationBar.accentTextColor
        actionButton.addTarget(self, action: #selector(actionTapped), for: .touchUpInside)

        errorLabel.font = Font.regular(14)
        errorLabel.textColor = presentationData.theme.list.itemDestructiveColor
        errorLabel.numberOfLines = 0
        errorLabel.isHidden = true

        stackView.addArrangedSubview(phoneField)
        stackView.addArrangedSubview(codeField)
        stackView.addArrangedSubview(nameField)
        stackView.addArrangedSubview(actionButton)
        stackView.addArrangedSubview(errorLabel)

        NSLayoutConstraint.activate([
            stackView.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 24),
            stackView.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -24),
            stackView.centerYAnchor.constraint(equalTo: view.centerYAnchor)
        ])

        updateState(.phone)
    }

    private func configureTextField(_ field: UITextField, placeholder: String, keyboard: UIKeyboardType) {
        field.borderStyle = .roundedRect
        field.font = Font.regular(17)
        field.keyboardType = keyboard
        field.autocorrectionType = .no
        field.autocapitalizationType = .none
        field.placeholder = placeholder
        field.backgroundColor = presentationData.theme.list.itemBlocksBackgroundColor
        field.textColor = presentationData.theme.list.itemPrimaryTextColor
    }

    private func updateState(_ state: State) {
        self.state = state
        errorLabel.isHidden = true

        switch state {
        case .phone:
            codeField.isHidden = true
            nameField.isHidden = true
            phoneField.isHidden = false
            actionButton.setTitle("Send Code", for: .normal)
        case .code:
            codeField.isHidden = false
            nameField.isHidden = false
            phoneField.isHidden = false
            actionButton.setTitle("Verify", for: .normal)
        }
    }

    @objc private func actionTapped() {
        errorLabel.isHidden = true
        actionButton.isEnabled = false

        switch state {
        case .phone:
            let phone = phoneField.text?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
            guard !phone.isEmpty else {
                showError("Phone required")
                return
            }
            Task { @MainActor in
                do {
                    try await api.requestAuthCode(phone: phone)
                    updateState(.code(phone: phone))
                } catch {
                    showError("Failed to send code")
                }
                actionButton.isEnabled = true
            }
        case let .code(phone):
            let code = codeField.text?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
            let name = nameField.text?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
            guard !code.isEmpty else {
                showError("Code required")
                return
            }
            Task { @MainActor in
                do {
                    let auth = try await api.verifyCode(phone: phone, code: code, name: name)
                    session.update(from: auth)
                    onAuthorized?()
                } catch {
                    showError("Failed to verify code")
                }
                actionButton.isEnabled = true
            }
        }
    }

    private func showError(_ text: String) {
        errorLabel.text = text
        errorLabel.isHidden = false
        actionButton.isEnabled = true
    }
}
