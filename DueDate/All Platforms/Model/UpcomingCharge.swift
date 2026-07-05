//
//  Copyright © 2026 Apparata AB. All rights reserved.
//

import Foundation

/// A projected future charge, generated from a subscription's next billing
/// date and cycle (spec Section 23). Used by the calendar and reports.
struct UpcomingCharge: Identifiable, Hashable {

    let subscriptionID: UUID
    let name: String
    let amount: Decimal
    let currencyCode: String
    let date: Date
    let cycleKind: BillingCycleKind

    var id: String {
        "\(subscriptionID.uuidString)-\(date.timeIntervalSinceReferenceDate)"
    }
}

extension UpcomingCharge {

    /// Projects charges for all charge-generating subscriptions
    /// roughly `monthsAhead` months out.
    static func project(
        from subscriptions: [Subscription],
        monthsAhead: Int = 12
    ) -> [UpcomingCharge] {
        var charges: [UpcomingCharge] = []
        for subscription in subscriptions where subscription.countsForUpcoming {
            let dates = BillingCalculator.chargeDates(
                startingAt: subscription.nextBillingDate,
                cycle: subscription.billingCycle,
                anchorDay: subscription.billingAnchorDay,
                monthsAhead: monthsAhead
            )
            for date in dates {
                charges.append(UpcomingCharge(
                    subscriptionID: subscription.id,
                    name: subscription.name,
                    amount: subscription.amount,
                    currencyCode: subscription.currencyCode,
                    date: date,
                    cycleKind: subscription.billingCycle.kind
                ))
            }
        }
        return charges.sorted { $0.date < $1.date }
    }
}
