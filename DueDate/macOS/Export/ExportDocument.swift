//
//  Copyright © 2026 Apparata AB. All rights reserved.
//

import SwiftUI
import UniformTypeIdentifiers

/// A pre-serialized export payload for `fileExporter`. Carries only `Data`,
/// so it is safely `Sendable` and nonisolated.
///
/// One document type covers both the JSON backup and the CSV export because
/// the File menu can host only a single `.fileExporter` (see ``ExportCommands``);
/// the concrete type of a given export is chosen by the `contentType` passed to
/// the exporter, not by the document.
nonisolated struct ExportDocument: FileDocument, Sendable {

    static let readableContentTypes: [UTType] = [.json, .commaSeparatedText]

    let data: Data

    init(data: Data) {
        self.data = data
    }

    init(configuration: ReadConfiguration) throws {
        data = configuration.file.regularFileContents ?? Data()
    }

    func fileWrapper(configuration: WriteConfiguration) throws -> FileWrapper {
        FileWrapper(regularFileWithContents: data)
    }
}
