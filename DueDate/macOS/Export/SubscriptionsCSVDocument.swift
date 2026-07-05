//
//  Copyright © 2026 Apparata AB. All rights reserved.
//

import SwiftUI
import UniformTypeIdentifiers

/// A pre-serialized CSV export for `fileExporter`. Carries only `Data`,
/// so it is safely `Sendable` and nonisolated.
nonisolated struct SubscriptionsCSVDocument: FileDocument, Sendable {

    static let readableContentTypes: [UTType] = [.commaSeparatedText]

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
