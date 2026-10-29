import SwiftUI

@main
struct OversightApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) private var appDelegate
    @State private var env: AppEnvironment

    init() {
        _env = State(initialValue: AppEnvironment.live())
    }

    var body: some Scene {
        WindowGroup("Oversight") {
            DashboardView(env: env)
        }
        .defaultSize(width: 1180, height: 900)
        .commands {
            OversightCommands(env: env)
        }

        Settings {
            SettingsView(env: env)
        }
    }
}

final class AppDelegate: NSObject, NSApplicationDelegate {
    /// Closing the window pauses polling instead of quitting, so ⌘W then
    /// reopening the window is cheap.
    func applicationShouldTerminateAfterLastWindowClosed(_: NSApplication) -> Bool {
        false
    }

    func applicationDidFinishLaunching(_: Notification) {
        // Launched from a terminal or Xcode the window can open behind other
        // apps; a single-window dashboard should come forward.
        NSApplication.shared.activate(ignoringOtherApps: true)
    }
}

@MainActor
struct OversightCommands: Commands {
    let env: AppEnvironment

    var body: some Commands {
        // A single-window app doesn't need a New Window command.
        CommandGroup(replacing: .newItem) {}

        CommandGroup(after: .toolbar) {
            Button("Refresh") {
                Task { await env.model.refreshAll() }
            }
            .keyboardShortcut("r", modifiers: .command)
            .disabled(env.model.isRefreshing)
        }
    }
}
