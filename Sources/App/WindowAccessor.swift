import AppKit
import SwiftUI

/// Reports whether the window is visible, so polling can pause when it isn't.
/// A tiny NSView subclass is the reliable way to observe the window without
/// capturing a non-Sendable view in a background callback.
struct WindowAccessor: NSViewRepresentable {
    let onVisibilityChange: @MainActor (Bool) -> Void

    func makeCoordinator() -> Coordinator {
        Coordinator(onVisibilityChange: onVisibilityChange)
    }

    func makeNSView(context: Context) -> WindowObservingView {
        let view = WindowObservingView(frame: .zero)
        view.onWindowChange = { [coordinator = context.coordinator] window in
            coordinator.attach(to: window)
        }
        return view
    }

    func updateNSView(_ nsView: WindowObservingView, context: Context) {
        context.coordinator.onVisibilityChange = onVisibilityChange
        if let window = nsView.window {
            context.coordinator.attach(to: window)
        }
    }

    @MainActor
    final class Coordinator {
        var onVisibilityChange: (Bool) -> Void
        private weak var window: NSWindow?
        private var observers: [NSObjectProtocol] = []

        init(onVisibilityChange: @escaping (Bool) -> Void) {
            self.onVisibilityChange = onVisibilityChange
        }

        func attach(to window: NSWindow?) {
            guard let window else {
                report(false)
                return
            }
            guard self.window !== window else {
                report()
                return
            }
            self.window = window

            let center = NotificationCenter.default
            for token in observers {
                center.removeObserver(token)
            }
            observers.removeAll()

            let names: [Notification.Name] = [
                NSWindow.didMiniaturizeNotification,
                NSWindow.didDeminiaturizeNotification,
                NSWindow.didBecomeKeyNotification,
            ]
            for name in names {
                observers.append(center.addObserver(forName: name, object: window, queue: .main) { [weak self] _ in
                    Task { @MainActor in self?.report() }
                })
            }
            observers.append(center.addObserver(
                forName: NSWindow.willCloseNotification, object: window, queue: .main
            ) { [weak self] _ in
                Task { @MainActor in self?.onVisibilityChange(false) }
            })
            report()
        }

        private func report() {
            guard let window else {
                report(false)
                return
            }
            onVisibilityChange(window.isVisible && !window.isMiniaturized)
        }

        private func report(_ visible: Bool) {
            onVisibilityChange(visible)
        }
    }
}

final class WindowObservingView: NSView {
    var onWindowChange: (@MainActor (NSWindow?) -> Void)?

    override func viewDidMoveToWindow() {
        super.viewDidMoveToWindow()
        onWindowChange?(window)
    }
}
