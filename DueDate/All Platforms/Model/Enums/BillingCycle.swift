//
//  Copyright © 2026 Apparata AB. All rights reserved.
//

import Foundation

/// How often a subscription bills.
nonisolated enum BillingCycle: Hashable, Sendable {
    case weekly
    case monthly
    case quarterly
    case semiAnnual
    case annual
    case custom(value: Int, unit: BillingUnit)

    var displayName: String {
        switch self {
        case .weekly: "Weekly"
        case .monthly: "Monthly"
        case .quarterly: "Quarterly"
        case .semiAnnual: "Semiannual"
        case .annual: "Annual"
        case .custom(let value, let unit):
            "Every \(value) \(value == 1 ? unit.singularName : unit.pluralName)"
        }
    }

    var kind: BillingCycleKind {
        switch self {
        case .weekly: .weekly
        case .monthly: .monthly
        case .quarterly: .quarterly
        case .semiAnnual: .semiAnnual
        case .annual: .annual
        case .custom: .custom
        }
    }
}

/// Raw-storable mirror of `BillingCycle` (associated value stored separately).
nonisolated enum BillingCycleKind: String, CaseIterable, Codable, Sendable {
    case weekly
    case monthly
    case quarterly
    case semiAnnual
    case annual
    case custom

    var displayName: String {
        switch self {
        case .weekly: "Weekly"
        case .monthly: "Monthly"
        case .quarterly: "Quarterly"
        case .semiAnnual: "Semiannual"
        case .annual: "Annual"
        case .custom: "Custom"
        }
    }
}

/// The unit for custom billing cycles and notice periods.
nonisolated enum BillingUnit: String, CaseIterable, Codable, Sendable {
    case days
    case weeks
    case months
    case years

    var singularName: String {
        switch self {
        case .days: "day"
        case .weeks: "week"
        case .months: "month"
        case .years: "year"
        }
    }

    var pluralName: String { rawValue }

    var calendarComponent: Calendar.Component {
        switch self {
        case .days: .day
        case .weeks: .weekOfYear
        case .months: .month
        case .years: .year
        }
    }
}
