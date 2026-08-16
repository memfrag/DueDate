//
//  Copyright © 2026 Apparata AB. All rights reserved.
//

import AppKit
import SwiftData
import OSLog

/// Drives the "Import Backup (JSON)…" flow: pick a file, decode it, ask how to
/// apply it, apply it, report what happened.
///
/// This uses `NSOpenPanel` / `NSAlert` rather than SwiftUI's `.fileImporter`
/// and `.confirmationDialog` deliberately. A `Commands` menu hosts exactly one
/// SwiftUI presentation, and ``ImportExportCommands`` already spends it on the
/// export `.fileExporter`; adding more silently breaks whichever ones lose the
/// race. AppKit panels have no such limit.
enum ImportCoordinator {

    private static let log = Logger(subsystem: "io.apparata.DueDate", category: "Import")

    static func run(context: ModelContext, settings: AppSettings) {
        guard let url = chooseFile() else { return }

        let backup: BackupFile
        do {
            let data = try Data(contentsOf: url)
            backup = try ImportExportService.readBackup(data)
        } catch {
            log.error("Failed to read backup at \(url.lastPathComponent): \(error)")
            presentError(
                title: "Couldn't Read Backup",
                message: error.localizedDescription
            )
            return
        }

        guard let mode = chooseMode(for: backup, filename: url.lastPathComponent) else { return }
        if mode == .replaceAll, !confirmReplace() { return }

        do {
            let summary = try ImportExportService.applyBackup(
                backup,
                mode: mode,
                context: context,
                settings: settings
            )
            log.info("Imported backup: \(String(describing: summary))")
            presentSummary(summary, mode: mode)
        } catch {
            log.error("Failed to apply backup: \(error)")
            presentError(
                title: "Import Failed",
                message: error.localizedDescription
            )
        }
    }

    // MARK: - Panels

    private static func chooseFile() -> URL? {
        let panel = NSOpenPanel()
        panel.title = "Import Backup"
        panel.message = "Choose a DueDate JSON backup."
        panel.allowedContentTypes = [.json]
        panel.allowsMultipleSelection = false
        panel.canChooseDirectories = false
        return panel.runModal() == .OK ? panel.url : nil
    }

    private static func chooseMode(for backup: BackupFile, filename: String) -> ImportExportService.ImportMode? {
        let alert = NSAlert()
        alert.messageText = "Import “\(filename)”?"
        alert.informativeText = """
            Exported \(backup.exportedAt.formatted(date: .abbreviated, time: .shortened)).

            Contains \(backup.subscriptions.count) subscriptions, \
            \(backup.categories.count) categories, and \
            \(backup.paymentMethods.count) payment methods.

            Merge updates matching records and adds missing ones, keeping \
            everything else. Replace All removes your current data first.
            """
        alert.addButton(withTitle: "Merge")
        alert.addButton(withTitle: "Replace All…")
        alert.addButton(withTitle: "Cancel")

        switch alert.runModal() {
        case .alertFirstButtonReturn: return .merge
        case .alertSecondButtonReturn: return .replaceAll
        default: return nil
        }
    }

    /// Replace deletes data on every synced device, so it gets its own
    /// destructive confirmation rather than riding on the first dialog.
    private static func confirmReplace() -> Bool {
        let alert = NSAlert()
        alert.alertStyle = .critical
        alert.messageText = "Replace all data?"
        alert.informativeText = """
            Every subscription, category and payment method currently in \
            DueDate will be deleted and replaced with the contents of the \
            backup. If iCloud sync is on, this also removes them from your \
            other devices. This can't be undone.
            """
        alert.addButton(withTitle: "Replace All")
        alert.addButton(withTitle: "Cancel")
        return alert.runModal() == .alertFirstButtonReturn
    }

    private static func presentSummary(_ summary: ImportExportService.ImportSummary, mode: ImportExportService.ImportMode) {
        let alert = NSAlert()
        alert.messageText = "Import Complete"

        var lines: [String] = []
        if summary.deleted > 0 {
            lines.append("Removed \(summary.deleted) existing records.")
        }
        lines.append("Subscriptions: \(summary.subscriptionsInserted) added, \(summary.subscriptionsUpdated) updated.")
        lines.append("Categories: \(summary.categoriesInserted) added, \(summary.categoriesUpdated) updated.")
        lines.append("Payment methods: \(summary.paymentMethodsInserted) added, \(summary.paymentMethodsUpdated) updated.")
        if mode == .replaceAll {
            lines.append("Settings were restored from the backup.")
        }

        alert.informativeText = lines.joined(separator: "\n")
        alert.addButton(withTitle: "OK")
        alert.runModal()
    }

    private static func presentError(title: String, message: String) {
        let alert = NSAlert()
        alert.alertStyle = .warning
        alert.messageText = title
        alert.informativeText = message
        alert.addButton(withTitle: "OK")
        alert.runModal()
    }
}
