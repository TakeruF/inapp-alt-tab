import AppKit
import AppLocalization

final class SetupWindow: NSWindowController {
    private let statusLabel = NSTextField(wrappingLabelWithString: "")
    private let permissionButton = NSButton(title: L10n.text(.permissionOpen), target: nil, action: nil)
    private var contentStack: NSStackView?
    var onRequestPermission: (() -> Void)?

    init() {
        let window = NSWindow(contentRect: NSRect(x: 0, y: 0, width: 520, height: 480),
                              styleMask: [.titled, .closable, .miniaturizable],
                              backing: .buffered, defer: false)
        window.title = "InApp Alt Tab"
        window.isReleasedWhenClosed = false
        super.init(window: window)
        buildContent(window)
        window.center()
    }

    required init?(coder: NSCoder) { nil }

    func present() {
        showWindow(nil)
        NSApp.activate(ignoringOtherApps: true)
        window?.makeKeyAndOrderFront(nil)
    }

    func update(status: String, trusted: Bool) {
        let changed = statusLabel.stringValue != status
        statusLabel.stringValue = status
        statusLabel.textColor = trusted ? .labelColor : .secondaryLabelColor
        permissionButton.title = L10n.text(trusted ? .permissionReview : .permissionOpen)
        if changed { fitContent() }
    }

    private func buildContent(_ window: NSWindow) {
        guard let content = window.contentView else { return }
        let image = NSImageView()
        image.image = NSImage(named: NSImage.Name("AppIcon")) ?? NSImage(
            systemSymbolName: "rectangle.on.rectangle", accessibilityDescription: L10n.text(.windowIcon))
        image.setAccessibilityLabel(L10n.text(.windowIcon))
        image.imageScaling = .scaleProportionallyUpOrDown
        image.widthAnchor.constraint(equalToConstant: 64).isActive = true
        image.heightAnchor.constraint(equalToConstant: 64).isActive = true
        let title = NSTextField(wrappingLabelWithString: L10n.text(.setupTitle))
        title.font = .systemFont(ofSize: 20, weight: .semibold)
        let description = NSTextField(wrappingLabelWithString: L10n.text(.setupInstructions))
        description.font = .systemFont(ofSize: 13)
        description.textColor = .secondaryLabelColor
        let shortcut = NSTextField(labelWithString: "⌥ Tab     /     ⌥ ⇧ Tab")
        shortcut.font = .monospacedSystemFont(ofSize: 20, weight: .medium)
        statusLabel.font = .systemFont(ofSize: 13)
        permissionButton.target = self
        permissionButton.action = #selector(requestPermission)
        permissionButton.bezelStyle = .rounded
        let footnote = NSTextField(wrappingLabelWithString: L10n.text(.setupFootnote))
        footnote.font = .systemFont(ofSize: 11)
        footnote.textColor = .secondaryLabelColor
        let stack = NSStackView(views: [image, title, description, shortcut, statusLabel, permissionButton, footnote])
        contentStack = stack
        stack.orientation = .vertical
        stack.alignment = .leading
        stack.spacing = 16
        stack.translatesAutoresizingMaskIntoConstraints = false
        content.addSubview(stack)
        for label in [title, description, statusLabel, footnote] {
            label.preferredMaxLayoutWidth = 460
            label.widthAnchor.constraint(equalTo: stack.widthAnchor).isActive = true
        }
        NSLayoutConstraint.activate([
            stack.leadingAnchor.constraint(equalTo: content.leadingAnchor, constant: 30),
            stack.trailingAnchor.constraint(equalTo: content.trailingAnchor, constant: -30),
            stack.topAnchor.constraint(equalTo: content.topAnchor, constant: 25),
            stack.bottomAnchor.constraint(lessThanOrEqualTo: content.bottomAnchor, constant: -25)
        ])
        fitContent()
    }

    private func fitContent() {
        guard let window, let content = window.contentView, let contentStack else { return }
        content.layoutSubtreeIfNeeded()
        let height = max(410, ceil(contentStack.fittingSize.height) + 50)
        window.setContentSize(NSSize(width: 520, height: height))
    }

    @objc private func requestPermission() { onRequestPermission?() }
}
