//
//  Copyright © 2026 Apparata AB. All rights reserved.
//

import Foundation
import SwiftData

/// A reusable payment method record that subscriptions reference.
///
/// Encourages aliases over sensitive details: "Visa debit •••• 1234",
/// never full card or bank account numbers (spec Section 25).
@Model
final class PaymentMethod {

    var id: UUID = UUID()
    var displayName: String = ""
    var kindRaw: String = PaymentMethodKind.other.rawValue
    var institutionName: String = ""
    var lastFour: String = ""
    var expirationDate: Date? = nil
    var owner: String = ""
    var notes: String = ""
    var isArchived: Bool = false
    var isSampleData: Bool = false

    @Relationship(deleteRule: .nullify, inverse: \Subscription.paymentMethod)
    var subscriptions: [Subscription]? = nil

    init() {}

    convenience init(displayName: String, kind: PaymentMethodKind, institutionName: String = "", lastFour: String = "") {
        self.init()
        self.displayName = displayName
        self.kindRaw = kind.rawValue
        self.institutionName = institutionName
        self.lastFour = lastFour
    }

    var kind: PaymentMethodKind {
        get { PaymentMethodKind(rawValue: kindRaw) ?? .other }
        set { kindRaw = newValue.rawValue }
    }
}
