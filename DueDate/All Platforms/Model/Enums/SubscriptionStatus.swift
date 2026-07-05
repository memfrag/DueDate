//
//  Copyright © 2026 Apparata AB. All rights reserved.
//

import Foundation

/// The lifecycle status of a subscription.
///
/// Cancelled is deliberately split in two: a subscription cancelled before its
/// paid period ends is still part of current reality (access remains, money is
/// spent for the period) and counts toward totals, unlike one that has fully ended.
nonisolated enum SubscriptionStatus: String, CaseIterable, Codable, Sendable {
    case active
    case trial
    case paused
    case cancelledStillActive
    case cancelledEnded
    case expired

    var displayName: String {
        switch self {
        case .active: "Active"
        case .trial: "Trial"
        case .paused: "Paused"
        case .cancelledStillActive: "Cancelled (still active)"
        case .cancelledEnded: "Cancelled (ended)"
        case .expired: "Expired"
        }
    }

    /// Whether subscriptions with this status count toward the headline
    /// monthly/annual totals (spec Section 7).
    var countsTowardTotals: Bool {
        switch self {
        case .active, .paused, .cancelledStillActive: true
        case .trial, .cancelledEnded, .expired: false
        }
    }

    /// Whether subscriptions with this status belong in the Archive.
    var isArchived: Bool {
        switch self {
        case .cancelledEnded, .expired: true
        default: false
        }
    }

    /// Whether reminders should fire for this status (spec Section 19).
    var allowsReminders: Bool {
        switch self {
        case .active, .trial: true
        default: false
        }
    }
}
