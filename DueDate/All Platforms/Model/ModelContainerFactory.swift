//
//  Copyright © 2026 Apparata AB. All rights reserved.
//

import Foundation
import SwiftData
import OSLog

enum ModelContainerFactory {

    static let schema = Schema([
        Subscription.self,
        SubscriptionCategory.self,
        PaymentMethod.self
    ])

    private static let log = Logger(subsystem: "io.apparata.DueDate", category: "ModelContainer")

    /// Creates the app's model container.
    ///
    /// The persistent store is mirrored to the user's private CloudKit database
    /// (`cloudKitDatabase: .automatic` picks up the container from the app's
    /// entitlement). Mirroring is best-effort: if CloudKit is unavailable —
    /// unsigned build, no iCloud account, or a schema the mirroring layer
    /// rejects — the app falls back to a local-only store and keeps working.
    ///
    /// - Parameter inMemory: Pass `true` for previews, mocks, and tests. In-memory
    ///   stores are always `cloudKitDatabase: .none` so they never touch iCloud.
    ///
    static func make(inMemory: Bool = false) -> ModelContainer {
        if inMemory {
            return makeInMemory()
        }

        do {
            let configuration = ModelConfiguration(schema: schema, cloudKitDatabase: .automatic)
            let container = try ModelContainer(for: schema, configurations: [configuration])
            log.info("Model container created with CloudKit mirroring.")
            return container
        } catch {
            // The specific reason (e.g. a CloudKit schema violation) is logged by the
            // com.apple.coredata subsystem, not carried on the thrown error.
            log.error("CloudKit unavailable: \(error). Falling back to a local-only store.")
        }

        do {
            let local = ModelConfiguration(schema: schema, cloudKitDatabase: .none)
            return try ModelContainer(for: schema, configurations: [local])
        } catch {
            log.error("Failed to create persistent container: \(error). Falling back to in-memory store.")
            return makeInMemory()
        }
    }

    private static func makeInMemory() -> ModelContainer {
        let configuration = ModelConfiguration(
            schema: schema,
            isStoredInMemoryOnly: true,
            cloudKitDatabase: .none
        )
        // swiftlint:disable:next force_try
        return try! ModelContainer(for: schema, configurations: [configuration])
    }
}
