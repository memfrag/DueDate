//
//  Copyright © 2026 Apparata AB. All rights reserved.
//

import Foundation

/// How reminder timing is determined for a subscription.
nonisolated enum ReminderPolicy: String, CaseIterable, Codable, Sendable {
    /// Use the app-wide default reminder offsets for the subscription's cycle.
    case useDefaults
    /// Use the subscription's own `reminderDaysBefore` offsets.
    case custom
    /// No reminders for this subscription.
    case disabled

    var displayName: String {
        switch self {
        case .useDefaults: "Use defaults"
        case .custom: "Custom"
        case .disabled: "None"
        }
    }
}
