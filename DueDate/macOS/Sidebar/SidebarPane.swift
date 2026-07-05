//
//  Copyright © 2026 Apparata AB. All rights reserved.
//

import Foundation

/// The panes available in the sidebar.
enum SidebarPane: Hashable {

    // MARK: Main Sections

    case dashboard
    case subscriptions
    case calendar
    case reports
    case paymentMethods
    case categories
    case archive

    // MARK: Smart Views

    case smartView(SmartView)
}

/// Filtered views over the subscription list (spec Section 14).
enum SmartView: String, CaseIterable, Hashable {
    case dueIn7Days
    case dueIn30Days
    case annualRenewals
    case trialsEnding
    case autoRenewing
    case needsAttention

    var displayName: String {
        switch self {
        case .dueIn7Days: "Due in 7 Days"
        case .dueIn30Days: "Due in 30 Days"
        case .annualRenewals: "Annual Renewals"
        case .trialsEnding: "Trials Ending"
        case .autoRenewing: "Auto-Renewing"
        case .needsAttention: "Needs Attention"
        }
    }

    var symbolName: String {
        switch self {
        case .dueIn7Days: "7.calendar"
        case .dueIn30Days: "30.calendar"
        case .annualRenewals: "arrow.trianglehead.2.clockwise.rotate.90"
        case .trialsEnding: "hourglass"
        case .autoRenewing: "arrow.clockwise.circle"
        case .needsAttention: "exclamationmark.triangle"
        }
    }
}

// MARK: - Protocol Conformances

extension SidebarPane: Identifiable {
    var id: Self { self }
}
