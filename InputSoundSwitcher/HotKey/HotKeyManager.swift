import Foundation
import HotKey
import Carbon

final class HotKeyManager: ObservableObject {
    @Published var currentKeyCombo: String = "⌘⇧M"

    private var hotKey: HotKey?
    var onHotKeyPressed: (() -> Void)?

    init() {
        setupHotKey()
    }

    private func setupHotKey() {
        // Default: Cmd+Shift+M
        hotKey = HotKey(key: .m, modifiers: [.command, .shift])
        hotKey?.keyDownHandler = { [weak self] in
            self?.onHotKeyPressed?()
        }
    }
}
