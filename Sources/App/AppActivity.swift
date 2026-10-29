import AppKit
import Observation

/// Tracks the conditions that should pause polling: the window being closed or
/// minimised, the app being hidden, the Mac going to sleep, or the session
/// locking.
@MainActor
@Observable
final class AppActivity {
    private(set) var isWindowVisible = true
    private(set) var isAppHidden = false
    private(set) var isSystemAsleep = false
    private(set) var isSessionLocked = false

    private var observers: [NSObjectProtocol] = []

    var isPaused: Bool {
        !isWindowVisible || isAppHidden || isSystemAsleep || isSessionLocked
    }

    init() {
        let workspace = NSWorkspace.shared.notificationCenter

        observers.append(workspace.addObserver(
            forName: NSWorkspace.willSleepNotification, object: nil, queue: .main
        ) { [weak self] _ in
            Task { @MainActor in self?.isSystemAsleep = true }
        })
        observers.append(workspace.addObserver(
            forName: NSWorkspace.didWakeNotification, object: nil, queue: .main
        ) { [weak self] _ in
            Task { @MainActor in self?.isSystemAsleep = false }
        })
        observers.append(workspace.addObserver(
            forName: NSWorkspace.screensDidSleepNotification, object: nil, queue: .main
        ) { [weak self] _ in
            Task { @MainActor in self?.isSystemAsleep = true }
        })
        observers.append(workspace.addObserver(
            forName: NSWorkspace.screensDidWakeNotification, object: nil, queue: .main
        ) { [weak self] _ in
            Task { @MainActor in self?.isSystemAsleep = false }
        })
        observers.append(workspace.addObserver(
            forName: NSWorkspace.sessionDidResignActiveNotification, object: nil, queue: .main
        ) { [weak self] _ in
            Task { @MainActor in self?.isSessionLocked = true }
        })
        observers.append(workspace.addObserver(
            forName: NSWorkspace.sessionDidBecomeActiveNotification, object: nil, queue: .main
        ) { [weak self] _ in
            Task { @MainActor in self?.isSessionLocked = false }
        })
        observers.append(NotificationCenter.default.addObserver(
            forName: NSApplication.didHideNotification, object: nil, queue: .main
        ) { [weak self] _ in
            Task { @MainActor in self?.isAppHidden = true }
        })
        observers.append(NotificationCenter.default.addObserver(
            forName: NSApplication.didUnhideNotification, object: nil, queue: .main
        ) { [weak self] _ in
            Task { @MainActor in self?.isAppHidden = false }
        })
    }

    func windowVisibilityChanged(_ visible: Bool) {
        isWindowVisible = visible
    }
}
