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

    /// Creates the app's model container.
    ///
    /// - Parameter inMemory: Pass `true` for previews, mocks, and tests.
    ///
    static func make(inMemory: Bool = false) -> ModelContainer {
        do {
            let configuration = ModelConfiguration(schema: schema, isStoredInMemoryOnly: inMemory)
            return try ModelContainer(for: schema, configurations: [configuration])
        } catch {
            Logger(subsystem: "io.apparata.DueDate", category: "ModelContainer")
                .error("Failed to create persistent container: \(error). Falling back to in-memory store.")
            let fallback = ModelConfiguration(schema: schema, isStoredInMemoryOnly: true)
            // swiftlint:disable:next force_try
            return try! ModelContainer(for: schema, configurations: [fallback])
        }
    }
}
