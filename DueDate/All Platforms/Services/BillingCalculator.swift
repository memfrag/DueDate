//
//  Copyright © 2026 Apparata AB. All rights reserved.
//

import Foundation

/// Pure billing math: monthly equivalents, annual projections, and
/// next-billing-date advancement (spec Section 23).
nonisolated enum BillingCalculator {

    // MARK: - Normalization

    /// The number of billing events per year for a cycle.
    static func cyclesPerYear(_ cycle: BillingCycle) -> Decimal {
        switch cycle {
        case .weekly: 52
        case .monthly: 12
        case .quarterly: 4
        case .semiAnnual: 2
        case .annual: 1
        case .custom(let value, let unit):
            switch unit {
            case .days: Decimal(365.25) / Decimal(max(1, value))
            case .weeks: Decimal(52) / Decimal(max(1, value))
            case .months: Decimal(12) / Decimal(max(1, value))
            case .years: Decimal(1) / Decimal(max(1, value))
            }
        }
    }

    /// Normalizes an amount into its monthly equivalent.
    static func monthlyEquivalent(amount: Decimal, cycle: BillingCycle) -> Decimal {
        amount * cyclesPerYear(cycle) / 12
    }

    /// Normalizes an amount into its annual projection.
    static func annualProjection(amount: Decimal, cycle: BillingCycle) -> Decimal {
        amount * cyclesPerYear(cycle)
    }

    // MARK: - Date Advancement

    /// The next billing date after `date` for the given cycle.
    ///
    /// For month/year-based cycles, `anchorDay` (1–31) keeps the billing day
    /// pinned across short months: a subscription anchored to the 31st bills
    /// on the last day of shorter months (Jan 31 → Feb 28 → Mar 31).
    ///
    static func nextDate(
        after date: Date,
        cycle: BillingCycle,
        anchorDay: Int = 0,
        calendar: Calendar = .current
    ) -> Date {
        let step: (component: Calendar.Component, value: Int) = switch cycle {
        case .weekly: (.weekOfYear, 1)
        case .monthly: (.month, 1)
        case .quarterly: (.month, 3)
        case .semiAnnual: (.month, 6)
        case .annual: (.year, 1)
        case .custom(let value, let unit): (unit.calendarComponent, max(1, value))
        }

        var result = calendar.date(byAdding: step.component, value: step.value, to: date) ?? date

        // Re-apply the day-of-month anchor after month/year arithmetic, since
        // Calendar clamps down (Jan 31 + 1 month = Feb 28) and would otherwise
        // lose the anchor for all subsequent months.
        let isMonthBased = step.component == .month || step.component == .year
        if isMonthBased, anchorDay > 0 {
            var components = calendar.dateComponents(
                [.year, .month, .hour, .minute, .second], from: result
            )
            let daysInMonth = calendar.range(of: .day, in: .month, for: result)?.count ?? 28
            components.day = min(anchorDay, daysInMonth)
            result = calendar.date(from: components) ?? result
        }
        return result
    }

    /// Advances a date by whole cycles until it is on or after `target`.
    /// Used by launch rollover for auto-renewing subscriptions that may have
    /// missed several cycles while the app was closed.
    static func advance(
        _ date: Date,
        cycle: BillingCycle,
        anchorDay: Int = 0,
        until target: Date,
        calendar: Calendar = .current
    ) -> Date {
        var result = date
        // Bounded to protect against degenerate cycles.
        for _ in 0..<1000 where result < target {
            let next = nextDate(after: result, cycle: cycle, anchorDay: anchorDay, calendar: calendar)
            guard next > result else { break }
            result = next
        }
        return result
    }

    /// Generates upcoming charge dates from `start` (inclusive) through
    /// `monthsAhead` months, for calendar and reminder views.
    static func chargeDates(
        startingAt start: Date,
        cycle: BillingCycle,
        anchorDay: Int = 0,
        monthsAhead: Int = 12,
        calendar: Calendar = .current
    ) -> [Date] {
        guard let horizon = calendar.date(byAdding: .month, value: monthsAhead, to: .now) else {
            return []
        }
        var dates: [Date] = []
        var date = start
        while date <= horizon && dates.count < 500 {
            dates.append(date)
            let next = nextDate(after: date, cycle: cycle, anchorDay: anchorDay, calendar: calendar)
            guard next > date else { break }
            date = next
        }
        return dates
    }
}
