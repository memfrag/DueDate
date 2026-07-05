//
//  Copyright © 2026 Apparata AB. All rights reserved.
//

import Foundation
import SwiftData
import OSLog

/// Launch-time due-date rollover (spec Section 23).
///
/// - Auto-renewing subscriptions whose next billing date has passed are
///   advanced by whole cycles (with month-end clamping) until on/after today,
///   so "what's due" stays correct with zero upkeep.
/// - Manual-renewal subscriptions are never auto-advanced, because payment
///   isn't guaranteed to have happened. They flip to overdue (Needs Attention)
///   until the user confirms payment.
/// - Paused and cancelled subscriptions never advance.
enum RenewalScheduler {

    /// Rolls forward past-due auto-renewing subscriptions.
    /// Idempotent; safe to run on every launch and app activation.
    static func performRollover(context: ModelContext, now: Date = .now) {
        let startOfToday = Calendar.current.startOfDay(for: now)
        let activeRaw = SubscriptionStatus.active.rawValue

        let descriptor = FetchDescriptor<Subscription>(
            predicate: #Predicate { subscription in
                subscription.statusRaw == activeRaw && subscription.nextBillingDate < startOfToday
            }
        )
        guard let overdue = try? context.fetch(descriptor), !overdue.isEmpty else { return }

        var didChange = false
        for subscription in overdue where subscription.effectivelyAutoRenews {
            subscription.nextBillingDate = BillingCalculator.advance(
                subscription.nextBillingDate,
                cycle: subscription.billingCycle,
                anchorDay: subscription.billingAnchorDay,
                until: startOfToday
            )
            didChange = true
        }

        if didChange {
            do {
                try context.save()
            } catch {
                Logger(subsystem: "io.apparata.DueDate", category: "Rollover")
                    .error("Failed to save rollover: \(error)")
            }
        }
    }

    /// The user confirmed a manual renewal was paid: advance exactly one cycle
    /// from the (overdue) due date.
    static func confirmPayment(for subscription: Subscription, context: ModelContext) {
        subscription.nextBillingDate = BillingCalculator.nextDate(
            after: subscription.nextBillingDate,
            cycle: subscription.billingCycle,
            anchorDay: subscription.billingAnchorDay
        )
        subscription.updatedAt = .now
        try? context.save()
    }
}
