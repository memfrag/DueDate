//
//  Copyright © 2026 Apparata AB. All rights reserved.
//

import Foundation
import SwiftData

/// A recurring cost or commitment, such as a streaming service, a domain
/// name, hosting, insurance, or a SaaS product.
///
/// CloudKit-compatibility rules (spec Section 22): no unique attributes,
/// all relationships optional, and a default value for every stored property.
/// Enums with associated values are stored as raw scalar fields with computed
/// wrappers in `Subscription+Wrappers.swift`; the raw fields stay `internal`
/// so `#Predicate` can reference them.
@Model
final class Subscription {

    var id: UUID = UUID()
    var name: String = ""
    var subscriptionDescription: String = ""
    var statusRaw: String = SubscriptionStatus.active.rawValue

    var amount: Decimal = Decimal(0)
    var currencyCode: String = "SEK"

    // Billing cycle, stored as scalars (see `billingCycle` wrapper).
    var billingCycleKindRaw: String = BillingCycleKind.monthly.rawValue
    var billingCycleValue: Int = 1
    var billingCycleUnitRaw: String = BillingUnit.months.rawValue

    /// Day-of-month anchor (1–31) used to keep month-based cycles pinned to
    /// their original day across short months (Jan 31 → Feb 28 → Mar 31).
    /// 0 means no anchor.
    var billingAnchorDay: Int = 0

    var startDate: Date? = nil
    var nextBillingDate: Date = Date.now
    /// For `.cancelledStillActive`: the paid-through / access-until date.
    var endDate: Date? = nil
    var trialEndDate: Date? = nil
    var contractEndDate: Date? = nil

    var autoRenews: Bool? = nil
    var renewalMethodRaw: String = RenewalMethodKind.unknown.rawValue
    var renewalMethodOtherLabel: String = ""
    var managedThroughRaw: String = ManagedThroughKind.unknown.rawValue
    var managedThroughOtherLabel: String = ""

    var category: SubscriptionCategory? = nil
    var paymentMethod: PaymentMethod? = nil

    var accountEmail: String = ""
    var websiteURLString: String = ""
    var cancellationURLString: String = ""
    var cancellationNotes: String = ""
    var noticePeriodValue: Int = 0
    var noticePeriodUnitRaw: String = BillingUnit.days.rawValue
    var notes: String = ""

    var reminderPolicyRaw: String = ReminderPolicy.useDefaults.rawValue
    var reminderDaysBefore: [Int] = []

    var isSampleData: Bool = false
    var createdAt: Date = Date.now
    var updatedAt: Date = Date.now

    init() {}
}
