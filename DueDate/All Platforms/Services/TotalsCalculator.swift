//
//  Copyright © 2026 Apparata AB. All rights reserved.
//

import Foundation

/// Aggregated totals in the display currency.
struct SpendTotals {
    var monthlyTotal: Decimal = 0
    var annualTotal: Decimal = 0
    /// Subscriptions counted toward the totals.
    var subscriptionCount: Int = 0
    /// Subscriptions skipped because no exchange rate was available.
    var unconvertibleCount: Int = 0
}

/// Sums subscription costs into the display currency using a rate table.
/// Only statuses that count toward totals are included (spec Section 7):
/// Active, Paused, and Cancelled (still active).
enum TotalsCalculator {

    static func convert(
        _ amount: Decimal,
        from sourceCode: String,
        to targetCode: String,
        table: RateTable?
    ) -> Decimal? {
        if sourceCode == targetCode { return amount }
        guard let table,
              let sourceRate = table.rate(for: sourceCode),
              let targetRate = table.rate(for: targetCode),
              targetRate > 0 else { return nil }
        // Pivot through SEK: amount → SEK → target.
        return amount * sourceRate / targetRate
    }

    static func totals(
        for subscriptions: [Subscription],
        displayCurrencyCode: String,
        table: RateTable?
    ) -> SpendTotals {
        var totals = SpendTotals()
        for subscription in subscriptions where subscription.countsTowardTotals {
            guard let monthly = convert(
                subscription.monthlyEquivalent,
                from: subscription.currencyCode,
                to: displayCurrencyCode,
                table: table
            ) else {
                totals.unconvertibleCount += 1
                continue
            }
            totals.monthlyTotal += monthly
            totals.annualTotal += monthly * 12
            totals.subscriptionCount += 1
        }
        return totals
    }

    /// The converted cost of the subscriptions due within `days` days.
    static func dueWithin(
        days: Int,
        subscriptions: [Subscription],
        displayCurrencyCode: String,
        table: RateTable?
    ) -> (count: Int, total: Decimal) {
        var count = 0
        var total: Decimal = 0
        for subscription in subscriptions where subscription.countsForUpcoming {
            let dueDays = subscription.daysUntilNextBilling
            guard dueDays >= 0 && dueDays <= days else { continue }
            count += 1
            if let converted = convert(
                subscription.amount,
                from: subscription.currencyCode,
                to: displayCurrencyCode,
                table: table
            ) {
                total += converted
            }
        }
        return (count, total)
    }
}
