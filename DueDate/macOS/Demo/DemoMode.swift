//
//  Copyright © 2026 Apparata AB. All rights reserved.
//

import AppKit
import OSLog

/// Demo mode: the app runs against a throwaway in-memory store seeded with
/// sample data, so it can be shown or screenshotted without exposing — or
/// touching — real subscriptions.
///
/// The flag lives in `UserDefaults` rather than ``AppSettings`` because it is
/// read while the environment is being built, before settings exist, and it has
/// to survive the relaunch. Deliberately **not** a synced value: which mode a
/// given Mac is in is a property of that Mac.
///
/// Isolation is total: a separate `ModelContainer`, in-memory and pinned to
/// `cloudKitDatabase: .none`, so nothing demo-related can reach iCloud and
/// nothing entered during a demo outlives it. Settings are in-memory too, so
/// changing the display currency to show it off doesn't rewrite real prefs.
enum DemoMode {

    private static let defaultsKey = "DemoMode.enabled"
    private static let log = Logger(subsystem: "io.apparata.DueDate", category: "DemoMode")

    static var isEnabled: Bool {
        UserDefaults.standard.bool(forKey: defaultsKey)
    }

    /// Switches into demo mode and restarts. Real data is left exactly as it is.
    static func enter() {
        setEnabled(true)
        relaunch(explanation: "DueDate will restart in demo mode. Your real subscriptions stay where they are, and nothing from the demo is saved or synced.")
    }

    /// Switches back to real data and restarts, discarding the demo store.
    static func exit() {
        setEnabled(false)
        relaunch(explanation: "DueDate will restart with your real subscriptions. Anything changed during the demo is discarded.")
    }

    private static func setEnabled(_ enabled: Bool) {
        UserDefaults.standard.set(enabled, forKey: defaultsKey)
        // The relaunch reads this from a separate process, so it must be on
        // disk before this one exits.
        UserDefaults.standard.synchronize()
    }

    /// Relaunches the app. Falls back to quitting with an explanation if the
    /// sandbox refuses to open a second instance.
    private static func relaunch(explanation: String) {
        let alert = NSAlert()
        alert.messageText = "Restart DueDate?"
        alert.informativeText = explanation
        alert.addButton(withTitle: "Restart")
        alert.addButton(withTitle: "Cancel")
        guard alert.runModal() == .alertFirstButtonReturn else {
            // Leave the flag as the user found it.
            setEnabled(!isEnabled)
            return
        }

        let configuration = NSWorkspace.OpenConfiguration()
        configuration.createsNewApplicationInstance = true
        NSWorkspace.shared.openApplication(
            at: Bundle.main.bundleURL,
            configuration: configuration
        ) { _, error in
            Task { @MainActor in
                if let error {
                    log.error("Could not relaunch automatically: \(error)")
                    presentManualRestart()
                } else {
                    NSApp.terminate(nil)
                }
            }
        }
    }

    private static func presentManualRestart() {
        let alert = NSAlert()
        alert.messageText = "Quit and Reopen DueDate"
        alert.informativeText = "DueDate couldn't restart itself. Quit and open it again — the new mode is already saved and takes effect on the next launch."
        alert.addButton(withTitle: "Quit")
        alert.addButton(withTitle: "Later")
        if alert.runModal() == .alertFirstButtonReturn {
            NSApp.terminate(nil)
        }
    }
}
