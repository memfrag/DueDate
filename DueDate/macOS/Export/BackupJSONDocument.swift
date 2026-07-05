//
//  Copyright © 2026 Apparata AB. All rights reserved.
//

import SwiftUI
import UniformTypeIdentifiers

/// A pre-serialized JSON backup for `fileExporter`. Carries only `Data`,
/// so it is safely `Sendable` and nonisolated.
nonisolated struct BackupJSONDocument: FileDocument, Sendable {

    static let readableContentTypes: [UTType] = [.json]

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
