//
//  Copyright © 2026 Apparata AB. All rights reserved.
//

import Foundation

/// The kind of a reusable payment method record.
nonisolated enum PaymentMethodKind: String, CaseIterable, Codable, Sendable {
    case debitCard
    case creditCard
    case bankAccount
    case paypal
    case appleAccount
    case googleAccount
    case invoice
    case cash
    case other

    var displayName: String {
        switch self {
        case .debitCard: "Debit card"
        case .creditCard: "Credit card"
        case .bankAccount: "Bank account"
        case .paypal: "PayPal"
        case .appleAccount: "Apple account"
        case .googleAccount: "Google account"
        case .invoice: "Invoice"
        case .cash: "Cash"
        case .other: "Other"
        }
    }

    var symbolName: String {
        switch self {
        case .debitCard, .creditCard: "creditcard"
        case .bankAccount: "building.columns"
        case .paypal: "p.circle"
        case .appleAccount: "apple.logo"
        case .googleAccount: "g.circle"
        case .invoice: "doc.text"
        case .cash: "banknote"
        case .other: "questionmark.circle"
        }
    }
}
