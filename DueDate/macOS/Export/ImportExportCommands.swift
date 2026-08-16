//
//  Copyright © 2026 Apparata AB. All rights reserved.
//

import SwiftUI
import UniformTypeIdentifiers
import OSLog

/// File menu import/export commands (spec Section 26): a complete JSON backup,
/// a spreadsheet-friendly CSV, and restoring a backup.
///
/// **A menu can host exactly one `.fileExporter`, and it must sit on the
/// `Section`, not on a `Button`.** Two exporters stacked on the same view
/// silently collapse to the outermost one, leaving the other menu item doing
/// nothing at all; moving them onto the individual buttons stops both from
/// presenting. Hence one exporter driven by one ``PendingExport``, whose
/// content type and filename vary per export.
struct ImportExportCommands: Commands {

    /// A built payload waiting for the user to pick a destination.
    private struct PendingExport {
        let document: ExportDocument
        let contentType: UTType
        let filename: String
    }

    @State private var pendingExport: PendingExport?

    private static let log = Logger(subsystem: "io.apparata.DueDate", category: "Export")

    var body: some Commands {
        CommandGroup(replacing: .importExport) {
            Section {
                Button("Import Backup (JSON)…") {
                    let environment = AppEnvironment.default
                    ImportCoordinator.run(
                        context: environment.modelContainer.mainContext,
                        settings: environment.appSettings
                    )
                    Task { await environment.notificationManager.resync() }
                }

                Button("Export Backup (JSON)…") {
                    let environment = AppEnvironment.default
                    do {
                        let data = try ImportExportService.makeBackupData(
                            context: environment.modelContainer.mainContext,
                            settings: environment.appSettings
                        )
                        pendingExport = PendingExport(
                            document: ExportDocument(data: data),
                            contentType: .json,
                            filename: "DueDate Backup"
                        )
                    } catch {
                        // Swallowing this leaves the menu item looking dead.
                        Self.log.error("Failed to build JSON backup: \(error)")
                    }
                }

                Button("Export Subscriptions (CSV)…") {
                    let environment = AppEnvironment.default
                    let data = ImportExportService.makeCSVData(
                        context: environment.modelContainer.mainContext,
                        settings: environment.appSettings,
                        rateTable: environment.exchangeRateService.table
                    )
                    pendingExport = PendingExport(
                        document: ExportDocument(data: data),
                        contentType: .commaSeparatedText,
                        filename: "DueDate Subscriptions"
                    )
                }
            }
            .fileExporter(
                isPresented: Binding(
                    get: { pendingExport != nil },
                    set: { if !$0 { pendingExport = nil } }
                ),
                document: pendingExport?.document,
                contentType: pendingExport?.contentType ?? .json,
                defaultFilename: pendingExport?.filename ?? "DueDate Export"
            ) { result in
                if case .failure(let error) = result {
                    Self.log.error("Export failed: \(error)")
                }
                pendingExport = nil
            }
        }
    }
}
