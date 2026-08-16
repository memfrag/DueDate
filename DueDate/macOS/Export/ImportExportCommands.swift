//
//  Copyright © 2026 Apparata AB. All rights reserved.
//

import SwiftUI

/// File menu export commands (spec Section 26):
/// a complete JSON backup and a spreadsheet-friendly CSV.
struct ExportCommands: Commands {

    @State private var jsonDocument: BackupJSONDocument?
    @State private var csvDocument: SubscriptionsCSVDocument?

    var body: some Commands {
        CommandGroup(replacing: .importExport) {
            Section {
                Button("Export Backup (JSON)…") {
                    let environment = AppEnvironment.default
                    jsonDocument = (try? ImportExportService.makeBackupData(
                        context: environment.modelContainer.mainContext,
                        settings: environment.appSettings
                    )).map(BackupJSONDocument.init(data:))
                }

                Button("Export Subscriptions (CSV)…") {
                    let environment = AppEnvironment.default
                    csvDocument = SubscriptionsCSVDocument(
                        data: ImportExportService.makeCSVData(
                            context: environment.modelContainer.mainContext,
                            settings: environment.appSettings,
                            rateTable: environment.exchangeRateService.table
                        )
                    )
                }
            }
            .fileExporter(
                isPresented: Binding(
                    get: { jsonDocument != nil },
                    set: { if !$0 { jsonDocument = nil } }
                ),
                document: jsonDocument,
                contentType: .json,
                defaultFilename: "DueDate Backup"
            ) { _ in
                jsonDocument = nil
            }
            .fileExporter(
                isPresented: Binding(
                    get: { csvDocument != nil },
                    set: { if !$0 { csvDocument = nil } }
                ),
                document: csvDocument,
                contentType: .commaSeparatedText,
                defaultFilename: "DueDate Subscriptions"
            ) { _ in
                csvDocument = nil
            }
        }
    }
}
