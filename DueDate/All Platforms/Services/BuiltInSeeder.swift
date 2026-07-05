//
//  Copyright © 2026 Apparata AB. All rights reserved.
//

import Foundation
import SwiftData

/// Seeds the built-in categories once per store (spec Section 20).
enum BuiltInSeeder {

    /// (name, colorHex, SF Symbol)
    static let builtInCategories: [(String, String, String)] = [
        ("Streaming", "E74C3C", "play.tv"),
        ("Internet", "3498DB", "wifi"),
        ("Mobile", "9B59B6", "iphone"),
        ("Software", "2980B9", "app.badge"),
        ("Cloud", "5DADE2", "icloud"),
        ("Domains", "16A085", "globe"),
        ("Hosting", "27AE60", "server.rack"),
        ("Utilities", "F39C12", "bolt"),
        ("Gaming", "8E44AD", "gamecontroller"),
        ("News", "34495E", "newspaper"),
        ("Music", "E91E63", "music.note"),
        ("Fitness", "2ECC71", "figure.run"),
        ("Finance", "1ABC9C", "banknote"),
        ("Insurance", "7F8C8D", "shield"),
        ("Membership", "D35400", "person.2"),
        ("Other", "95A5A6", "square.grid.2x2")
    ]

    /// Inserts the built-in categories if the store has none yet.
    /// Idempotent: guarded by an existence check rather than a settings flag,
    /// so it also heals a store whose seed was interrupted.
    static func seedIfNeeded(context: ModelContext) {
        let descriptor = FetchDescriptor<SubscriptionCategory>(
            predicate: #Predicate { $0.isBuiltIn }
        )
        let existingCount = (try? context.fetchCount(descriptor)) ?? 0
        guard existingCount == 0 else { return }

        for (index, (name, colorHex, symbolName)) in builtInCategories.enumerated() {
            let category = SubscriptionCategory(
                name: name,
                colorHex: colorHex,
                symbolName: symbolName,
                isBuiltIn: true,
                sortOrder: index
            )
            context.insert(category)
        }
        try? context.save()
    }
}
