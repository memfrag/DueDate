//
//  Copyright © 2026 Apparata AB. All rights reserved.
//

import Foundation

/// Where a subscription can be managed, changed, or cancelled.
nonisolated enum ManagedThrough: Hashable, Sendable {
    case serviceWebsite
    case appleAppStore
    case googlePlay
    case paypal
    case bankOrAutogiro
    case providerSupport
    case invoice
    case other(String)
    case unknown

    var displayName: String {
        switch self {
        case .serviceWebsite: "Service website"
        case .appleAppStore: "Apple App Store"
        case .googlePlay: "Google Play"
        case .paypal: "PayPal"
        case .bankOrAutogiro: "Bank / Autogiro"
        case .providerSupport: "Provider support"
        case .invoice: "Invoice"
        case .other(let label): label.isEmpty ? "Other" : label
        case .unknown: "Unknown"
        }
    }

    var kind: ManagedThroughKind {
        switch self {
        case .serviceWebsite: .serviceWebsite
        case .appleAppStore: .appleAppStore
        case .googlePlay: .googlePlay
        case .paypal: .paypal
        case .bankOrAutogiro: .bankOrAutogiro
        case .providerSupport: .providerSupport
        case .invoice: .invoice
        case .other: .other
        case .unknown: .unknown
        }
    }
}

/// Raw-storable mirror of `ManagedThrough` (`.other` label stored separately).
nonisolated enum ManagedThroughKind: String, CaseIterable, Codable, Sendable {
    case serviceWebsite
    case appleAppStore
    case googlePlay
    case paypal
    case bankOrAutogiro
    case providerSupport
    case invoice
    case other
    case unknown

    var managedThrough: ManagedThrough {
        switch self {
        case .serviceWebsite: .serviceWebsite
        case .appleAppStore: .appleAppStore
        case .googlePlay: .googlePlay
        case .paypal: .paypal
        case .bankOrAutogiro: .bankOrAutogiro
        case .providerSupport: .providerSupport
        case .invoice: .invoice
        case .other: .other("")
        case .unknown: .unknown
        }
    }

    var displayName: String { managedThrough.displayName }
}
