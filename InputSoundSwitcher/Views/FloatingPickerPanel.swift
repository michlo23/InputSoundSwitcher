import AppKit
import SwiftUI

final class FloatingPickerPanel: NSPanel {
    private var eventMonitor: Any?

    init(hostingView: NSView) {
        super.init(
            contentRect: NSRect(x: 0, y: 0, width: 320, height: 200),
            styleMask: [.nonactivatingPanel, .titled, .fullSizeContentView],
            backing: .buffered,
            defer: true
        )

        isFloatingPanel = true
        level = .floating
        isOpaque = false
        backgroundColor = .clear
        hidesOnDeactivate = false
        isMovableByWindowBackground = false
        titleVisibility = .hidden
        titlebarAppearsTransparent = true
        acceptsMouseMovedEvents = true

        // Build view hierarchy: container > visual effect background + hosting view on top
        let container = NSView(frame: NSRect(x: 0, y: 0, width: 320, height: 200))
        container.wantsLayer = true

        let visualEffect = NSVisualEffectView(frame: container.bounds)
        visualEffect.autoresizingMask = [.width, .height]
        visualEffect.material = .hudWindow
        visualEffect.state = .active
        visualEffect.blendingMode = .behindWindow
        visualEffect.wantsLayer = true
        visualEffect.layer?.cornerRadius = 12
        visualEffect.layer?.masksToBounds = true

        hostingView.autoresizingMask = [.width, .height]
        hostingView.frame = container.bounds

        container.addSubview(visualEffect)
        container.addSubview(hostingView)

        self.contentView = container
    }

    override var canBecomeKey: Bool { true }
    override var canBecomeMain: Bool { true }

    func showPicker() {
        positionNearMenuBar()
        makeKeyAndOrderFront(nil)
        NSApp.activate(ignoringOtherApps: true)
        installEventMonitor()
    }

    func dismissPicker() {
        removeEventMonitor()
        orderOut(nil)
    }

    func toggle() {
        if isVisible {
            dismissPicker()
        } else {
            showPicker()
        }
    }

    override func keyDown(with event: NSEvent) {
        if event.keyCode == 53 { // Escape key
            dismissPicker()
        } else {
            super.keyDown(with: event)
        }
    }

    private func positionNearMenuBar() {
        guard let screen = NSScreen.main else { return }
        let screenFrame = screen.visibleFrame
        let menuBarHeight = screen.frame.height - screenFrame.height - screenFrame.origin.y
        let panelWidth = frame.width
        let x = (screen.frame.width - panelWidth) / 2
        let y = screen.frame.height - menuBarHeight - frame.height - 8
        setFrameOrigin(NSPoint(x: x, y: y))
    }

    private func installEventMonitor() {
        removeEventMonitor()
        eventMonitor = NSEvent.addGlobalMonitorForEvents(matching: [.leftMouseDown, .rightMouseDown]) { [weak self] _ in
            guard let self, self.isVisible else { return }
            if !self.frame.contains(NSEvent.mouseLocation) {
                self.dismissPicker()
            }
        }
    }

    private func removeEventMonitor() {
        if let monitor = eventMonitor {
            NSEvent.removeMonitor(monitor)
            eventMonitor = nil
        }
    }
}
