import AppKit

final class SetupWindow: NSWindowController {
    private let statusLabel = NSTextField(wrappingLabelWithString: "")
    private let permissionButton = NSButton(title: "アクセシビリティ設定を開く", target: nil, action: nil)
    var onRequestPermission: (() -> Void)?

    init() {
        let window = NSWindow(contentRect: NSRect(x: 0, y: 0, width: 470, height: 410),
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
        statusLabel.stringValue = status
        statusLabel.textColor = trusted ? .labelColor : .secondaryLabelColor
        permissionButton.title = trusted ? "アクセシビリティ設定を確認" : "アクセシビリティ設定を開く"
    }

    private func buildContent(_ window: NSWindow) {
        guard let content = window.contentView else { return }
        let image = NSImageView()
        image.image = NSImage(systemSymbolName: "rectangle.on.rectangle", accessibilityDescription: nil)
        image.contentTintColor = .controlAccentColor
        image.symbolConfiguration = NSImage.SymbolConfiguration(pointSize: 34, weight: .medium)
        let title = NSTextField(labelWithString: "いまのアプリ内で、すぐ切り替え。")
        title.font = .systemFont(ofSize: 20, weight: .semibold)
        let description = NSTextField(wrappingLabelWithString:
            "Option（Alt）＋Tab で次のウィンドウへ。\nShift を加えると逆方向に切り替えます。\nOption を押したまま Tab を繰り返すと順番に巡回します。")
        description.font = .systemFont(ofSize: 13)
        description.textColor = .secondaryLabelColor
        let shortcut = NSTextField(labelWithString: "⌥ Tab     /     ⌥ ⇧ Tab")
        shortcut.font = .monospacedSystemFont(ofSize: 20, weight: .medium)
        statusLabel.font = .systemFont(ofSize: 13)
        permissionButton.target = self
        permissionButton.action = #selector(requestPermission)
        permissionButton.bezelStyle = .rounded
        let footnote = NSTextField(wrappingLabelWithString:
            "設定で「InApp Alt Tab」をオンにしてください。\nウィンドウが1つのときは何もしません。この画面を閉じてもメニューバーに常駐します。")
        footnote.font = .systemFont(ofSize: 11)
        footnote.textColor = .secondaryLabelColor
        let stack = NSStackView(views: [image, title, description, shortcut, statusLabel, permissionButton, footnote])
        stack.orientation = .vertical
        stack.alignment = .leading
        stack.spacing = 16
        stack.translatesAutoresizingMaskIntoConstraints = false
        content.addSubview(stack)
        NSLayoutConstraint.activate([
            stack.leadingAnchor.constraint(equalTo: content.leadingAnchor, constant: 30),
            stack.trailingAnchor.constraint(equalTo: content.trailingAnchor, constant: -30),
            stack.topAnchor.constraint(equalTo: content.topAnchor, constant: 25),
            stack.bottomAnchor.constraint(lessThanOrEqualTo: content.bottomAnchor, constant: -25)
        ])
    }

    @objc private func requestPermission() { onRequestPermission?() }
}
