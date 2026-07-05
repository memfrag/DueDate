//
//  Copyright © 2026 Apparata AB. All rights reserved.
//

import Foundation

// MARK: - Enum Wrappers

extension Subscription {

    var status: SubscriptionStatus {
        get { SubscriptionStatus(rawValue: statusRaw) ?? .active }
        set { statusRaw = newValue.rawValue }
    }

    var billingCycle: BillingCycle {
        get {
            switch BillingCycleKind(rawValue: billingCycleKindRaw) ?? .monthly {
            case .weekly: .weekly
            case .monthly: .monthly
            case .quarterly: .quarterly
            case .semiAnnual: .semiAnnual
            case .annual: .annual
            case .custom: .custom(
                value: max(1, billingCycleValue),
                unit: BillingUnit(rawValue: billingCycleUnitRaw) ?? .months
            )
            }
        }
        set {
            billingCycleKindRaw = newValue.kind.rawValue
            if case .custom(let value, let unit) = newValue {
                billingCycleValue = max(1, value)
                billingCycleUnitRaw = unit.rawValue
            } else {
                billingCycleValue = 1
                billingCycleUnitRaw = BillingUnit.months.rawValue
            }
        }
    }

    var renewalMethod: RenewalMethod {
        get {
            let kind = RenewalMethodKind(rawValue: renewalMethodRaw) ?? .unknown
            return kind == .other ? .other(renewalMethodOtherLabel) : kind.method
        }
        set {
            renewalMethodRaw = newValue.kind.rawValue
            if case .other(let label) = newValue {
                renewalMethodOtherLabel = label
            } else {
                renewalMethodOtherLabel = ""
            }
        }
    }

    var managedThrough: ManagedThrough {
        get {
            let kind = ManagedThroughKind(rawValue: managedThroughRaw) ?? .unknown
            return kind == .other ? .other(managedThroughOtherLabel) : kind.managedThrough
        }
        set {
            managedThroughRaw = newValue.kind.rawValue
            if case .other(let label) = newValue {
                managedThroughOtherLabel = label
            } else {
                managedThroughOtherLabel = ""
            }
        }
    }

    var reminderPolicy: ReminderPolicy {
        get { ReminderPolicy(rawValue: reminderPolicyRaw) ?? .useDefaults }
        set { reminderPolicyRaw = newValue.rawValue }
    }

    var websiteURL: URL? {
        get { websiteURLString.isEmpty ? nil : URL(string: websiteURLString) }
        set { websiteURLString = newValue?.absoluteString ?? "" }
    }

    var cancellationURL: URL? {
        get { cancellationURLString.isEmpty ? nil : URL(string: cancellationURLString) }
        set { cancellationURLString = newValue?.absoluteString ?? "" }
    }
}

// MARK: - Derived Properties

extension Subscription {

    /// Whether this subscription's cost counts toward the headline totals.
    var countsTowardTotals: Bool {
        status.countsTowardTotals
    }

    /// Whether this subscription effectively renews without user action.
    /// An explicit `autoRenews == false` overrides an automatic renewal method.
    var effectivelyAutoRenews: Bool {
        renewalMethod.isAutomatic && autoRenews != false
    }

    /// A manual-renewal subscription whose due date has passed without the
    /// user confirming payment (spec Section 23).
    var isOverdueManualRenewal: Bool {
        guard status == .active, !effectivelyAutoRenews else { return false }
        return nextBillingDate < Calendar.current.startOfDay(for: .now)
    }

    /// The monthly-equivalent cost in the subscription's own currency.
    var monthlyEquivalent: Decimal {
        BillingCalculator.monthlyEquivalent(amount: amount, cycle: billingCycle)
    }

    /// The annual-projection cost in the subscription's own currency.
    var annualProjection: Decimal {
        BillingCalculator.annualProjection(amount: amount, cycle: billingCycle)
    }

    // MARK: Sortable display strings (used by table column comparators)

    var categoryName: String {
        category?.name ?? ""
    }

    var paymentMethodName: String {
        paymentMethod?.displayName ?? ""
    }

    var renewalMethodName: String {
        renewalMethod.displayName
    }

    var billingCycleName: String {
        billingCycle.displayName
    }

    /// Whole days from the start of today until the next billing date.
    /// Negative values mean the date has passed.
    var daysUntilNextBilling: Int {
        let calendar = Calendar.current
        return calendar.dateComponents(
            [.day],
            from: calendar.startOfDay(for: .now),
            to: calendar.startOfDay(for: nextBillingDate)
        ).day ?? 0
    }
}
