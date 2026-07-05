//
//  Copyright © 2026 Apparata AB. All rights reserved.
//

import Foundation
import SwiftData

/// A user-editable category for grouping subscriptions.
///
/// Named `SubscriptionCategory` rather than `Category` to avoid collisions
/// with framework types; the display name in the UI is still "Category".
@Model
final class SubscriptionCategory {

    var id: UUID = UUID()
    var name: String = ""
    var colorHex: String = ""
    var symbolName: String = ""
    var isBuiltIn: Bool = false
    var sortOrder: Int = 0

    @Relationship(deleteRule: .nullify, inverse: \Subscription.category)
    var subscriptions: [Subscription]? = nil

    init() {}

    convenience init(name: String, colorHex: String = "", symbolName: String = "", isBuiltIn: Bool = false, sortOrder: Int = 0) {
        self.init()
        self.name = name
        self.colorHex = colorHex
        self.symbolName = symbolName
        self.isBuiltIn = isBuiltIn
        self.sortOrder = sortOrder
    }
}
