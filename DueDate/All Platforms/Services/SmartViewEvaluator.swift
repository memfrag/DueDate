//
//  Copyright © 2026 Apparata AB. All rights reserved.
//

import Foundation

/// A reason a subscription appears in the Needs Attention smart view
/// (spec Section 23, v1 triggers).
nonisolated enum AttentionReason: Hashable, Sendable {
    case dueSoon(days: Int)
    case trialEndingSoon(days: Int)
    case missingCancellationInfo
    case unknownRenewalMethod
    case unknownPaymentMethod
    case overdueManualRenewal

    var displayName: String {
        switch self {
        case .dueSoon(let days): "Due in \(days) day\(days == 1 ? "" : "s")"
        case .trialEndingSoon(let days): "Trial ends in \(days) day\(days == 1 ? "" : "s")"
        case .missingCancellationInfo: "No cancellation info"
        case .unknownRenewalMethod: "Unknown renewal method"
        case .unknownPaymentMethod: "No payment method"
        case .overdueManualRenewal: "Overdue manual renewal"
        }
    }

    var symbolName: String {
        switch self {
        case .dueSoon, .trialEndingSoon: "clock"
        case .missingCancellationInfo: "xmark.circle"
        case .unknownRenewalMethod, .unknownPaymentMethod: "questionmark.circle"
        case .overdueManualRenewal: "exclamationmark.triangle"
        }
    }
}

/// Counts per smart view, for sidebar badges.
struct SmartViewCounts {
    var counts: [SmartView: Int] = [:]
    subscript(view: SmartView) -> Int { counts[view] ?? 0 }
}

/// Pure evaluation of smart-view membership so the sidebar badge, the
/// filtered table, and the dashboard cards always agree.
enum SmartViewEvaluator {

    /// The window (in days) within which an upcoming due date or trial end
    /// is considered "soon" for the Needs Attention view.
    static let attentionWindowDays = 7

    static func matches(
        _ subscription: Subscription,
        view: SmartView,
        now: Date = .now
    ) -> Bool {
        // Archived subscriptions never appear in smart views.
        guard !subscription.status.isArchived else { return false }

        switch view {
        case .dueIn7Days:
            let days = subscription.daysUntilNextBilling
            return subscription.countsForUpcoming && days >= 0 && days <= 7
        case .dueIn30Days:
            let days = subscription.daysUntilNextBilling
            return subscription.countsForUpcoming && days >= 0 && days <= 30
        case .annualRenewals:
            return subscription.billingCycle.kind == .annual && subscription.countsForUpcoming
        case .trialsEnding:
            return subscription.status == .trial
        case .autoRenewing:
            return subscription.effectivelyAutoRenews
                && (subscription.status == .active || subscription.status == .trial)
        case .needsAttention:
            return !attentionReasons(for: subscription, now: now).isEmpty
        }
    }

    static func filter(
        _ subscriptions: [Subscription],
        view: SmartView,
        now: Date = .now
    ) -> [Subscription] {
        subscriptions.filter { matches($0, view: view, now: now) }
    }

    static func counts(
        for subscriptions: [Subscription],
        now: Date = .now
    ) -> SmartViewCounts {
        var result = SmartViewCounts()
        for view in SmartView.allCases {
            result.counts[view] = subscriptions.count { matches($0, view: view, now: now) }
        }
        return result
    }

    /// The v1 Needs Attention triggers (spec Section 23).
    static func attentionReasons(
        for subscription: Subscription,
        now: Date = .now
    ) -> [AttentionReason] {
        guard !subscription.status.isArchived else { return [] }

        var reasons: [AttentionReason] = []

        // 1. Due date or trial end within the attention window.
        if subscription.status == .active {
            let days = subscription.daysUntilNextBilling
            if days >= 0 && days <= attentionWindowDays {
                reasons.append(.dueSoon(days: days))
            }
        }
        if subscription.status == .trial, let trialEnd = subscription.trialEndDate {
            let calendar = Calendar.current
            let days = calendar.dateComponents(
                [.day],
                from: calendar.startOfDay(for: now),
                to: calendar.startOfDay(for: trialEnd)
            ).day ?? 0
            if days >= 0 && days <= attentionWindowDays {
                reasons.append(.trialEndingSoon(days: days))
            }
        }

        // 2. Missing cancellation info: no URL and no managed-through location.
        if subscription.cancellationURLString.isEmpty,
           subscription.managedThrough == .unknown,
           subscription.status == .active || subscription.status == .trial {
            reasons.append(.missingCancellationInfo)
        }

        // 3. Unknown renewal or payment method.
        if subscription.status == .active || subscription.status == .trial {
            if subscription.renewalMethod == .unknown {
                reasons.append(.unknownRenewalMethod)
            }
            if subscription.paymentMethod == nil {
                reasons.append(.unknownPaymentMethod)
            }
        }

        // 4. Overdue manual renewal.
        if subscription.isOverdueManualRenewal {
            reasons.append(.overdueManualRenewal)
        }

        return reasons
    }
}

extension Subscription {

    /// Whether this subscription belongs in upcoming/due views:
    /// it must still be able to generate a charge.
    var countsForUpcoming: Bool {
        switch status {
        case .active, .trial: true
        case .paused, .cancelledStillActive, .cancelledEnded, .expired: false
        }
    }
}
