//
//  Copyright © 2026 Apparata AB. All rights reserved.
//

import Foundation

/// How a subscription renews.
nonisolated enum RenewalMethod: Hashable, Sendable {
    case manual
    case autoRenew
    case cardOnFile
    case applePay
    case paypalAutomaticPayment
    case appStoreSubscription
    case googlePlaySubscription
    case autogiro
    case directDebit
    case invoice
    case bankTransfer
    case unknown
    case other(String)

    var displayName: String {
        switch self {
        case .manual: "Manual"
        case .autoRenew: "Auto-renew"
        case .cardOnFile: "Card on file"
        case .applePay: "Apple Pay"
        case .paypalAutomaticPayment: "PayPal"
        case .appStoreSubscription: "Apple App Store"
        case .googlePlaySubscription: "Google Play"
        case .autogiro: "Autogiro"
        case .directDebit: "Direct debit"
        case .invoice: "Invoice"
        case .bankTransfer: "Bank transfer"
        case .unknown: "Unknown"
        case .other(let label): label.isEmpty ? "Other" : label
        }
    }

    var kind: RenewalMethodKind {
        switch self {
        case .manual: .manual
        case .autoRenew: .autoRenew
        case .cardOnFile: .cardOnFile
        case .applePay: .applePay
        case .paypalAutomaticPayment: .paypalAutomaticPayment
        case .appStoreSubscription: .appStoreSubscription
        case .googlePlaySubscription: .googlePlaySubscription
        case .autogiro: .autogiro
        case .directDebit: .directDebit
        case .invoice: .invoice
        case .bankTransfer: .bankTransfer
        case .unknown: .unknown
        case .other: .other
        }
    }

    /// Whether this method renews without user action.
    /// Manual and unknown renewals are not considered automatic.
    var isAutomatic: Bool {
        switch self {
        case .manual, .unknown: false
        default: true
        }
    }
}

/// Raw-storable mirror of `RenewalMethod` (`.other` label stored separately).
nonisolated enum RenewalMethodKind: String, CaseIterable, Codable, Sendable {
    case manual
    case autoRenew
    case cardOnFile
    case applePay
    case paypalAutomaticPayment
    case appStoreSubscription
    case googlePlaySubscription
    case autogiro
    case directDebit
    case invoice
    case bankTransfer
    case unknown
    case other

    var method: RenewalMethod {
        switch self {
        case .manual: .manual
        case .autoRenew: .autoRenew
        case .cardOnFile: .cardOnFile
        case .applePay: .applePay
        case .paypalAutomaticPayment: .paypalAutomaticPayment
        case .appStoreSubscription: .appStoreSubscription
        case .googlePlaySubscription: .googlePlaySubscription
        case .autogiro: .autogiro
        case .directDebit: .directDebit
        case .invoice: .invoice
        case .bankTransfer: .bankTransfer
        case .unknown: .unknown
        case .other: .other("")
        }
    }

    var displayName: String { method.displayName }
}
